#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh
source $CDIR/pkg-common.sh

# Package-specific configuration
REPO="antonmedv/fx"
DPKG_BASENAME="fx"
DOWNLOAD_FILENAME="fx_linux_\$DPKG_ARCH"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/fx_linux_\$DPKG_ARCH"
EXTRACT_CMD=""
INSTALL_CMD="install -Dm755 \"\$DOWNLOAD_FILE\" \"\${DPKG_DIR}/usr/bin/fx\""
CLEANUP_FILES="\$DOWNLOAD_FILE"
PACKAGE_DESCRIPTION="Fx is a CLI for JSON: it shows JSON interactively in your terminal, and lets you transform JSON with JavaScript. Fx is written in Go and uses goja as its embedded JavaScript engine."

build_package "$0"
