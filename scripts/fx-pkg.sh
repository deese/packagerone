CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

REPO="antonmedv/fx"
LATEST_VER=$(get_latest_ver $REPO)
if [ $? -eq 1 ]; then
     echo Fatal error: $version
     exit 1
fi

CURRENT_VERSION=$(get_stored_version "$REPO")

if [[ "$LATEST_VER" == "$CURRENT_VERSION" ]]; then
   echo "[INFO] $REPO is up to date ($CURRENT_VERSION)"
   exit 0
fi


DPKG_VERSION="${LATEST_VER#v}"
DPKG_BASENAME="fx"
ORIG_FILENAME="fx_linux_$DPKG_ARCH"
URL="https://github.com/$REPO/releases/download/$LATEST_VER/fx_linux_$DPKG_ARCH"
DPKG_DIR="fx-$LATEST_VER-$TARGET_ARCH"
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

install -Dm755 "$ORIG_FILENAME" "${DPKG_DIR}/usr/bin/fx"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Description: Fx is a CLI for JSON: it shows JSON interactively in your terminal, and lets you transform JSON with JavaScript. Fx is written in Go and uses goja as its embedded JavaScript engine.
EOF

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr ${DPKG_DIR} $ORIG_FILENAME
