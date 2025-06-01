### Old version. Not required as FD provides its own deb package now.
###
exit
MAINTAINER="Deese <deese2k@gmail.com>"
REPO="https://github.com/sharkdp/fd"
TARGET_ARCH="x86_64"
DPKG_ARCH="amd64"
DPKG_BASENAME="fd"
DPKG_VERSION="10.2.0"
URL="https://github.com/sharkdp/fd/releases/download/v$DPKG_VERSION/fd-v$DPKG_VERSION-$TARGET_ARCH-unknown-linux-gnu.tar.gz"
FOLDER_ORIG="fd-v$DPKG_VERSION-$TARGET_ARCH-unknown-linux-gnu"
DPKG_DIR="fd-v$DPKG_VERSION-$TARGET_ARCH"
DPKG_CONFLICTS="fd-find"
DPKG_NAME="${DPKG_BASENAME}_${DPKG_VERSION}_${DPKG_ARCH}.deb"


$WGET $URL
tar zxvf fd-v$DPKG_VERSION-$DPKG_ARCH-unknown-linux-gnu.tar.gz

install -Dm755 "${FOLDER_ORIG}/fd" "${DPKG_DIR}/usr/bin/fd"
# Man page
install -Dm644 "${FOLDER_ORIG}/fd.1" "${DPKG_DIR}/usr/share/man/man1/fd.1"
gzip -n --best "${DPKG_DIR}/usr/share/man/man1/fd.1"

# Autocompletion files
install -Dm644 "${FOLDER_ORIG}/autocomplete/fd.bash" "${DPKG_DIR}/usr/share/bash-completion/completions/fd"
install -Dm644 "${FOLDER_ORIG}/autocomplete/fd.fish" "${DPKG_DIR}/usr/share/fish/vendor_completions.d/fd.fish"
install -Dm644 "${FOLDER_ORIG}/autocomplete/_fd" "${DPKG_DIR}/usr/share/zsh/vendor-completions/_fd"
# Create symlinks so fdfind can be used as well:
ln -s "/usr/bin/fd" "${DPKG_DIR}/usr/bin/fdfind"
ln -s  './fd.bash' "${DPKG_DIR}/usr/share/bash-completion/completions/fdfind"
ln -s  './fd.fish' "${DPKG_DIR}/usr/share/fish/vendor_completions.d/fdfind.fish"
ln -s  './_fd' "${DPKG_DIR}/usr/share/zsh/vendor-completions/_fdfind"

mkdir -p "${DPKG_DIR}/DEBIAN"
cat > "${DPKG_DIR}/DEBIAN/control" << EOF
Package: ${DPKG_BASENAME}
Version: ${DPKG_VERSION}
Section: utils
Priority: optional
Maintainer: ${MAINTAINER}
Homepage: ${REPO}
Architecture: ${DPKG_ARCH}
Provides: fd
Conflicts: ${DPKG_CONFLICTS}
Description: simple, fast and user-friendly alternative to find
  fd is a program to find entries in your filesystem.
  It is a simple, fast and user-friendly alternative to find.
  While it does not aim to support all of finds powerful functionality, it provides
  sensible (opinionated) defaults for a majority of use cases.
EOF

DPKG_PATH="./$OUTPUT_FOLDER/$DPKG_NAME"

fakeroot dpkg-deb --build "${DPKG_DIR}" "${DPKG_PATH}"
rm -fr ${FOLDER_ORIG} ${DPKG_DIR} fd-*-unknown-linux-gnu.tar.gz
