#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh
source $CDIR/pkg-common.sh

# Package-specific configuration
REPO="neovim/neovim"
DPKG_BASENAME="neovim"
DOWNLOAD_FILENAME="nvim-linux-\$TARGET_ARCH.appimage"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD=""
INSTALL_CMD="install -Dm755 \"\$DOWNLOAD_FILE\" \"\${DPKG_DIR}/usr/bin/nvim\""
CLEANUP_FILES="\$DOWNLOAD_FILE"
PACKAGE_DESCRIPTION="Neovim is a project that seeks to aggressively refactor Vim in order to:
	Simplify maintenance and encourage contributions
	Split the work between multiple developers
	Enable advanced UIs without modifications to the core
	Maximize extensibility
	See the Introduction wiki page and Roadmap for more information."

build_package "$0"
