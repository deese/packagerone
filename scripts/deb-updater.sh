CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

packages=(
  "ajeetdsouza/zoxide|0.9.8|zoxide_\$VERSION-1_amd64.deb"
  "sharkdp/fd|10.2.0|fd_\$VERSION_amd64.deb"
  "sharkdp/bat|0.25.0|bat_\$VERSION_amd64.deb"
  "sharkdp/hexyl|0.16.0|hexyl_\$VERSION_amd64.deb"
)

for entry in "${packages[@]}"; do
  IFS='|' read -r repo version filename <<< "$entry"

  # Replace $VERSION in filename
  filename="${filename//\$VERSION/$version}"

  if [ ! -f "$OUTPUT_FOLDER/$filename" ] ; then

        echo "Repo: $repo"
        echo "Version: $version"
        echo "Filename: $filename"
        echo "-----"
        wget "https://github.com/$repo/releases/download/v$version/$filename" -O $OUTPUT_FOLDER/$filename
  fi
done
