MAINTAINER="Deese <deese2k@gmail.com>"
DPKG_ARCH="amd64"
TARGET_ARCH="x86_64"
WGET="wget -q"
OUTPUT_FOLDER="dist"
PKG1UPLOADTRK=".upload_tracker"

mkdir -p $OUTPUT_FOLDER

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
	OUTPUT=$(curl -qs https://api.github.com/repos/$1/releases/latest)
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

