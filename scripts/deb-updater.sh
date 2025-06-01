CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

packages=(
  "ajeetdsouza/zoxide|0.9.8|zoxide_\$VERSION-1_amd64.deb|v"
  "sharkdp/fd|10.2.0|fd_\$VERSION_amd64.deb|v"
  "sharkdp/bat|0.25.0|bat_\$VERSION_amd64.deb|v"
  "sharkdp/hexyl|0.16.0|hexyl_\$VERSION_amd64.deb|v"
  "burntsushi/ripgrep|14.1.1|ripgrep_\$VERSION-1_amd64.deb|"
)

for entry in "${packages[@]}"; do
  IFS='|' read -r repo version filename extra_ver <<< "$entry"

  # Replace $VERSION in filename
  filename="${filename//\$VERSION/$version}"

  if [ ! -f "$OUTPUT_FOLDER/$filename" ] ; then

        echo "Repo: $repo"
        echo "Version: $version"
        echo "Filename: $filename"
	echo "Extraver: $extraver"
        echo "-----"
        wget "https://github.com/$repo/releases/download/$extraver$version/$filename" -O $OUTPUT_FOLDER/$filename
  fi
done
