SCRIPT_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
source "$SCRIPT_DIR/scripts/environ.sh"

mkdir -p $OUTPUT_FOLDER $LOGFOLDER

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET='\033[0m'; C_DIM='\033[2m'; C_BOLD='\033[1m'
  C_CYAN='\033[36m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_RED='\033[31m'
else
  C_RESET=''; C_DIM=''; C_BOLD=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

function read_env() {
  local filePath="${1:-.env}"
  logme -v Loading environment  $filePath
  if [ ! -f "$filePath" ]; then
    logme "missing ${filePath}"
    exit 1
  fi

  logme -v "Reading $filePath"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

function get_repo_license() {
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

function resolve_package_license() {
    local formula_file="${1:-}"

    if [[ -n "${PACKAGE_LICENSE:-}" ]]; then
        echo "$PACKAGE_LICENSE"
        return 0
    fi

    if [[ -n "${REPO:-}" ]]; then
        local license
        if license=$(get_repo_license "$REPO") && [[ -n "$license" ]]; then
            logme "[NFPM] License for ${REPO}: ${license}" >&2
            [[ -n "$formula_file" ]] && echo "PACKAGE_LICENSE=\"${license}\"" >> "$formula_file"
            PACKAGE_LICENSE="$license"
            echo "$license"
            return 0
        fi
    fi

    local user_license
    printf '[NFPM] License not found for %s. Enter SPDX identifier (e.g. MIT, Apache-2.0): ' "$DPKG_BASENAME" >/dev/tty
    read -r user_license < /dev/tty
    [[ -z "$user_license" ]] && user_license="unknown"
    [[ -n "$formula_file" ]] && echo "PACKAGE_LICENSE=\"${user_license}\"" >> "$formula_file"
    PACKAGE_LICENSE="$user_license"
    echo "$user_license"
    return 0
}

# Cache key shared between the version-prefetch phase (runner.sh) and the
# get_latest_ver* lookups below, so both sides derive the same filename.
function version_cache_key() {
    case "$1" in
        github)    echo "github_${2//\//_}" ;;
        url_html)  echo "html_${2}" ;;
        hashicorp) echo "hashicorp_${2}" ;;
    esac
}

function get_latest_ver_hashicorp() {
    local product="$1"
    if [[ -n "${VERSION_CACHE_DIR:-}" ]]; then
        local cache_file="$VERSION_CACHE_DIR/$(version_cache_key hashicorp "$product")"
        [[ -f "$cache_file" ]] && cat "$cache_file" && return 0
    fi
    local result
    result=$(curl -qsL "https://api.releases.hashicorp.com/v1/releases/${product}/latest" | jq -r '.version')
    if [[ -z "$result" || "$result" == "null" ]]; then
        echo "Could not get version for HashiCorp product: $product"
        return 1
    fi
    echo "$result"
}

function get_latest_ver_html() {
    local url="$1"
    local regex="$2"
    # Keyed by DPKG_BASENAME (global, already sourced from the formula by the
    # caller) to match the key the prefetch phase derives for this formula.
    if [[ -n "${VERSION_CACHE_DIR:-}" && -n "${DPKG_BASENAME:-}" ]]; then
        local cache_file="$VERSION_CACHE_DIR/$(version_cache_key url_html "$DPKG_BASENAME")"
        [[ -f "$cache_file" ]] && cat "$cache_file" && return 0
    fi
    local result
    result=$(curl -qsL "$url" | grep -oP "$regex" | head -1)
    if [[ -z "$result" ]]; then
        echo "Could not extract version from $url with regex: $regex"
        return 1
    fi
    echo "$result"
}

function get_latest_ver () {
	# The cache only ever stores the plain tag_name (no $2/date mode), so
	# bypass it when the caller asked for the tag+date form.
	if [[ -z "${2:-}" && -n "${VERSION_CACHE_DIR:-}" ]]; then
	    cache_file="$VERSION_CACHE_DIR/$(version_cache_key github "$1")"
	    if [[ -f "$cache_file" ]]; then
	        cat "$cache_file"
	        return 0
	    fi
	fi
	if [[ ! -z $GITHUB_TOKEN ]]; then
	   EXTRA_ARGS=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
	   )
	else
           EXTRA_ARGS=()
        fi
	OUTPUT=$(curl "${EXTRA_ARGS[@]}" -qs https://api.github.com/repos/$1/releases/latest)
	if [[ "$OUTPUT" == *"API rate limit exceeded for"* || "$OUTPUT" == *"secondary rate limit"* ]]; then
	  echo "Github API rate limit exceeded. Try later."
	  return 1
	fi
    if [ ! -z $2 ]; then
        TAG_NAME=$(echo "$OUTPUT"| jq -r '.tag_name')
        REL_DATE=$(echo "$OUTPUT"| jq -r '.published_at')
        if [[ -z "$TAG_NAME" || "$TAG_NAME" == "null" ]]; then
            echo "Could not get tag_name from GitHub API for $1"
            return 1
        fi
        echo $TAG_NAME $REL_DATE
        return 0
    fi
    local tag_name
    tag_name=$(echo "$OUTPUT" | jq -r '.tag_name')
    if [[ -z "$tag_name" || "$tag_name" == "null" ]]; then
        echo "Could not get tag_name from GitHub API for $1 (response: $(echo "$OUTPUT" | jq -r '.message // "unknown error"'))"
        return 1
    fi
	echo "$tag_name"
	return 0
}

function vprint {
	if [ ! -z $VERBOSE ] && [ $VERBOSE -eq 1 ]; then
		echo $*
	fi
}

function date_diff {
    now_ts=$(date +%s)
    target_ts=$(date -d "$1" +%s)
    diff_sec=$(( target_ts - now_ts ))
    diff_days=$(( diff_sec / 86400 * -1 ))

    echo "$diff_days"
}

function get_stored_version() {
    local repo="$1"
    if [ ! -f $DB_FILE ]; then
      echo ""
      return 0
    fi
    grep -E "^${repo}=" "$DB_FILE" 2>/dev/null | cut -d'=' -f2
}

function set_stored_version() {
    local repo="$1"
    local version="$2"
    if grep -qE "^${repo}=" "$DB_FILE"; then
        sed -i "s|^${repo}=.*|${repo}=${version}|" "$DB_FILE"
    else
        echo "${repo}=${version}" >> "$DB_FILE"
    fi
}

function var_substitution() {
    VARS_TO_SUBST=(DOWNLOAD_FILENAME REPO DPKG_ARCH TARGET_ARCH DPKG_BASENAME LATEST_VER DPKG_VERSION HASHICORP_PRODUCT)
    RET="$1"
    shift

    if [[ $# -gt 0 ]]; then
        VARS_TO_SUBST=("$@")
    fi

    local max_loops=5
    local _count=0
    while [[ "$RET" == *'$'* && $_count -lt $max_loops ]]; do
        for var in "${VARS_TO_SUBST[@]}"; do
            if [[ -n "${!var+x}" ]]; then
                #echo "Substituting variable [$_count] $var - ${!var}"
                val="${!var}"  # Indirect expansion to get value of the variable
                RET="${RET//\$$var/$val}"
                RET="${RET//\$\{$var\}/$val}"
            fi
        done
        _count=$(( _count + 1 ))
    done
    echo "$RET"
}

function ts () {
    date +"[%Y-%m-%d %H:%M:%S]"
}

# logme: print/log a message with options.
# Usage:
#   logme [-v] [-n] [-e EOL] message...
#   -v    also send the message to vprint
#   -n    do NOT append any end-of-line to stdout
#   -e    custom EOL (default "\n"); supports escapes like "\r\n"
#
# Notes:
# - If $RUNLOG is set, the message is appended to that file with a timestamp.
# - When both -n and -e are given, -n takes precedence (no EOL printed).

logme() {
  local verbose=0
  local no_eol=0
  local eol="\n"
  local OPTIND=1 opt

  while getopts ":vne:" opt; do
    case "$opt" in
      v) verbose=1 ;;
      n) no_eol=1 ;;
      e) eol="$OPTARG" ;;
      \?)
        printf 'Usage: logme [-v] [-n] [-e EOL] message...\n' >&2
        return 2
        ;;
    esac
  done
  shift $((OPTIND - 1))

  # Remaining args form the message
  local msg="$*"
  [ -z "$msg" ] && { printf 'logme: empty message\n' >&2; return 2; }

  # Write to log if requested
  if [ -n "$RUNLOG" ]; then
    # Keep logging always newline-terminated
    printf "%s %s\n" "$(ts)" "$msg" >> "$RUNLOG"
  fi

  # Verbose path
  if [ "$verbose" -eq 1 ]; then
    vprint "$msg"
  else
  # Stdout path
    if [ "$no_eol" -eq 1 ]; then
     printf "%s" "$msg"
    else
    # %b interprets backslash escapes in $eol
      printf "%s%b" "$msg" "$eol"
    fi
  fi
}

# Live per-package build progress: header -> steps -> success/failure.
# Errors are only ever printed inline, never re-shown by the caller, to avoid duplication.

pkg_header() {
  local repo="$1" from="$2" to="$3"
  printf "${C_CYAN}==>${C_RESET} ${C_BOLD}%s${C_RESET} ${C_DIM}(%s → %s)${C_RESET}\n" "$repo" "$from" "$to"
  [ -n "$RUNLOG" ] && printf "%s ==> %s (%s -> %s)\n" "$(ts)" "$repo" "$from" "$to" >> "$RUNLOG"
}

up_to_date() {
  local repo="$1" ver="$2"
  printf -- "${C_DIM}--> %-24s up to date (%s)${C_RESET}\n" "$repo" "$ver"
  [ -n "$RUNLOG" ] && printf -- "%s --> %s up to date (%s)\n" "$(ts)" "$repo" "$ver" >> "$RUNLOG"
}

step_start() {
  printf "    ${C_DIM}→${C_RESET} %s..." "$1"
}

step_ok() {
  printf " ${C_GREEN}ok${C_RESET}\n"
}

step_fail() {
  printf " ${C_RED}FAILED${C_RESET}\n"
}

step_warn() {
  printf " ${C_YELLOW}WARN${C_RESET}\n"
}

step_error() {
  printf "      ${C_RED}%s${C_RESET}\n" "$1"
  [ -n "$RUNLOG" ] && printf "%s     %s\n" "$(ts)" "$1" >> "$RUNLOG"
}

step_warning() {
  printf "      ${C_YELLOW}%s${C_RESET}\n" "$1"
  [ -n "$RUNLOG" ] && printf "%s     %s\n" "$(ts)" "$1" >> "$RUNLOG"
}

pkg_success() {
  printf "${C_GREEN}==>${C_RESET} ${C_BOLD}%s${C_RESET} built ${C_GREEN}✔${C_RESET}\n\n" "$1"
  [ -n "$RUNLOG" ] && printf "%s ==> %s built OK\n" "$(ts)" "$1" >> "$RUNLOG"
}

pkg_error() {
  printf "${C_RED}✘ %s: %s${C_RESET}\n" "$1" "$2"
  [ -n "$RUNLOG" ] && printf "%s ERROR %s: %s\n" "$(ts)" "$1" "$2" >> "$RUNLOG"
}

pkg_failure() {
  local repo="$1" step="$2"
  printf "${C_RED}==>${C_RESET} ${C_RED}%s build failed at '%s'${C_RESET}\n" "$repo" "$step"
  printf "    ${C_YELLOW}skipping version bump for %s${C_RESET}\n\n" "$repo"
  [ -n "$RUNLOG" ] && printf "%s ==> %s build failed at '%s'\n" "$(ts)" "$repo" "$step" >> "$RUNLOG"
}

# pkg_warning: like pkg_failure, but for a known non-error upstream condition
# (e.g. a GitHub "latest release" with no assets attached) that still means
# we can't build this run, without it being a config/pipeline bug.
pkg_warning() {
  local repo="$1" msg="$2"
  printf "${C_YELLOW}==>${C_RESET} ${C_YELLOW}%s: %s${C_RESET}\n" "$repo" "$msg"
  printf "    ${C_DIM}skipping version bump for %s${C_RESET}\n\n" "$repo"
  [ -n "$RUNLOG" ] && printf "%s ==> WARN %s: %s\n" "$(ts)" "$repo" "$msg" >> "$RUNLOG"
}

# get_github_release_asset_count: number of assets attached to a repo's
# latest GitHub release, or empty on API failure (caller should treat that as
# "unknown", not as zero).
get_github_release_asset_count() {
    local repo="$1"
    local extra_args=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        extra_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
        )
    fi
    local output
    output=$(curl "${extra_args[@]}" -qs "https://api.github.com/repos/${repo}/releases/latest")
    jq -r '.assets | length' <<< "$output" 2>/dev/null
}

# build_cron_summary: turn one run's RUNLOG into a short human-readable report
# (packages updated, packages warned, packages failed). Relies on the
# "==> NAME (FROM -> TO)", "==> NAME built OK", "==> WARN NAME: MSG",
# "==> NAME build failed at 'STEP'" and "ERROR NAME: MSG" lines already
# written by pkg_header/pkg_success/pkg_warning/pkg_failure/pkg_error.
build_cron_summary() {
    local runlog="$1"
    local -A pending_ver=()
    local updated=() warned=() failed=()
    local line name range step

    while IFS= read -r line; do
        if [[ "$line" == *" ==> "*" ("*" -> "*")" ]]; then
            name=$(sed -E 's/^.*==> ([^ ]+) \(.*$/\1/' <<< "$line")
            range=$(sed -E 's/^.*\((.*)\)$/\1/' <<< "$line")
            pending_ver["$name"]="$range"
        elif [[ "$line" == *" ==> "*" built OK" ]]; then
            name=$(sed -E 's/^.*==> (.*) built OK$/\1/' <<< "$line")
            updated+=("- ${name}: ${pending_ver[$name]:-updated}")
        elif [[ "$line" == *" ==> WARN "* ]]; then
            name=$(sed -E 's/^.*==> WARN ([^:]+):.*$/\1/' <<< "$line")
            step=$(sed -E 's/^.*==> WARN [^:]+: (.*)$/\1/' <<< "$line")
            warned+=("- ${name}: ${step}")
        elif [[ "$line" == *" ==> "*" build failed at "* ]]; then
            name=$(sed -E "s/^.*==> (.*) build failed at '.*'\$/\1/" <<< "$line")
            step=$(sed -E "s/^.*build failed at '(.*)'\$/\1/" <<< "$line")
            failed+=("- ${name}: failed at ${step}")
        elif [[ "$line" == *" ERROR "* ]]; then
            failed+=("- $(sed -E 's/^.*ERROR //' <<< "$line")")
        fi
    done < "$runlog"

    if [[ ${#updated[@]} -eq 0 && ${#warned[@]} -eq 0 && ${#failed[@]} -eq 0 ]]; then
        echo "No updates. All packages up to date."
        return 0
    fi

    if [[ ${#updated[@]} -gt 0 ]]; then
        printf 'Updated (%d):\n' "${#updated[@]}"
        printf '%s\n' "${updated[@]}"
    fi
    if [[ ${#warned[@]} -gt 0 ]]; then
        [[ ${#updated[@]} -gt 0 ]] && printf '\n'
        printf 'Warnings (%d):\n' "${#warned[@]}"
        printf '%s\n' "${warned[@]}"
    fi
    if [[ ${#failed[@]} -gt 0 ]]; then
        [[ ${#updated[@]} -gt 0 || ${#warned[@]} -gt 0 ]] && printf '\n'
        printf 'Failed (%d):\n' "${#failed[@]}"
        printf '%s\n' "${failed[@]}"
    fi
}

# send_apprise_notification: post a title/body message to the Apprise webhook
# configured in APPRISE_URL (.env). No-op (with a log line) if unset.
send_apprise_notification() {
    local title="$1" body="$2"

    if [[ -z "${APPRISE_URL:-}" ]]; then
        logme "APPRISE_URL not set, skipping notification"
        return 0
    fi

    local payload
    payload=$(jq -n --arg title "$title" --arg body "$body" '{title: $title, body: $body}')

    if ! curl -fsS -X POST "$APPRISE_URL" -H 'Content-Type: application/json' -d "$payload" >/dev/null; then
        logme "Failed to send Apprise notification"
    fi
}

# analyze_log: send a run log to an LLM (via OpenRouter) and print back what
# failed and how to fix it. Only the tail of the log is sent to keep the
# request small.
analyze_log() {
    local logfile="$1"

    if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
        echo "Set OPENROUTER_API_KEY in .env to use log analysis (-L --analyze)." >&2
        return 1
    fi

    local model="${ANALYZE_MODEL:-anthropic/claude-sonnet-4.6}"
    local log_content
    log_content=$(tail -n 500 "$logfile")

    local system_prompt="You are a build-log analyst for packagerone, a DEB/RPM packaging pipeline. Given a run log, identify what failed and why, then give a concise, actionable fix."

    local payload
    payload=$(jq -n \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user "$log_content" \
        '{
            model: $model,
            temperature: 0.0,
            max_tokens: 1024,
            messages: [
                {role: "system", content: $system},
                {role: "user", content: $user}
            ]
        }')

    local resp
    resp=$(curl -qsX POST "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $OPENROUTER_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    echo "$resp" | jq -r '.choices[0].message.content // .error.message // "No response from LLM."'
}

# Print archive contents and a short tree of the build folder to aid troubleshooting
print_archive_listing() {
  # Avoid spamming: print only once per run
  if [ -n "$_PRINTED_ARCHIVE" ]; then
    return 0
  fi
  local archive="${BUILD_FOLDER:-}/$DOWNLOAD_FILENAME"
  echo "[DEBUG] Build folder: ${BUILD_FOLDER:-<unset>}"
  if [ -f "$archive" ]; then
    echo "[DEBUG] Archive: $archive"
    case "$archive" in
      *.tar|*.tar.gz|*.tar.bz2|*.tar.xz|*.t?z)
        tar -tf "$archive" 2>/dev/null | head -n 200 ;;
      *.zip)
        unzip -l "$archive" 2>/dev/null | head -n 200 ;;
      *.gz)
        gzip -l "$archive" 2>/dev/null || true ;;
      *)
        echo "[DEBUG] Unknown archive type"
        ;;
    esac
  else
    echo "[DEBUG] Archive file not found: $archive"
  fi
  #if [ -n "$BUILD_FOLDER" ] && [ -d "$BUILD_FOLDER" ]; then
  #  echo "[DEBUG] Extracted files (top 200):"
  #  (cd "$BUILD_FOLDER" && find . -maxdepth 4 -print 2>/dev/null | sort | head -n 200)
  #fi
  _PRINTED_ARCHIVE=1
}
