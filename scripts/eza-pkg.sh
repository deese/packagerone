source environ.sh

REPO="https://github.com/eza-community/eza"
TARGET_ARCH="x86_64"
DPKG_ARCH="amd64"
DPKG_BASENAME="eza"
DPKG_VERSION="0.21.3"
ORIG_FILENAME="eza_$TARGET_ARCH-unknown-linux-gnu.tar.gz"
URL="$REPO/releases/download/v$DPKG_VERSION/$ORIG_FILENAME"
DPKG_DIR="eza-v$DPKG_VERSION-$TARGET_ARCH"
DPKG_CONFLICTS=""
DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"


wget $URL

if [ ! -f $ORIG_FILENAME ]; then
  echo Error downloading file.
  exit
fi

tar zxvf $ORIG_FILENAME

install -Dm755 "eza" "${DPKG_DIR}/usr/bin/eza"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat > "${DPKG_DIR}/DEBIAN/control" << EOF
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

mkdir -p dist
DPKG_PATH="./dist/$DPKG_NAME"

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr eza ${DPKG_DIR} $ORIG_FILENAME
