CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

REPO="neovim/neovim"
LATEST_VER=$(get_latest_ver $REPO)

if [ $? -eq 1 ]; then
     echo Fatal error: $version
     exit 1
fi

DPKG_VERSION="${LATEST_VER#v}"
DPKG_BASENAME="neovim"
ORIG_FILENAME="nvim-linux-$TARGET_ARCH.appimage"
URL="https://github.com/$REPO/releases/download/$LATEST_VER/$ORIG_FILENAME"
DPKG_DIR="nvim-$LATEST_VER-$TARGET_ARCH"
DPKG_CONFLICTS=""
DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"
DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

if [ -f $DPKG_PATH ]; then
        echo File already exists: $DPKG_PATH
        exit
fi

$WGET $URL

if [ ! -f $ORIG_FILENAME ]; then
  echo Error downloading file: $URL.
  exit
fi

install -Dm755 "$ORIG_FILENAME" "${DPKG_DIR}/usr/bin/nvim"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Description: Neovim is a project that seeks to aggressively refactor Vim in order to:
	Simplify maintenance and encourage contributions
	Split the work between multiple developers
	Enable advanced UIs without modifications to the core
	Maximize extensibility
	See the Introduction wiki page and Roadmap for more information. 
EOF

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr ${DPKG_DIR} $ORIG_FILENAME
