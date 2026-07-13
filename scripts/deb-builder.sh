#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

# Common package building functions
build_deb () {
    mkdir -p $OUTPUT_FOLDER/deb

    # Validate required variables
    if [[ -z "$DPKG_BASENAME" || -z "$DOWNLOAD_FILENAME" || -z "$INSTALL_FILES" ]]; then
        step_start "build deb"
        step_fail
        step_error "Missing required configuration variables"
        return 1
    fi

    # Setup package variables
    #DPKG_VERSION="${LATEST_VER#v}"
    DPKG_VERSION="${LATEST_VER#[rv]}"
    DPKG_DIR="$BUILD_FOLDER/${DPKG_BASENAME}-${LATEST_VER}-${TARGET_ARCH}"
    DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
    DPKG_PATH="$OUTPUT_FOLDER/deb/$DPKG_NAME"

    step_start "build deb"

    if [[ "$DPKG_VERSION" =~ [^0-9.-] ]]; then
      step_fail
      step_error "\$DPKG_VERSION contains invalid characters: $DPKG_VERSION"
      return 1
    fi

    # Check if package already exists
    if [[ "$FORCE" -eq 0 && -f "$DPKG_PATH" ]]; then
        step_ok
        logme -v "[DEB] File already exists: $DPKG_PATH"
        return 0
    fi

    # Install files
    for entry in "${INSTALL_FILES[@]}"; do
        IFS='|' read -r source perms destination <<< "$entry"
        source=$(var_substitution "$source")
        [ -n "$RUNLOG" ] && echo "Installing $source from $BUILD_FOLDER" >> "$RUNLOG"
        if [[ "$source" != "/"* ]]; then
            source="$BUILD_FOLDER/$source"
        fi
        if [ -f "$source" ]; then
            install -Dm"$perms" "$source" "${DPKG_DIR}$destination"
        elif [ -d "$source" ]; then
            install -d -Dm"$perms" "$source" "${DPKG_DIR}$destination"
        else
            [ -n "$RUNLOG" ] && echo "File doesn't exist: $source" >> "$RUNLOG"
            print_archive_listing >> "$RUNLOG" 2>&1
        fi
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
Homepage: ${HOMEPAGE:-https://github.com/${REPO}}
Architecture: ${DPKG_ARCH}
Description: $_DESC
EOF

    ## Clean old files

    OLD_DPKG_NAME="${DPKG_BASENAME}_*_${DPKG_ARCH}.deb"
   
    for i in $OUTPUT_FOLDER/deb/$OLD_DPKG_NAME; do
        logme -v "[DEB] Removing old file: $i"
        rm -f "$i"
    done
     
    # Build package
    if ! fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}" >> "$RUNLOG" 2>&1; then
        step_fail
        step_error "dpkg-deb failed. Check $RUNLOG"
        return 1
    fi

    # Cleanup
    #if [[ -n "$CLEANUP_FILES" ]]; then
    #    rm -fr $CLEANUP_FILES
    #fi
    #rm -fr "${DPKG_DIR}" "$DOWNLOAD_FILENAME"

    step_ok
    logme -v "[DEB] Successfully built $DPKG_PATH"
    return 0
}
