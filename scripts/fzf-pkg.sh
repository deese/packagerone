CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

REPO="junegunn/fzf"
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
DPKG_BASENAME="fzf"
ORIG_FILENAME="fzf-$DPKG_VERSION-linux_$DPKG_ARCH.tar.gz"
URL="https://github.com/$REPO/releases/download/$LATEST_VER/$ORIG_FILENAME"
DPKG_DIR="fzf-$LATEST_VER$TARGET_ARCH"
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

install -Dm755 "fzf" "${DPKG_DIR}/usr/bin/fzf"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat >"${DPKG_DIR}/DEBIAN/control" <<EOF
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

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr fzf ${DPKG_DIR} $ORIG_FILENAME
