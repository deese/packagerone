#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
TMPFOLDER=$(mktemp -dt "pkgone-XXXXXXXX")
WGET="wget -q"
LATEST_FILE="$TMPFOLDER/latest.json"
DOWNLOAD_LINKS="$TMPFOLDER/links.txt"
OUTPUT_GPT="output_gpt.log"
MODEL="anthropic/claude-sonnet-4.6"
TEMPERATURE="${TEMPERATURE:-0.0}"
MAX_TOKENS="${MAX_TOKENS:-1024}"
SYSTEM_PROMPT_FILE="$CDIR/system_prompt.md"
USER_PROMPT_FILE="$CDIR/user_prompt.md"

function run_clean {
    FILENAME=$(basename "$1")
    read -p "Do you want to clean the files [y/N]: " answer
	case "$answer" in
		[Yy]* )
			echo "Deleting file..."
			rm -fr "$TMPFOLDER"
			;;
		* )
			echo "File not deleted."
			;;
	esac
}

function var_substitution {
    VARS_TO_SUBST=(FILELIST DOWNLOAD_LINK FORMULA_TYPE TYPE_CONTEXT HASHICORP_PRODUCT VERSION_URL)
    RET="$1"
    shift
    if [[ $# -gt 0 ]]; then
        VARS_TO_SUBST=("$@")
    fi

    local max_loops=5
    local _count=0
    stderr "substituting.."
    while [[ "$RET" == *'$'* && $_count -lt $max_loops ]]; do
        for var in "${VARS_TO_SUBST[@]}"; do
            if [[ -n "${!var+x}" ]]; then
                val="${!var}"
                RET="${RET//\$$var/$val}"
            fi
        done
        _count=$(( _count + 1 ))
    done
    echo "$RET"
}

function stderr {
    echo "$1" >&2
}

# ── Type detection ────────────────────────────────────────────────────────────

function detect_type {
    if [[ "$1" == hashicorp:* ]]; then
        echo "hashicorp"
    elif [[ "$1" =~ ^https?:// ]] && [[ "$1" != *github.com* ]]; then
        echo "url_html"
    else
        echo "github"
    fi
}

# ── GitHub ────────────────────────────────────────────────────────────────────

function normalize_github_repo {
    local input="$1"

    if [[ "$input" =~ ^[^/]+/[^/]+$ ]]; then
        echo "$input"
        return 0
    fi

    if [[ "$input" =~ github\.com/([^/]+/[^/]+) ]]; then
        local repo_part="${BASH_REMATCH[1]}"
        repo_part=$(echo "$repo_part" | cut -d'/' -f1,2)
        echo "$repo_part"
        return 0
    fi

    echo "$input"
    return 1
}

function download_latest_gh {
    stderr "Downloading latest from: $1"
	if [ -f "$LATEST_FILE" ]; then
		stderr "Data already exists."
		return 0
	fi
	if [[ ! -z $GITHUB_TOKEN ]]; then
	   EXTRA_ARGS=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
	   )
	else
           EXTRA_ARGS=()
    fi

	curl "${EXTRA_ARGS[@]}" -qs https://api.github.com/repos/$1/releases/latest > $LATEST_FILE
}

function get_download_links {
    stderr "Retrieving links"

    jq -r '.assets[] | select(.name | test("(?=.*linux)(?=.*x86_64).*"; "i")) | .browser_download_url' $LATEST_FILE > $DOWNLOAD_LINKS
    jq -r '.assets[] | select(.name | test("(?=.*linux)(?=.*amd64).*"; "i")) | .browser_download_url' $LATEST_FILE >> $DOWNLOAD_LINKS

    if [[ ! -s "$DOWNLOAD_LINKS" ]]; then
        jq -r '.assets[] | select(.name | test(".*linux.*"; "i")) | .browser_download_url' $LATEST_FILE >> $DOWNLOAD_LINKS
    fi
}

function get_github_repo_description {
    local repo="$1"
    local extra_args=()

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        extra_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
        )
    fi

    curl "${extra_args[@]}" -qs "https://api.github.com/repos/${repo}" \
        | jq -r '.description // empty'
}

function get_repo_data {
    stderr "Get Repo Data"
    download_latest_gh "$1"
    get_download_links

    PROMPT_LINKS="$(<$DOWNLOAD_LINKS)"
    if [[ -z "$PROMPT_LINKS" ]]; then
        stderr "Error: no download links found for $1"
        return 1
    fi
    if [[ $(echo -e "$PROMPT_LINKS"|wc -l) -eq 1 ]]; then
        stderr "Only one link found."
        echo "$PROMPT_LINKS"
        return 0
    fi
    LINK_SYSTEM="You are a helper that selects the best download link from a list. Return only the URL, with no explanation or extra text."
    LINK_USER="Given the following links and giving priority to tar.gz and similar, and GNU over musl. To be run on an x64 machine. What will be the best match? Return only the link. $PROMPT_LINKS"
    RETR=$(query_ai "$LINK_SYSTEM" "$LINK_USER")
    echo "$RETR" >> "$OUTPUT_GPT"

    echo "$RETR" | jq -r '.choices[0].message.content'
}

# ── HashiCorp ─────────────────────────────────────────────────────────────────

function get_hashicorp_data {
    local product="$1"
    stderr "Fetching latest HashiCorp release for: $product"

    local api_json
    api_json=$(curl -qsL "https://api.releases.hashicorp.com/v1/releases/${product}/latest")
    LATEST_VER=$(echo "$api_json" | jq -r '.version')

    if [[ -z "$LATEST_VER" || "$LATEST_VER" == "null" ]]; then
        stderr "Error: could not fetch version for HashiCorp product: $product"
        exit 1
    fi

    DOWNLOAD_LINK="https://releases.hashicorp.com/${product}/${LATEST_VER}/${product}_${LATEST_VER}_linux_amd64.zip"
    stderr "Latest version: $LATEST_VER"
    stderr "Download link: $DOWNLOAD_LINK"
}

# ── URL/HTML ──────────────────────────────────────────────────────────────────

# Builds a PCRE regex that extracts the version from a page, based on the
# pattern of the download filename (e.g. ncdu-2.9.1-linux-x86_64.tar.gz →
# ncdu-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz))
function derive_version_regex {
    local download_url="$1"
    local filename
    filename=$(basename "$download_url")

    # Find first semver-like string in the filename
    local version
    version=$(echo "$filename" | grep -oP '\d+\.\d+(\.\d+)*' | head -1)

    if [[ -z "$version" ]]; then
        return 1
    fi

    # Split filename around the version
    local prefix suffix
    prefix="${filename%%"$version"*}"
    suffix="${filename#*"$version"}"

    # Escape PCRE metacharacters (dots are the only common case in filenames)
    local esc_prefix esc_suffix
    esc_prefix=$(printf '%s' "$prefix" | sed 's/\./\\./g')
    esc_suffix=$(printf '%s' "$suffix" | sed 's/\./\\./g')

    # Match the same version depth as found
    local dots ver_pattern
    dots=$(echo "$version" | tr -cd '.' | wc -c)
    case $dots in
        0) ver_pattern='[0-9]+' ;;
        1) ver_pattern='[0-9]+\.[0-9]+' ;;
        *) ver_pattern='[0-9]+\.[0-9]+\.[0-9]+' ;;
    esac

    printf '%s\\K%s(?=%s)' "$esc_prefix" "$ver_pattern" "$esc_suffix"
}

# Returns 0 if the regex extracts the expected version from the page HTML
function validate_version_regex {
    local page_url="$1"
    local regex="$2"
    local expected="$3"

    local result
    result=$(curl -qsL "$page_url" | grep -oP "$regex" | head -1)
    [[ "$result" == "$expected" ]]
}

function get_url_html_data {
    local url="$1"
    stderr "Fetching HTML from: $url"

    local html
    html=$(curl -qsL "$url")

    # Extract href links pointing to binary archives
    local raw_links
    raw_links=$(echo "$html" \
        | grep -oP 'href="[^"]*\.(tar\.gz|tgz|tar\.bz2|tbz2?|tar\.xz|txz|zip)[^"]*"' \
        | sed 's/href="//;s/"//' \
        | sort -u)

    if [[ -z "$raw_links" ]]; then
        stderr "Error: no download links found on $url"
        exit 1
    fi

    # Derive base URL for resolving relative paths
    local base_url
    base_url=$(echo "$url" | grep -oP '^https?://[^/]+')

    LINK_SYSTEM="You are a helper that selects the best Linux x86_64 static binary download link from a list. Return only the full URL, no explanation or extra text."
    LINK_USER="Page URL: $url
Base URL for relative paths: $base_url
Links found on page:
$raw_links

Select the best link for a static Linux x86_64 binary. Prefer x86_64 over amd64, prefer tar.gz/tgz over zip. If the link is a relative path, prepend the base URL. Return only the full URL."

    RETR=$(query_ai "$LINK_SYSTEM" "$LINK_USER")
    DOWNLOAD_LINK=$(echo "$RETR" | jq -r '.choices[0].message.content' | tr -d '[:space:]')

    if [[ -z "$DOWNLOAD_LINK" ]]; then
        stderr "Error: AI could not determine download link from $url"
        exit 1
    fi
    stderr "Selected download link: $DOWNLOAD_LINK"
}

# ── License / Summary resolution ─────────────────────────────────────────────

function fetch_github_license {
    local repo="$1"
    local extra_args=()

    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        extra_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
        )
    fi

    local result
    result=$(curl "${extra_args[@]}" -qs "https://api.github.com/repos/${repo}" \
        | jq -r '.license.spdx_id // empty')

    if [[ -n "$result" && "$result" != "NOASSERTION" ]]; then
        echo "$result"
        return 0
    fi
    return 1
}

function ensure_license {
    local formula_text="$1"
    local formula_type="${2:-github}"

    if echo "$formula_text" | grep -qE '^PACKAGE_LICENSE=".+"'; then
        echo "$formula_text"
        return 0
    fi

    local license=""

    if [[ "$formula_type" == "github" && -n "${REPO:-}" ]]; then
        stderr "Fetching license from GitHub for $REPO..."
        license=$(fetch_github_license "$REPO") || true
    fi

    if [[ -z "$license" ]]; then
        read -r -p "License not found. Enter SPDX identifier (e.g. MIT, Apache-2.0): " license </dev/tty
        [[ -z "$license" ]] && license="unknown"
    else
        stderr "License resolved from GitHub: $license"
    fi

    echo "$formula_text"
    echo "PACKAGE_LICENSE=\"${license}\""
}

function ensure_summary {
    local formula_text="$1"

    if echo "$formula_text" | grep -qE '^PACKAGE_SUMMARY=".+"'; then
        echo "$formula_text"
        return 0
    fi

    local desc_line summary
    desc_line=$(echo "$formula_text" | grep '^PACKAGE_DESCRIPTION=')
    summary=$(echo "$desc_line" | sed 's/^PACKAGE_DESCRIPTION="//;s/"$//' | head -1)

    echo "$formula_text"
    if [[ -n "$summary" ]]; then
        stderr "Using first line of PACKAGE_DESCRIPTION as PACKAGE_SUMMARY"
        echo "PACKAGE_SUMMARY=\"${summary}\""
    fi
}

# ── AI ────────────────────────────────────────────────────────────────────────

function query_ai {
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "Set the \$OPENROUTER_API_KEY in order to use the LLM query."
        return 1
    fi
    local system_prompt="$1"
    local user_prompt="$2"

    PROMPT=$(jq -n \
        --arg model "$MODEL" \
        --arg system "$system_prompt" \
        --arg user "$user_prompt" \
        --argjson temperature "$TEMPERATURE" \
        --argjson max_tokens "$MAX_TOKENS" \
        '{
            model: $model,
            temperature: $temperature,
            max_tokens: $max_tokens,
            messages: [
                {role: "system", content: $system},
                {role: "user", content: $user}
            ]
        }')

    RESP=$(curl -qsX POST "https://openrouter.ai/api/v1/chat/completions" \
         -H "Authorization: Bearer $OPENROUTER_API_KEY" \
         -H "Content-Type: application/json" \
         -d "$PROMPT")

    echo -e "PROMPT: $PROMPT" >> $OUTPUT_GPT
    echo "RESPONSE: $RESP" >> $OUTPUT_GPT
    echo "$RESP"
}

# ── File listing ──────────────────────────────────────────────────────────────

function get_file_listing {
    FILENAME=$(basename "$DOWNLOAD_LINK")
    FILENAME="$TMPFOLDER/$FILENAME"
    if [ ! -f "$FILENAME" ]; then
        $WGET "$DOWNLOAD_LINK" -O "$FILENAME"
    fi

    if [ ! -f "$FILENAME" ]; then
        stderr "Error downloading file"
        exit 1
    fi

    case "$FILENAME" in
        *.tar|*.tar.gz|*.tar.bz2|*.tar.xz|*.tgz|*.tbz|*.txz)
            FILELIST=$(tar tvf "$FILENAME")
            echo -e "$FILELIST"
            ;;
        *.zip)
            FILELIST=$(unzip -l "$FILENAME")
            echo -e "$FILELIST"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── Main ──────────────────────────────────────────────────────────────────────

FORMULA_TYPE=$(detect_type "$1")
TYPE_CONTEXT=""

case "$FORMULA_TYPE" in
    github)
        REPO=$(normalize_github_repo "$1")
        if [[ $? -ne 0 ]]; then
            stderr "Warning: Could not parse GitHub repository from input: $1"
        fi
        PACKAGE_NAME=$(basename "$REPO")
        DOWNLOAD_LINK=$(get_repo_data "$REPO")
        echo "Download link: $DOWNLOAD_LINK"
        if [[ "$DOWNLOAD_LINK" != *"https://github.com"* ]]; then
            echo "$DOWNLOAD_LINK"
            exit 1
        fi
        REPO_DESCRIPTION=$(get_github_repo_description "$REPO")
        TYPE_CONTEXT="REPO: $REPO"
        [[ -n "$REPO_DESCRIPTION" ]] && TYPE_CONTEXT+="
Repo description: $REPO_DESCRIPTION"
        ;;

    hashicorp)
        HASHICORP_PRODUCT="${1#hashicorp:}"
        PACKAGE_NAME="$HASHICORP_PRODUCT"
        get_hashicorp_data "$HASHICORP_PRODUCT"
        echo "Download link: $DOWNLOAD_LINK"
        TYPE_CONTEXT="HASHICORP_PRODUCT: $HASHICORP_PRODUCT"
        ;;

    url_html)
        VERSION_URL="$1"
        # Try to extract package name from URL path; confirm with user
        PACKAGE_NAME=$(basename "$VERSION_URL" | sed 's/[^a-zA-Z0-9_-]//g')
        read -p "Package name [$PACKAGE_NAME]: " user_input
        [[ -n "$user_input" ]] && PACKAGE_NAME="$user_input"
        get_url_html_data "$VERSION_URL"
        echo "Download link: $DOWNLOAD_LINK"

        # Derive VERSION_REGEX from the download link and validate against the page
        local detected_version regex_label
        detected_version=$(basename "$DOWNLOAD_LINK" | grep -oP '\d+\.\d+(\.\d+)*' | head -1)
        DERIVED_REGEX=$(derive_version_regex "$DOWNLOAD_LINK")

        if [[ -n "$DERIVED_REGEX" ]]; then
            stderr "Derived regex candidate: $DERIVED_REGEX"
            stderr "Validating against $VERSION_URL ..."
            if validate_version_regex "$VERSION_URL" "$DERIVED_REGEX" "$detected_version"; then
                stderr "Regex validated ✓  (extracts: $detected_version)"
                regex_label="validated"
            else
                stderr "Warning: regex did not extract expected version '$detected_version' — passing as candidate"
                regex_label="unvalidated candidate"
            fi
        else
            stderr "Warning: could not derive regex from download filename"
            DERIVED_REGEX="FILL_IN_MANUALLY"
            regex_label="unknown"
        fi

        TYPE_CONTEXT="VERSION_URL: $VERSION_URL
VERSION_REGEX ($regex_label): $DERIVED_REGEX"
        ;;
esac

FORMULA_FILE="formulas/${PACKAGE_NAME}-pkg.formula"

if [ -f "$FORMULA_FILE" ]; then
    echo "Formula already exists: $FORMULA_FILE"
    if [ "${FORCE:-0}" -ne 1 ]; then
        exit 1
    else
        echo "Force is on. Continuing"
    fi
fi

FILELIST=$(get_file_listing)
if [ -z "$FILELIST" ]; then
    echo "Empty file listing. Please review"
    exit 1
fi

SYSTEM_PROMPT=$(<"$SYSTEM_PROMPT_FILE")
USER_TEMPLATE=$(<"$USER_PROMPT_FILE")
USER_TEMPLATE=$(var_substitution "$USER_TEMPLATE")

DATA=$(query_ai "$SYSTEM_PROMPT" "$USER_TEMPLATE")
FORMULA=$(echo "$DATA" | jq -r '.choices[0].message.content')

FORMULA=$(ensure_license "$FORMULA" "$FORMULA_TYPE")
FORMULA=$(ensure_summary "$FORMULA")

echo "File listing"
echo "============"
echo "$FILELIST"
echo "============"

echo "Generated formula:"
echo "=================="
echo "$FORMULA"
echo "=================="

read -p "Do you want to save this formula to $FORMULA_FILE? [y/N]: " answer
case "$answer" in
    [Yy]* )
        if [ -d "formulas" ]; then
            echo "$FORMULA" > "$FORMULA_FILE"
            echo "Formula saved to: $FORMULA_FILE"
        else
            echo "Error: formulas directory does not exist"
            exit 1
        fi
        ;;
    * )
        echo "Formula not saved."
        ;;
esac

run_clean "$DOWNLOAD_LINK"
