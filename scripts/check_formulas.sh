#!/bin/bash
# check_formulas.sh: for every formula, resolve the latest version and verify
# that the download this formula would actually attempt exists upstream.
# Catches config drift such as a GitHub repo's "latest release" pointing at a
# sub-crate/library tag with no CLI binary attached (e.g. dua-cli's
# dua-core-vX releases), a renamed asset, or a dead download URL.
#
# Deliberately does NOT use `set -e`: one formula's network hiccup must not
# abort the scan of the other 30+.
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

shopt -s nullglob

STATUS_OK=0
STATUS_WARN=0
STATUS_FAIL=0

function report_ok {
    printf "${C_GREEN}OK${C_RESET}   %-20s %s\n" "$1" "$2"
    STATUS_OK=$((STATUS_OK + 1))
}

function report_warn {
    printf "${C_YELLOW}WARN${C_RESET} %-20s %s\n" "$1" "$2"
    STATUS_WARN=$((STATUS_WARN + 1))
}

function report_fail {
    printf "${C_RED}FAIL${C_RESET} %-20s %s\n" "$1" "$2"
    STATUS_FAIL=$((STATUS_FAIL + 1))
}

# derive_dpkg_version: mirror pkg-common.sh's build_package derivation of
# DPKG_VERSION from LATEST_VER (strip leading non-digits, pad to X.Y.Z), since
# several formulas' DOWNLOAD_FILENAME/DOWNLOAD_URL_TEMPLATE use $DPKG_VERSION
# instead of $LATEST_VER.
function derive_dpkg_version {
    local ver parts
    ver=$(sed 's/^[^0-9]*//' <<< "$LATEST_VER")
    IFS='.' read -ra parts <<< "$ver"
    while [ ${#parts[@]} -lt 3 ]; do
        parts+=("0")
    done
    DPKG_VERSION=$(IFS='.'; echo "${parts[*]}")
}

# github_release_json: fetch the raw /releases/latest JSON for a repo, reusing
# the same auth header as get_latest_ver() in functions.sh.
function github_release_json {
    local repo="$1"
    local extra_args=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        extra_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
        )
    fi
    curl "${extra_args[@]}" -qs "https://api.github.com/repos/${repo}/releases/latest"
}

function check_github_formula {
    local name="$1"
    local json tag_name assets_json download_filename

    json=$(github_release_json "$REPO")
    if [[ -z "$json" ]]; then
        report_warn "$name" "empty response from GitHub API for $REPO, skipped"
        return 0
    fi
    if [[ "$json" == *"API rate limit exceeded"* || "$json" == *"secondary rate limit"* ]]; then
        report_warn "$name" "GitHub API rate limit exceeded, skipped"
        return 0
    fi

    tag_name=$(jq -r '.tag_name // empty' <<< "$json" 2>/dev/null)
    if [[ -z "$tag_name" ]]; then
        report_fail "$name" "could not read tag_name from GitHub API for $REPO"
        return 0
    fi

    assets_json=$(jq -c '[.assets[].name]' <<< "$json" 2>/dev/null)
    LATEST_VER="$tag_name"
    derive_dpkg_version
    download_filename=$(var_substitution "$DOWNLOAD_FILENAME")

    if [[ -z "$assets_json" || "$assets_json" == "[]" ]]; then
        report_fail "$name" "latest release $tag_name has no assets (likely a non-CLI/sub-crate release)"
        return 0
    fi

    if jq -e --arg f "$download_filename" 'index($f) != null' <<< "$assets_json" >/dev/null 2>&1; then
        report_ok "$name" "$tag_name -> $download_filename"
    else
        local sample
        sample=$(jq -r '.[0:3] | join(", ")' <<< "$assets_json" 2>/dev/null)
        report_fail "$name" "$tag_name has assets but not '$download_filename' (e.g. $sample)"
    fi
}

# check_download_url: url_html and hashicorp formulas have no asset listing to
# compare against, so fall back to a HEAD request on the constructed URL.
function check_download_url {
    local name="$1" latest_ver="$2"
    local download_url http_code

    LATEST_VER="$latest_ver"
    derive_dpkg_version
    download_url=$(var_substitution "$DOWNLOAD_URL_TEMPLATE")
    http_code=$(curl -qsL -o /dev/null -w '%{http_code}' "$download_url" 2>/dev/null)

    if [[ "$http_code" == "200" ]]; then
        report_ok "$name" "$latest_ver -> $download_url"
    else
        report_fail "$name" "$latest_ver -> $download_url (HTTP ${http_code:-000})"
    fi
}

for formula in "$CDIR"/../formulas/*.formula; do
    name=$(basename "$formula" .formula)

    unset FORMULA_TYPE REPO HASHICORP_PRODUCT VERSION_URL VERSION_REGEX
    unset DPKG_BASENAME DOWNLOAD_FILENAME DOWNLOAD_URL_TEMPLATE LATEST_VER
    source "$formula"

    ftype="${FORMULA_TYPE:-github}"
    case "$ftype" in
        github)
            if [[ -z "$REPO" ]]; then
                report_fail "$name" "github formula missing REPO"
                continue
            fi
            check_github_formula "$name"
            ;;
        url_html)
            if [[ -z "$VERSION_URL" || -z "$VERSION_REGEX" ]]; then
                report_fail "$name" "url_html formula missing VERSION_URL/VERSION_REGEX"
                continue
            fi
            if ! latest_ver=$(get_latest_ver_html "$VERSION_URL" "$VERSION_REGEX"); then
                report_fail "$name" "$latest_ver"
                continue
            fi
            check_download_url "$name" "$latest_ver"
            ;;
        hashicorp)
            if [[ -z "$HASHICORP_PRODUCT" ]]; then
                report_fail "$name" "hashicorp formula missing HASHICORP_PRODUCT"
                continue
            fi
            if ! latest_ver=$(get_latest_ver_hashicorp "$HASHICORP_PRODUCT"); then
                report_fail "$name" "$latest_ver"
                continue
            fi
            check_download_url "$name" "$latest_ver"
            ;;
        *)
            report_warn "$name" "unknown FORMULA_TYPE '$ftype', skipped"
            ;;
    esac
done

echo "---------------"
echo "OK: $STATUS_OK  WARN: $STATUS_WARN  FAIL: $STATUS_FAIL"

[[ "$STATUS_FAIL" -eq 0 ]]
