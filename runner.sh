#!/bin/bash
export SCRIPT_DIR=$(dirname "$(realpath "$0")")
set -e


source "$SCRIPT_DIR/scripts/functions.sh"
source "$SCRIPT_DIR/scripts/pkg-common.sh"
source "$SCRIPT_DIR/scripts/deb-updater.sh"
source "$SCRIPT_DIR/scripts/rpm-builder.sh"

packages=(
)

export CHANGES_FILE=$(mktemp --suffix ".changes")

function do_upload {
    if [ ! -z "$PKG1UPLOADER" ]; then
        logme -v "Uploader set to: $PKG1UPLOADER"
      if [ ! -f "$SCRIPT_DIR/scripts/uploader_$PKG1UPLOADER.sh" ]; then
        logme "uploader_$PKG1UPLOADER.sh doesn't exit"
        echo "uploader_$PKG1UPLOADER.sh doesn't exit"
        exit
      fi
      logme "Running uploader - $PKG1UPLOADER"
      bash $SCRIPT_DIR/scripts/uploader_$PKG1UPLOADER.sh $CHANGES_FILE
    fi
}
function cleanup {
  if [ -f $CHANGES_FILE ]; then
    rm -f $CHANGES_FILE
  fi
  if [ -f "$BUILD_FOLDER" ]; then
    logme -v "Removing build folder: $BUILD_FOLDER"
    rm -fr "$BUILD_FOLDER"
  fi
  unset CHANGES_FILE
}
trap cleanup EXIT

read_env $SCRIPT_DIR/.env

while getopts "ufVvhF:b:RD" opt; do
  case "$opt" in
    b)
        if [[ -z "$OPTARG" ]]; then
            echo "Error: -b requires a formula"
            exit 1
        fi
        echo "Buil package $OPTARG"
	    build_package "$OPTARG"
        exit 0
		;;

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
      echo "-----"
      echo "-b - Build specific formula"
      echo "-D - Skip DEB package creation"
      echo "-f - force build without checking versions"
      echo "-F <repository/name> - Automatically create formulas using AI (this requires human review)"
      echo "-R - Skip RPM package creation"
      echo "-u - Upload created packages"
      echo "-v - Enable verbose mode"
      echo "-V - Run version check and exit."
      echo "---------------"
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

if [ -s $CHANGES_FILE ]; then
    logme "Changes detected. Running upload script if available."
    do_upload
fi

