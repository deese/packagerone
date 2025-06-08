#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh
REPO="eza-community/eza"
echo $CHANGES_FILE
LATEST_VER=$(get_latest_ver $REPO)

if [ $? -eq 1 ]; then
     echo Fatal error: $LATEST_VER
     exit 1
fi

CURRENT_VERSION=$(get_stored_version "$REPO")

if [[ "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
   echo "[INFO] $REPO is up to date ($CURRENT_VERSION)"
   exit 0
fi


DPKG_VERSION="${LATEST_VER#v}"
DPKG_BASENAME="eza"
ORIG_FILENAME="eza_$TARGET_ARCH-unknown-linux-gnu.tar.gz"
URL="https://github.com/$REPO/releases/download/$LATEST_VER/$ORIG_FILENAME"
DPKG_DIR="eza-$LATEST_VER-$TARGET_ARCH"
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

tar zxf $ORIG_FILENAME

install -Dm755 "eza" "${DPKG_DIR}/usr/bin/eza"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Description: eza is a modern alternative for the venerable file-listing command-line program ls that
  ships with Unix and Linux operating systems, giving it more features and better defaults.
  It uses colours to distinguish file types and metadata. It knows about symlinks,
  extended attributes, and Git. And it’s small, fast, and just one single binary.
EOF

DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr eza ${DPKG_DIR} $ORIG_FILENAME
