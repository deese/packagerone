#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

build_nfpm() {
    local formula_file="${1:-}"
    local nfpm_config="${BUILD_FOLDER}/nfpm-${DPKG_BASENAME}.yaml"
    local build_failed=0

    if ! command -v nfpm &>/dev/null; then
        step_start "package"
        step_fail
        step_error "nfpm not found. Install it or set USE_NFPM=0"
        return 1
    fi

    local license
    license=$(resolve_package_license "${formula_file}")

    local desc_indented
    desc_indented=$(printf '%s' "$PACKAGE_DESCRIPTION" | sed 's/^/  /')

    local homepage="${HOMEPAGE:-https://github.com/${REPO:-}}"

    cat > "$nfpm_config" <<EOF
name: "${DPKG_BASENAME}"
arch: "${DPKG_ARCH}"
version: "${DPKG_VERSION}"
maintainer: "${MAINTAINER}"
description: |
${desc_indented}
homepage: "${homepage}"
license: "${license}"
contents:
EOF

    for entry in "${INSTALL_FILES[@]}"; do
        IFS='|' read -r src perms dst <<< "$entry"
        src=$(var_substitution "$src")
        [[ "$src" != "/"* ]] && src="${BUILD_FOLDER}/${src}"
        cat >> "$nfpm_config" <<EOF
  - src: "${src}"
    dst: "${dst}"
    file_info:
      mode: 0${perms}
EOF
    done

    logme -v "[NFPM] Config written to $nfpm_config"

    if [[ "${SKIP_DEB_PACKAGE:-0}" -ne 1 ]]; then
        mkdir -p "$OUTPUT_FOLDER/deb"
        step_start "build deb"
        local new_deb="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
        if ! nfpm pkg --packager deb --config "$nfpm_config" --target "$OUTPUT_FOLDER/deb/" >> "$RUNLOG" 2>&1; then
            step_fail
            step_error "nfpm deb build failed. Check $RUNLOG"
            build_failed=1
        else
            step_ok
            find "$OUTPUT_FOLDER/deb/" -name "${DPKG_BASENAME}_*_${DPKG_ARCH}.deb" ! -name "$new_deb" -delete
        fi
    fi

    if [[ "${SKIP_RPM_PACKAGE:-0}" -ne 1 ]]; then
        mkdir -p "$OUTPUT_FOLDER/rpm/$TARGET_ARCH"
        step_start "build rpm"
        local new_rpm="${DPKG_BASENAME}-${DPKG_VERSION}-1.${TARGET_ARCH}.rpm"
        if ! nfpm pkg --packager rpm --config "$nfpm_config" --target "$OUTPUT_FOLDER/rpm/$TARGET_ARCH/" >> "$RUNLOG" 2>&1; then
            step_fail
            step_error "nfpm rpm build failed. Check $RUNLOG"
            build_failed=1
        else
            step_ok
            find "$OUTPUT_FOLDER/rpm/$TARGET_ARCH/" -name "${DPKG_BASENAME}-*-*.${TARGET_ARCH}.rpm" ! -name "$new_rpm" -delete
        fi
    fi

    return $build_failed
}
