#SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "$SCRIPT_DIR/scripts/environ.sh"

mkdir -p $OUTPUT_FOLDER $LOGFOLDER

function read_env() {
  local filePath="${1:-.env}"
  echo Loading environment  $filePath
  if [ ! -f "$filePath" ]; then
    echo "missing ${filePath}"
    exit 1
  fi

  echo "Reading $filePath"
  while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Remove leading and trailing whitespaces, and carriage return
    CLEANED_LINE=$(echo "$LINE" | awk '{$1=$1};1' | tr -d '\r')

    if [[ $CLEANED_LINE != '#'* ]] && [[ $CLEANED_LINE == *'='* ]]; then
      export "$CLEANED_LINE"
    fi
  done < "$filePath"
}

function get_latest_ver () {
	if [[ ! -z $GITHUB_TOKEN ]]; then
	   EXTRA_ARGS=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
	   )
	   #EXTRA_ARGS="-H \"Authorization: Bearer $GITHUB_TOKEN\" -H \"Accept: application/vnd.github+json\""
	else
           EXTRA_ARGS=() #""
        fi
	OUTPUT=$(curl "${EXTRA_ARGS[@]}" -qs https://api.github.com/repos/$1/releases/latest)
	if [[ "$OUTPUT" == *"API rate limit exceeded for"* ]]; then
	  echo "Github API exceeded. Try later."
	  return 1
	fi
    if [ ! -z $2 ]; then
        TAG_NAME=$(echo "$OUTPUT"| jq -r '.tag_name')
        REL_DATE=$(echo "$OUTPUT"| jq -r '.published_at')
        echo $TAG_NAME $REL_DATE
        return 0
    fi
	echo "$OUTPUT"| jq -r '.tag_name'
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
    VARS_TO_SUBST=(DOWNLOAD_FILENAME REPO DPKG_ARCH TARGET_ARCH DPKG_BASENAME LATEST_VER DPKG_VERSION)
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
    return 
  fi

  # Stdout path
  if [ "$no_eol" -eq 1 ]; then
    printf "%s" "$msg"
  else
    # %b interprets backslash escapes in $eol
    printf "%s%b" "$msg" "$eol"
  fi
}

function logme_old () {
    EOL="\n"
    if [ ! -z "$RUNLOG" ]; then
        echo "$(ts) $1" >> $RUNLOG
    fi
    if [[ $2 -eq 1 ]]; then
      vprint "$1"
    else
      if [[ ! -z "$2" ]]; then
        EOL="$2"
      fi
      echo -n "$1$EOL"
    fi
}
