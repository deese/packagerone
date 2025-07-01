#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

# Common package building functions
build_deb () {
    mkdir -p $OUTPUT_FOLDER/deb

    # Validate required variables
    if [[ -z "$REPO" || -z "$DPKG_BASENAME" || -z "$DOWNLOAD_FILENAME" || -z "$INSTALL_FILES" ]]; then
        echo "Error: Missing required configuration variables"
        exit 1
    fi

    # Get latest version
    LATEST_VER=$(get_latest_ver "$REPO")
    if [ $? -eq 1 ]; then
        echo "Fatal error: $LATEST_VER"
        exit 1
    fi

    # Setup package variables
    DPKG_VERSION="${LATEST_VER#v}"
    DPKG_DIR="$BUILD_FOLDER/${DPKG_BASENAME}-${LATEST_VER}-${TARGET_ARCH}"
    DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
    DPKG_PATH="$OUTPUT_FOLDER/deb/$DPKG_NAME"

    logme "Building $DPKG_BASENAME deb package"
    # Check if package already exists
    if [ -f "$DPKG_PATH" ]; then
        echo "File already exists: $DPKG_PATH"
        return 0
    fi

    # Download file
    DOWNLOAD_FILENAME="$BUILD_FOLDER/$(var_substitution "$DOWNLOAD_FILENAME")"
    DOWNLOAD_URL=$(var_substitution "$DOWNLOAD_URL_TEMPLATE")

    if [ ! -f $DOWNLOAD_FILENAME ]; then
        $WGET "$DOWNLOAD_URL" -O "$DOWNLOAD_FILENAME"
    fi

    if [ ! -f "$DOWNLOAD_FILENAME" ]; then
        echo "Error downloading file: $DOWNLOAD_URL"
        return  1
    fi

    # Extract if needed
    if [[ -n "$EXTRACT_CMD" ]]; then
        $EXTRACT_CMD "$DOWNLOAD_FILENAME"
    fi

    # Install files
    for entry in "${INSTALL_FILES[@]}"; do
        IFS='|' read -r source perms destination <<< "$entry"
        source=$(var_substitution "$source")
        install -Dm"$perms" "$source" "${DPKG_DIR}$destination"
    done

    # Create DEBIAN directory and control file
    mkdir -p "${DPKG_DIR}/DEBIAN"
    _DESC=$(echo -e "$PACKAGE_DESCRIPTION" | sed '2,$s/^/\t/')
    
    cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: https://github.com/${REPO}
Architecture: ${DPKG_ARCH}
Description: $_DESC
EOF

    ## Clean old files

    OLD_DPKG_NAME="${DPKG_BASENAME}_*_${DPKG_ARCH}.deb"
    for i in $DPKG_PATH/$OLD_DPKG_NAME; do
        echo Removing old file: $i
        rm -f "$i"
    done
     
    # Build package
    fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"

    # Cleanup
    if [[ -n "$CLEANUP_FILES" ]]; then
        rm -fr $CLEANUP_FILES
    fi
    rm -fr "${DPKG_DIR}" "$DOWNLOAD_FILENAME"

    # Update version tracking
    set_stored_version "$REPO" "$LATEST_VER"
    echo "[SUCCESS] Built $DPKG_PATH"
    echo 1 > "$CHANGES_FILE"
    return 0 
}
