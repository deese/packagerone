MAINTAINER="Deese <deese2k@gmail.com>"
DPKG_ARCH="amd64"
TARGET_ARCH="x86_64"
WGET="wget -q"
OUTPUT_FOLDER="dist"

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


