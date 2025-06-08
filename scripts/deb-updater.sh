CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

packages=(
  "ajeetdsouza/zoxide|zoxide_\$VERSION-1_amd64.deb"
  "sharkdp/fd|fd_\$VERSION_amd64.deb"
  "sharkdp/bat|bat_\$VERSION_amd64.deb"
  "sharkdp/hexyl|hexyl_\$VERSION_amd64.deb"
  "burntsushi/ripgrep|ripgrep_\$VERSION-1_amd64.deb"
)

for entry in "${packages[@]}"; do
  #IFS="|" read -r repo filename <<< "$entry"
  repo="${entry%%|*}"
  filename="${entry#*|}"
  current_version=$(get_stored_version "$repo")
  version=$(get_latest_ver $repo)	

  if [ $? -eq 1 ]; then
     echo Fatal error: $version
     exit 1
  fi

  if [[ "$version" == "$current_version" ]]; then
        echo "[INFO] $repo is up to date ($current_version)"
	continue
  fi

  F_VERSION="${version#v}"
  filename="${filename//\$VERSION/$F_VERSION}"

  if [ ! -f "$OUTPUT_FOLDER/$filename" ]; then
    echo "Repo: $repo"
    echo "Version: $version"
    echo "Filename: $filename"
    echo "-----"
    $WGET "https://github.com/$repo/releases/download/$version/$filename" -O $OUTPUT_FOLDER/$filename
    set_stored_version "$repo" "$version"
    echo 1 > $CHANGES_FILE
  else
    vprint [debup] File already exist: $filename
  fi
exit 0
done
