#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"
source "$CDIR/rpm-builder.sh"
source "$CDIR/deb-builder.sh"
source "$CDIR/nfpm-builder.sh"

# Common package building functions
build_package() {
    local config_file="$1"
    local build_failed=0
    local rc=0

    # Reset all formula variables before sourcing to prevent leakage between formulas
    unset FORMULA_TYPE REPO HASHICORP_PRODUCT VERSION_URL VERSION_REGEX HOMEPAGE
    unset DPKG_BASENAME DOWNLOAD_FILENAME DOWNLOAD_URL_TEMPLATE EXTRACT_CMD
    unset INSTALL_FILES CLEANUP_FILES PACKAGE_DESCRIPTION PACKAGE_SUMMARY PACKAGE_LICENSE
    unset LATEST_VER DPKG_VERSION DPKG_DIR DPKG_NAME DPKG_PATH PACKAGE_VERSION

    # Source the configuration
    source "$config_file"

    local pkg_name="${REPO:-$DPKG_BASENAME}"

    # Validate required variables
    local _ftype="${FORMULA_TYPE:-github}"
    if [[ -z "$DPKG_BASENAME" || -z "$DOWNLOAD_FILENAME" || -z "$INSTALL_FILES" ]]; then
        pkg_error "$pkg_name" "Missing required configuration variables"
        return 1
    fi

    # Get latest version based on formula type
    local VERSION_KEY
    case "$_ftype" in
        github)
            if [[ -z "$REPO" ]]; then
                pkg_error "$pkg_name" "github formula requires REPO"
                return 1
            fi
            if ! LATEST_VER=$(get_latest_ver "$REPO"); then
                pkg_error "$pkg_name" "$LATEST_VER"
                return 1
            fi
            VERSION_KEY="$REPO"
            ;;
        url_html)
            if [[ -z "$VERSION_URL" || -z "$VERSION_REGEX" ]]; then
                pkg_error "$pkg_name" "url_html formula requires VERSION_URL and VERSION_REGEX"
                return 1
            fi
            if ! LATEST_VER=$(get_latest_ver_html "$VERSION_URL" "$VERSION_REGEX") || [[ -z "$LATEST_VER" ]]; then
                pkg_error "$pkg_name" "could not get version from $VERSION_URL"
                return 1
            fi
            VERSION_KEY="$DPKG_BASENAME"
            ;;
        hashicorp)
            if [[ -z "$HASHICORP_PRODUCT" ]]; then
                pkg_error "$pkg_name" "hashicorp formula requires HASHICORP_PRODUCT"
                return 1
            fi
            if ! LATEST_VER=$(get_latest_ver_hashicorp "$HASHICORP_PRODUCT") || [[ -z "$LATEST_VER" ]]; then
                pkg_error "$pkg_name" "could not get version for HashiCorp product: $HASHICORP_PRODUCT"
                return 1
            fi
            VERSION_KEY="hashicorp/$HASHICORP_PRODUCT"
            ;;
        *)
            pkg_error "$pkg_name" "Unknown FORMULA_TYPE: $_ftype"
            return 1
            ;;
    esac

    # Check if already up to date
    CURRENT_VERSION=$(get_stored_version "$VERSION_KEY")
    if [[ $FORCE -ne 1 && "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
        up_to_date "$pkg_name" "$CURRENT_VERSION"
        return 0
    fi

    pkg_header "$pkg_name" "${CURRENT_VERSION:-none}" "$LATEST_VER"


    if [ ! -n "$_TMPFOLDER" ]; then
        _TMPFOLDER=$(mktemp -dt "pkgone-XXXXXXXX")
        BUILD_FOLDER="$_TMPFOLDER/build"
        mkdir -p $BUILD_FOLDER
    fi

    # Setup package variables
    DPKG_VERSION=$(echo "${LATEST_VER}" | sed 's/^[^0-9]*//')
    DPKG_DIR="${DPKG_BASENAME}-${LATEST_VER}-${TARGET_ARCH}"
    DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
    DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"
    PACKAGE_VERSION=$DPKG_VERSION

    # Download file
    DOWNLOAD_FILENAME=$(var_substitution "$DOWNLOAD_FILENAME")
    DOWNLOAD_URL=$(var_substitution "$DOWNLOAD_URL_TEMPLATE")
    logme -v "[PKGBUILD] Using build folder: $BUILD_FOLDER"

    step_start "download"
    rc=0
    $WGET "$DOWNLOAD_URL" -O  "$BUILD_FOLDER/$DOWNLOAD_FILENAME"  ||  rc=$?

    if [[ ! -z $rc && $rc -ne 0 ]]; then
        step_fail
        step_error "wget failed (rc=$rc) for $DOWNLOAD_URL"
        pkg_failure "$pkg_name" "download"
        return 1
    fi
    step_ok
    logme -v "[PKGBUILD] File downloaded to $BUILD_FOLDER/$DOWNLOAD_FILENAME"

    # Extract if needed
    step_start "extract"

    if [[ -n "$EXTRACT_CMD" ]]; then
        if [[ "$EXTRACT_CMD" == *"tar"* ]]; then
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME" -C "$BUILD_FOLDER" >> "$RUNLOG" 2>&1
        elif [[ "$EXTRACT_CMD" == "unzip" ]]; then
            unzip -o "$BUILD_FOLDER/$DOWNLOAD_FILENAME" -d "$BUILD_FOLDER" >> "$RUNLOG" 2>&1
        elif [[ "$EXTRACT_CMD" == "cp" ]]; then
            #cp "$BUILD_FOLDER/$DOWNLOAD_FILENAME" "$BUILD_FOLDER"
            true
        elif [[ "$EXTRACT_CMD" == "gunzip" ]]; then
            gunzip "$BUILD_FOLDER/$DOWNLOAD_FILENAME" >> "$RUNLOG" 2>&1
        else
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME" >> "$RUNLOG" 2>&1
        fi
    fi

    step_ok

    if [[ "${USE_NFPM:-0}" -eq 1 ]]; then
        if ! build_nfpm "$config_file"; then
            build_failed=1
        fi
    else
        if [ ${SKIP_DEB_PACKAGE:-0} -ne 1 ]; then
            if ! build_deb; then
                build_failed=1
            fi
        fi

        if [ ${SKIP_RPM_PACKAGE:-0} -ne 1 ]; then
            if ! build_rpm; then
                build_failed=1
            fi
        fi
    fi

    # Cleanup (paths are relative to BUILD_FOLDER, not $PWD)
    if [[ -n "$CLEANUP_FILES" ]]; then
        logme -v "[PKGBUILD] Cleaning up files."
        for _cf in $CLEANUP_FILES; do
            _cf=$(var_substitution "$_cf")
            rm -fr "${BUILD_FOLDER}/${_cf}"
        done
    fi

    # Update version tracking
    if [[ $build_failed -ne 0 ]]; then
        pkg_failure "$pkg_name" "package build"
        return 1
    fi

    set_stored_version "$VERSION_KEY" "$LATEST_VER"
    pkg_success "$pkg_name"
    echo 1 > "$CHANGES_FILE"
    return 0
}
