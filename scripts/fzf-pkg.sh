#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh
source $CDIR/pkg-common.sh

# Package-specific configuration
REPO="junegunn/fzf"
DPKG_BASENAME="fzf"
DOWNLOAD_FILENAME="fzf-\$DPKG_VERSION-linux_\$DPKG_ARCH.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf \$DOWNLOAD_FILE"
INSTALL_CMD="install -Dm755 \"fzf\" \"\${DPKG_DIR}/usr/bin/fzf\""
CLEANUP_FILES="fzf \$DOWNLOAD_FILE"
PACKAGE_DESCRIPTION="fzf is a general-purpose command-line fuzzy finder.
  It's an interactive filter program for any kind of list; files, command history, processes, hostnames, bookmarks,
  git commits, etc. It implements a \"fuzzy\" matching algorithm, so you can quickly type in patterns with omitted
  characters and still get the results you want."

build_package "$0"
