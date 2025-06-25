#!/bin/bash
SCRIPT_DIR=$(dirname "$(realpath "$0")")
set -e

source "$SCRIPT_DIR/scripts/functions.sh"
source "$SCRIPT_DIR/scripts/pkg-common.sh"
source "$SCRIPT_DIR/scripts/deb-updater.sh"
source "$SCRIPT_DIR/scripts/rpm-builder.sh"

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
      if [ ! -f "$SCRIPT_DIR/scripts/uploader_$PKG1UPLOADER.sh" ]; then
        logme "uploader_$PKG1UPLOADER.sh doesn't exit"
        echo "uploader_$PKG1UPLOADER.sh doesn't exit"
        exit
      fi
      logme "Running uploader - $PKG1UPLOADER"
      bash $SCRIPT_DIR/scripts/uploader_$PKG1UPLOADER.sh
    fi
}
function cleanup {
  if [ -f $CHANGES_FILE ]; then
    rm -f $CHANGES_FILE
  fi
  if [ -f "$BUILD_FOLDER" ]; then 
    logme "Removing build folder: $BUILD_FOLDER" 1 
    rm -fr "$BUILD_FOLDER"
  fi
  unset CHANGES_FILE
}
trap cleanup EXIT

read_env

while getopts "ufVvhF:RD" opt; do
  case "$opt" in
    F)
        if [[ -z "$OPTARG" ]]; then
            echo "Error: -F requires a github repository name"
            exit 1
        fi
        bash $SCRIPT_DIR/scripts/creator/formula_creator.sh "$OPTARG"
        exit 0
        ;;
    f)
      FORCE=1
      ;;
    R)
      SKIP_RPM_PACKAGE=1
      ;;
    D)
      SKIP_DEB_PACKAGE=1
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
    R)
      SKIP_RPM_PACKAGE=1
      ;;
    D)
      SKIP_DEB_PACKAGE=1
      ;;
    *)
      echo "Usage: $0 [-V] [-v] [-f] [-R] [-D]"
      exit 1
      ;;
  esac
done

if [[ $check_versions -eq 1 ]]; then
  echo "Checking versions..."
  bash $SCRIPT_DIR/scripts/version_check.sh
  exit 1
fi

for i in $SCRIPT_DIR/formulas/*.formula; do
  build_package $i
done

exit 0

if [ -s $CHANGES_FILE ]; then
    do_upload
fi

