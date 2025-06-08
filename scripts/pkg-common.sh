#!/bin/bash

var_substitution() {
    VARS_TO_SUBST=(REPO DPKG_ARCH TARGET_ARCH DPKG_BASENAME LATEST_VER DOWNLOAD_FILENAME DPKG_VERSION)
    RET=$1
    for var in "${VARS_TO_SUBST[@]}"; do
        if [[ -n "${!var+x}" ]]; then
            #echo "Substituting variable: $var"
            val="${!var}"  # Indirect expansion to get value of the variable
            RET="${RET//\$$var/$val}"
        fi
    done
    echo "$RET"
}

# Common package building functions
build_package() {
    local config_file="$1"

    # Source the configuration
    source "$config_file"

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

    # Check if already up to date
    CURRENT_VERSION=$(get_stored_version "$REPO")
    if [[ "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
        echo "[INFO] $REPO is up to date ($CURRENT_VERSION)"
        return 0
    fi

    # Setup package variables
    DPKG_VERSION="${LATEST_VER#v}"
    DPKG_DIR="${DPKG_BASENAME}-${LATEST_VER}-${TARGET_ARCH}"
    DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
    DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

    # Check if package already exists
    if [ -f "$DPKG_PATH" ]; then
        echo "File already exists: $DPKG_PATH"
        return 0
    fi

    # Download file
    DOWNLOAD_FILENAME=$(var_substitution "$DOWNLOAD_FILENAME")
    DOWNLOAD_URL=$(var_substitution "$DOWNLOAD_URL_TEMPLATE")

    $WGET "$DOWNLOAD_URL"

    if [ ! -f "$DOWNLOAD_FILENAME" ]; then
        echo "Error downloading file: $DOWNLOAD_URL"
        return  0
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
    cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: https://github.com/${REPO}
Architecture: ${DPKG_ARCH}
Description: ${PACKAGE_DESCRIPTION}
EOF

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
