#!/bin/bash
export SCRIPT_DIR=$(dirname "$(realpath "$0")")
set -e

FORCE=0
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
        logme "uploader_$PKG1UPLOADER.sh doesn't exist"
        exit 1
      fi
      logme "Running uploader - $PKG1UPLOADER"
      bash $SCRIPT_DIR/scripts/uploader_$PKG1UPLOADER.sh $CHANGES_FILE
    fi
}
function cleanup {
  if [ -f $CHANGES_FILE ]; then
    rm -f $CHANGES_FILE
  fi
  if [ -d "${_TMPFOLDER:-}" ]; then
    logme -v "Removing temp folder: $_TMPFOLDER"
    rm -rf "$_TMPFOLDER"
  fi
  if [ -d "${VERSION_CACHE_DIR:-}" ]; then
    rm -rf "$VERSION_CACHE_DIR"
  fi
  unset CHANGES_FILE
}
trap cleanup EXIT

# Resolve the version of every formula concurrently before the (serial) build
# loop, so the ~30 sequential GitHub/HashiCorp/HTML lookups don't dominate an
# all-up-to-date run. Builds themselves stay serial (shared BUILD_FOLDER,
# versions.db written with sed -i). Self-healing: a job that fails to write a
# cache file just falls through to a live lookup during the build phase.
function prefetch_versions {
    export VERSION_CACHE_DIR=$(mktemp -d)
    local max_jobs=8

    for formula in "$SCRIPT_DIR"/formulas/*.formula; do
        (
            unset FORMULA_TYPE REPO HASHICORP_PRODUCT VERSION_URL VERSION_REGEX DPKG_BASENAME
            source "$formula"
            local ftype="${FORMULA_TYPE:-github}"
            local key ver
            case "$ftype" in
                github)    key=$(version_cache_key github "$REPO"); ver=$(get_latest_ver "$REPO") ;;
                url_html)  key=$(version_cache_key url_html "$DPKG_BASENAME"); ver=$(get_latest_ver_html "$VERSION_URL" "$VERSION_REGEX") ;;
                hashicorp) key=$(version_cache_key hashicorp "$HASHICORP_PRODUCT"); ver=$(get_latest_ver_hashicorp "$HASHICORP_PRODUCT") ;;
                *) exit 0 ;;
            esac
            [[ -n "$ver" ]] && printf '%s' "$ver" > "$VERSION_CACHE_DIR/$key"
        ) &
        while (( $(jobs -rp | wc -l) >= max_jobs )); do wait -n; done
    done
    wait
}

read_env $SCRIPT_DIR/.env

function resolve_formula {
    local input="$1"
    for candidate in \
        "$input" \
        "${input}-pkg.formula" \
        "${input}.formula" \
        "$SCRIPT_DIR/formulas/${input}-pkg.formula" \
        "$SCRIPT_DIR/formulas/${input}.formula" \
        "$SCRIPT_DIR/formulas/${input}"
    do
        [[ -f "$candidate" ]] && echo "$candidate" && return 0
    done
    echo "Error: no formula found for: $input" >&2
    return 1
}

FORMULA_TO_BUILD=""
FORMULA_TO_CREATE=""
DO_UPLOAD=0

while getopts "ufVvhF:b:RD" opt; do
  case "$opt" in
    b) FORMULA_TO_BUILD="$OPTARG" ;;
    F) FORMULA_TO_CREATE="$OPTARG" ;;
    f) FORCE=1 ;;
    V) check_versions=1 ;;
    v) VERBOSE=1 ;;
    u) DO_UPLOAD=1 ;;
    R) SKIP_RPM_PACKAGE=1 ;;
    D) SKIP_DEB_PACKAGE=1 ;;
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

if [[ -n "$FORMULA_TO_CREATE" ]]; then
    FORCE=$FORCE VERBOSE=$VERBOSE bash $SCRIPT_DIR/scripts/creator/formula_creator.sh "$FORMULA_TO_CREATE"
    exit 0
fi

if [[ -n "$FORMULA_TO_BUILD" ]]; then
    formula=$(resolve_formula "$FORMULA_TO_BUILD") || exit 1
    echo "Build package $formula"
    build_package "$formula"
    exit 0
fi

if [[ "$DO_UPLOAD" -eq 1 ]]; then
    do_upload
    exit 0
fi

if [[ $check_versions -eq 1 ]]; then
  echo "Checking versions..."
  bash $SCRIPT_DIR/scripts/version_check.sh
  exit 1
fi

prefetch_versions

for i in $SCRIPT_DIR/formulas/*.formula; do
  build_package $i || logme "[ERROR] Failed to process formula: $i"
done

if [ -s $CHANGES_FILE ]; then
    logme "Changes detected. Running upload script if available."
    do_upload
fi

