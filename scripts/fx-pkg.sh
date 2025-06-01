CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh


REPO="https://github.com/antonmedv/fx"
TARGET_ARCH="x86_64"
DPKG_ARCH="amd64"
DPKG_BASENAME="fx"
DPKG_VERSION="36.0.3"
ORIG_FILENAME="fx_linux_$DPKG_ARCH"
URL="$REPO/releases/download/$DPKG_VERSION/fx_linux_$DPKG_ARCH"
DPKG_DIR="fx-v$DPKG_VERSION-$TARGET_ARCH"
DPKG_CONFLICTS=""
DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"


$WGET $URL

if [ ! -f $ORIG_FILENAME ]; then
  echo Error downloading file.
  exit
fi

install -Dm755 "$ORIG_FILENAME" "${DPKG_DIR}/usr/bin/fx"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat > "${DPKG_DIR}/DEBIAN/control" << EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Description: Fx is a CLI for JSON: it shows JSON interactively in your terminal, and lets you transform JSON with JavaScript. Fx is written in Go and uses goja as its embedded JavaScript engine.
EOF

DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr ${DPKG_DIR} $ORIG_FILENAME
