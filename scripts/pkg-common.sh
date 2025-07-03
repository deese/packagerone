#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"
source "$CDIR/rpm-builder.sh"
source "$CDIR/deb-builder.sh"

# Common package building functions
build_package() {
    local config_file="$1"

    # Source the configuration
    source "$config_file"
    
    logme "[PKGBUILD] Building package with formula: $1"

    # Validate required variables
    if [[ -z "$REPO" || -z "$DPKG_BASENAME" || -z "$DOWNLOAD_FILENAME" || -z "$INSTALL_FILES" ]]; then
        logme "[PKGBUILD] Error: Missing required configuration variables"
        exit 1
    fi

    # Get latest version
    LATEST_VER=$(get_latest_ver "$REPO")
    if [ $? -eq 1 ]; then
        logme "[PKGBUILD] Fatal error: $LATEST_VER"
        exit 1
    fi

    # Check if already up to date
    CURRENT_VERSION=$(get_stored_version "$REPO")
    if [[ $FORCE -ne 1 && "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
        logme "[PKGBUILD] $REPO is up to date ($CURRENT_VERSION)"
        return 0
    fi
    
    if [ ! -n "$_TMPFOLDER" ]; then
        _TMPFOLDER=$(mktemp -dt "pkgone-XXXXXXXX")
        BUILD_FOLDER="$_TMPFOLDER/build"
        mkdir -p $BUILD_FOLDER
    fi

    # Setup package variables
    DPKG_VERSION="${LATEST_VER#v}"
    DPKG_DIR="${DPKG_BASENAME}-${LATEST_VER}-${TARGET_ARCH}"
    DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
    DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"
    PACKAGE_VERSION=$DPKG_VERSION

    # Download file
    DOWNLOAD_FILENAME=$(var_substitution "$DOWNLOAD_FILENAME")
    DOWNLOAD_URL=$(var_substitution "$DOWNLOAD_URL_TEMPLATE")
    logme "[PKGBUILD] Using build folder: $BUILD_FOLDER" 

    logme "[PKGBUILD] Downloading file: $DOWNLOAD_URL" 1
    $WGET "$DOWNLOAD_URL" -O  "$BUILD_FOLDER/$DOWNLOAD_FILENAME"

    if [ ! -f "$BUILD_FOLDER/$DOWNLOAD_FILENAME" ]; then
        logme "[PKGBUILD] Error downloading file: $DOWNLOAD_URL" 
        return  1
    else 
        logme "[PKGBUILD] File downloaded to $BUILD_FOLDER/$DOWNLOAD_FILENAME" 1
    fi

    # Extract if needed
    logme "[PKGBUILD] Extracting file"

    if [[ -n "$EXTRACT_CMD" ]]; then
        if [[ "$EXTRACT_CMD" == *"tar"* ]]; then
            echo "Extracting to $BUILD_FOLDER" 
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME" -C "$BUILD_FOLDER"
        else
            echo "Regular extract"
            $EXTRACT_CMD "$BUILD_FOLDER/$DOWNLOAD_FILENAME"
        fi
    fi

    logme "[PKGBUILD] File extracted. Running builders"

    if [ ${SKIP_DEB_PACKAGE:-0} -ne 1 ]; then
        build_deb
    fi
    
    if [ ${SKIP_RPM_PACKAGE:-0} -ne 1 ]; then
        build_rpm
    fi

    # Cleanup
    if [[ -n "$CLEANUP_FILES" ]]; then
        logme "[PKGBUILD] Cleaning up files." 1
        rm -fr $CLEANUP_FILES
    fi

    rm -fr "${DPKG_DIR}" "$DOWNLOAD_FILENAME"

    # Update version tracking
    set_stored_version "$REPO" "$LATEST_VER"
    logme "[SUCCESS] Built $DPKG_BASENAME"
    echo 1 > "$CHANGES_FILE"
    return 0
}
