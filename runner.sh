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

# -L and -C are read-only actions (print/analyze the last log, check formula
# config); don't let them create a new (near-empty) log file of their own
# before we even parse options.
for arg in "$@"; do
    if [[ "$arg" =~ ^-[a-zA-Z]*[LC][a-zA-Z]*$ ]]; then
        unset RUNLOG
        break
    fi
done

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
  if [ "${CRON_NOTIFY:-0}" -eq 1 ]; then
    logme "Cron run finished. Sending summary."
    summary="$(build_cron_summary "$RUNLOG")"
    send_apprise_notification "PackageOne ($(hostname))" "$summary"$'\n\n'
  fi
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
CRON_MODE=0
LOG_MODE=0
ANALYZE_MODE=0

# getopts can't parse the long-form "--analyze" flag alongside short options,
# so strip it out of the argument list up front and track it separately.
ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "--analyze" ]]; then
        ANALYZE_MODE=1
    else
        ARGS+=("$arg")
    fi
done
set -- "${ARGS[@]}"

while getopts "ufVvhF:b:RDcLC" opt; do
  case "$opt" in
    b) FORMULA_TO_BUILD="$OPTARG" ;;
    F) FORMULA_TO_CREATE="$OPTARG" ;;
    f) FORCE=1 ;;
    V) check_versions=1 ;;
    v) VERBOSE=1 ;;
    u) DO_UPLOAD=1 ;;
    R) SKIP_RPM_PACKAGE=1 ;;
    D) SKIP_DEB_PACKAGE=1 ;;
    c) CRON_MODE=1 ;;
    L) LOG_MODE=1 ;;
    C) CHECK_FORMULAS=1 ;;
    *)
      echo "Usage: $0 [-V] [-v] [-f] [-R] [-D] [-c] [-L [--analyze]] [-C]"
      echo "-----"
      echo "-b - Build specific formula"
      echo "-c - Cron mode: silence stdout, keep the run log, send an Apprise/Telegram summary at the end"
      echo "-C - Check every formula's resolved download against upstream and exit"
      echo "-D - Skip DEB package creation"
      echo "-f - force build without checking versions"
      echo "-F <repository/name> - Automatically create formulas using AI (this requires human review)"
      echo "-L [--analyze] - Print the last run log; with --analyze, send it to an LLM (OpenRouter) to explain the failure"
      echo "-R - Skip RPM package creation"
      echo "-u - Upload created packages"
      echo "-v - Enable verbose mode"
      echo "-V - Run version check and exit."
      echo "---------------"
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

if [[ "${CHECK_FORMULAS:-0}" -eq 1 ]]; then
    echo "Checking formula configuration against upstream..."
    bash "$SCRIPT_DIR/scripts/check_formulas.sh"
    exit $?
fi

if [[ "$LOG_MODE" -eq 1 ]]; then
    LATEST_LOG=$(ls -t "$LOGFOLDER"/*.log 2>/dev/null | head -1)
    if [[ -z "$LATEST_LOG" ]]; then
        echo "No log files found in $LOGFOLDER" >&2
        exit 1
    fi
    if [[ "$ANALYZE_MODE" -eq 1 ]]; then
        analyze_log "$LATEST_LOG"
    else
        cat "$LATEST_LOG"
    fi
    exit 0
fi

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

if [[ $CRON_MODE -eq 1 ]]; then
    exec >/dev/null 2>&1
    CRON_NOTIFY=1
    logme "Cron run started"
fi

prefetch_versions

for i in $SCRIPT_DIR/formulas/*.formula; do
  rc=0
  build_package $i || rc=$?
  if [[ $rc -eq 2 ]]; then
    logme "[WARN] No upstream assets to build formula: $i"
  elif [[ $rc -ne 0 ]]; then
    logme "[ERROR] Failed to process formula: $i"
  fi
done

if [ -s $CHANGES_FILE ]; then
    logme "Changes detected. Running upload script if available."
    if [[ $CRON_MODE -eq 1 ]]; then
        do_upload || logme "[ERROR] Upload step failed"
    else
        do_upload
    fi
fi

