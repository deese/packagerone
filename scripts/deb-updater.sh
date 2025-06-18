CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh


function process_deb_file() {
  entry="$1"
  repo="${entry%%|*}"
  filename="${entry#*|}"
  current_version=$(get_stored_version "$repo")
  version=$(get_latest_ver $repo)
  
  if [ $? -eq 1 ]; then
    echo Fatal error: $version
    return 1
  fi

  if [[ "$version" == "$current_version" ]]; then
    echo "[INFO] $repo is up to date ($current_version)"
    continue
  fi

  F_VERSION="${version#v}"
  filename="${filename//\$VERSION/$F_VERSION}"
  DEB_OUTPUT="$OUTPUT_FOLDER/deb/$filename"

  if [ ! -f "$OUTPUT_FOLDER/$filename" ]; then
    echo "Repo: $repo"
    echo "Version: $version"
    echo "Filename: $filename"
    echo "-----"
    $WGET "https://github.com/$repo/releases/download/$version/$filename" -O $DEB_OUTPUT
    set_stored_version "$repo" "$version"
    echo 1 > $CHANGES_FILE
  else
    vprint [debup] File already exist: $filename
  fi
  return  0
}
