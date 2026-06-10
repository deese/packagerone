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

    PAD_SIZE=$(( $(max_strlen line < <(grep ^REPO $SCRIPT_DIR/formulas/* | cut -f2 -d=)) * -1 ))
    PAD_REPO=$(pad "${REPO:-$DPKG_BASENAME}" $PAD_SIZE)
    logme -n "[PKGBUILD] Building $PAD_REPO"

    # Validate required variables
    local _ftype="${FORMULA_TYPE:-github}"
    if [[ -z "$DPKG_BASENAME" || -z "$DOWNLOAD_FILENAME" || -z "$INSTALL_FILES" ]]; then
        logme "\n[PKGBUILD] Error: Missing required configuration variables"
        exit 1
    fi

    # Get latest version based on formula type
    local VERSION_KEY
    case "$_ftype" in
        github)
            if [[ -z "$REPO" ]]; then
                logme "\n[PKGBUILD] Error: github formula requires REPO"
                exit 1
            fi
            LATEST_VER=$(get_latest_ver "$REPO")
            if [[ $? -ne 0 ]]; then
                logme "\n[PKGBUILD] Fatal error: $LATEST_VER"
                exit 1
            fi
            VERSION_KEY="$REPO"
            ;;
        url_html)
            if [[ -z "$VERSION_URL" || -z "$VERSION_REGEX" ]]; then
                logme "\n[PKGBUILD] Error: url_html formula requires VERSION_URL and VERSION_REGEX"
                exit 1
            fi
            LATEST_VER=$(get_latest_ver_html "$VERSION_URL" "$VERSION_REGEX")
            if [[ $? -ne 0 || -z "$LATEST_VER" ]]; then
                logme "\n[PKGBUILD] Fatal error: could not get version from $VERSION_URL"
                exit 1
            fi
            VERSION_KEY="$DPKG_BASENAME"
            ;;
        hashicorp)
            if [[ -z "$HASHICORP_PRODUCT" ]]; then
                logme "\n[PKGBUILD] Error: hashicorp formula requires HASHICORP_PRODUCT"
                exit 1
            fi
            LATEST_VER=$(get_latest_ver_hashicorp "$HASHICORP_PRODUCT")
            if [[ $? -ne 0 || -z "$LATEST_VER" ]]; then
                logme "\n[PKGBUILD] Fatal error: could not get version for HashiCorp product: $HASHICORP_PRODUCT"
                exit 1
            fi
            VERSION_KEY="hashicorp/$HASHICORP_PRODUCT"
            ;;
        *)
            logme "\n[PKGBUILD] Error: Unknown FORMULA_TYPE: $_ftype"
            exit 1
            ;;
    esac

    # Check if already up to date
    CURRENT_VERSION=$(get_stored_version "$VERSION_KEY")
    if [[ $FORCE -ne 1 && "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
        logme " - Up to date ($CURRENT_VERSION)"
        return 0
    else
      logme " - Building version: $CURRENT_VERSION → $LATEST_VER"
    fi


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
    logme "[PKGBUILD] Using build folder: $BUILD_FOLDER"

    logme -v "[PKGBUILD] Downloading file: $DOWNLOAD_URL"
    rc=0
    $WGET "$DOWNLOAD_URL" -O  "$BUILD_FOLDER/$DOWNLOAD_FILENAME"  ||  rc=$?

    if [[ ! -z $rc && $rc -ne 0 ]]; then
        # [ ! -f "$BUILD_FOLDER/$DOWNLOAD_FILENAME" && ! -s "$BUILD_FOLDER/$DOWNLOAD_FILENAME" ]; then
        logme "[PKGBUILD] Error downloading file (rc=$rc): $DOWNLOAD_URL"
        logme "[PKGBUILD] Skipping package due to download error"
        return 1
    else
        logme -v "[PKGBUILD] File downloaded to $BUILD_FOLDER/$DOWNLOAD_FILENAME"
    fi

    # Extract if needed
    logme "[PKGBUILD] Extracting file"

    if [[ -n "$EXTRACT_CMD" ]]; then
        if [[ "$EXTRACT_CMD" == *"tar"* ]]; then
            echo "Extracting to $BUILD_FOLDER"
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME" -C "$BUILD_FOLDER"
        elif [[ "$EXTRACT_CMD" == "unzip" ]]; then
            unzip -o "$BUILD_FOLDER/$DOWNLOAD_FILENAME" -d "$BUILD_FOLDER"
        elif [[ "$EXTRACT_CMD" == "cp" ]]; then
            #cp "$BUILD_FOLDER/$DOWNLOAD_FILENAME" "$BUILD_FOLDER"
            true
        elif [[ "$EXTRACT_CMD" == "gunzip" ]]; then
            ls -l  "$BUILD_FOLDER/$DOWNLOAD_FILENAME"
            gunzip "$BUILD_FOLDER/$DOWNLOAD_FILENAME"
            ls -l "$BUILD_FOLDER"
        else
            echo "Regular extract"
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME"
        fi
    fi

    logme "[PKGBUILD] File extracted. Running builders"

    if [[ "${USE_NFPM:-0}" -eq 1 ]]; then
        if ! build_nfpm "$config_file"; then
            logme "[PKGBUILD] build_nfpm failed"
            build_failed=1
        fi
    else
        if [ ${SKIP_DEB_PACKAGE:-0} -ne 1 ]; then
            if ! build_deb; then
                logme "[PKGBUILD] build_deb failed"
                build_failed=1
            fi
        fi

        if [ ${SKIP_RPM_PACKAGE:-0} -ne 1 ]; then
            if ! build_rpm; then
                logme "[PKGBUILD] build_rpm failed"
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
        logme "[PKGBUILD] Build encountered errors. Skipping version update."
        return 1
    fi

    set_stored_version "$VERSION_KEY" "$LATEST_VER"
    logme "[SUCCESS] Built $DPKG_BASENAME"
    echo 1 > "$CHANGES_FILE"
    return 0
}
