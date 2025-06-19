#!/bin/bash
set -e
source scripts/environ.sh
source scripts/pkg-common.sh
source scripts/deb-updater.sh
source scripts/rpm-builder.sh

packages=(
#  "ajeetdsouza/zoxide|zoxide_\$VERSION-1_amd64.deb"
  "sharkdp/fd|fd_\$VERSION_amd64.deb"
  "sharkdp/bat|bat_\$VERSION_amd64.deb"
  "sharkdp/hexyl|hexyl_\$VERSION_amd64.deb"
#  "burntsushi/ripgrep|ripgrep_\$VERSION-1_amd64.deb"
  "dandavison/delta|git-delta_\$VERSION_amd64.deb"
)

export CHANGES_FILE=$(mktemp --suffix ".changes")

function do_upload {
    if [ ! -z "$PKG1UPLOADER" ]; then
      if [ ! -f "./scripts/uploader_$PKG1UPLOADER.sh" ]; then
        echo "uploader_$PKG1UPLOADER.sh doesn't exit"
        exit
      fi
      echo "Running uploader - $PKG1UPLOADER"
      bash ./scripts/uploader_$PKG1UPLOADER.sh
    fi
}
function cleanup {
  if [ -f $CHANGES_FILE ]; then
    rm -f $CHANGES_FILE
  fi
  unset CHANGES_FILE
}
trap cleanup EXIT

read_env

while getopts "ufVvhF:" opt; do
  case "$opt" in
    F)
        if [[ -z "$OPTARG" ]]; then
            echo "Error: -F requires a github repository name"
            exit 1
        fi
        bash ./scripts/creator/formula_creator.sh "$OPTARG"
        exit 0
        ;;
    f)
      FORCE=1
      ;;
    V)
      check_versions=1
      ;;
    v)
      VERBOSE=1
      ;;
    u)
       do_upload
       exit 0
       ;; 
    *)
      echo "Usage: $0 [-V] [-v] [-f]"
      exit 1
      ;;
  esac
done

if [[ $check_versions -eq 1 ]]; then
  echo "Checking versions..."
  bash ./scripts/version_check.sh
  exit 1
fi

#for entry in "${packages[@]}"; do
#  process_deb_file "$entry"
#done
echo $FORCE
for i in formulas/*.formula; do
  build_package $i
done

exit 0

if [ -s $CHANGES_FILE ]; then
    do_upload
fi

