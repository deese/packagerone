CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

REPO="https://github.com/junegunn/fzf"
DPKG_BASENAME="fzf"
DPKG_VERSION="0.62.0"
ORIG_FILENAME="fzf-$DPKG_VERSION-linux_$DPKG_ARCH.tar.gz"
URL="$REPO/releases/download/v$DPKG_VERSION/$ORIG_FILENAME"
DPKG_DIR="fzf-v$DPKG_VERSION-$TARGET_ARCH"
DPKG_CONFLICTS=""
DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"


$WGET $URL

if [ ! -f $ORIG_FILENAME ]; then
  echo Error downloading file.
  exit
fi
tar zxf $ORIG_FILENAME


install -Dm755 "fzf" "${DPKG_DIR}/usr/bin/fzf"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat > "${DPKG_DIR}/DEBIAN/control" << EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Description: fzf is a general-purpose command-line fuzzy finder.
  It's an interactive filter program for any kind of list; files, command history, processes, hostnames, bookmarks,
  git commits, etc. It implements a "fuzzy" matching algorithm, so you can quickly type in patterns with omitted
  characters and still get the results you want.
EOF

DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr fzf ${DPKG_DIR} $ORIG_FILENAME
