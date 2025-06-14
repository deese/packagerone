#!/bin/bash
set -e
source scripts/environ.sh
source scripts/pkg-common.sh
source scripts/deb-updater.sh

packages=(
  "ajeetdsouza/zoxide|zoxide_\$VERSION-1_amd64.deb"
  "sharkdp/fd|fd_\$VERSION_amd64.deb"
  "sharkdp/bat|bat_\$VERSION_amd64.deb"
  "sharkdp/hexyl|hexyl_\$VERSION_amd64.deb"
  "burntsushi/ripgrep|ripgrep_\$VERSION-1_amd64.deb"
)

export CHANGES_FILE=$(mktemp --suffix ".changes")

function cleanup {
  if [ -f $CHANGES_FILE ]; then
    rm -f $CHANGES_FILE
  fi
  unset CHANGES_FILE
}
trap cleanup EXIT

read_env

while getopts "Vvh" opt; do
  case "$opt" in
    V)
      check_versions=1
      ;;
    v)
      VERBOSE=1
      ;;
    *)
      echo "Usage: $0 [-V] [-v]"
      exit 1
      ;;
  esac
done

if [[ $check_versions -eq 1 ]]; then
  echo "Checking versions..."
  bash ./scripts/version_check.sh
  exit 1
fi

for entry in "${packages[@]}"; do
  process_deb_file "$entry"
done

for i in formulas/*.formula; do
  build_package $i
done

if [ -s $CHANGES_FILE ]; then
	if [ ! -z "$PKG1UPLOADER" ]; then
	  if [ ! -f "./scripts/uploader_$PKG1UPLOADER.sh" ]; then
	    echo "uploader_$PKG1UPLOADER.sh doesn't exit"
	    exit
	  fi
	  echo "Running uploader - $PKG1UPLOADER"
	  bash ./scripts/uploader_$PKG1UPLOADER.sh
	fi
fi

