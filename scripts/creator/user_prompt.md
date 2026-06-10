Here are examples of input → output per formula type:

### EXAMPLE 1 — github ###
Download url:
https://github.com/eza-community/eza/releases/download/v0.21.4/eza_x86_64-unknown-linux-gnu.tar.gz
File listing:
$ tar tvf eza_x86_64-unknown-linux-gnu.tar.gz
-rwxr-xr-x ces/users   2282480 2025-05-30 16:04 ./eza
Formula type: github
Type context: REPO: eza-community/eza
Repo description: A modern replacement for ls
Output:
# -*- mode: sh -*-
REPO="eza-community/eza"
DPKG_BASENAME="eza"
HOMEPAGE="https://eza.rocks"
DOWNLOAD_FILENAME="eza_\$TARGET_ARCH-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "eza|755|/usr/bin/eza"
)
CLEANUP_FILES="eza"
PACKAGE_DESCRIPTION="eza is a modern alternative for the venerable file-listing command-line program ls."
PACKAGE_SUMMARY="A modern replacement for ls"
PACKAGE_LICENSE="MIT"
### END EXAMPLE 1 ###

### EXAMPLE 2 — github ###
Download url:
https://github.com/junegunn/fzf/releases/download/v0.62.0/fzf-0.62.0-linux_amd64.tar.gz
File listing:
tar tvf fzf-0.62.0-linux_amd64.tar.gz
-rwxr-xr-x jg/staff    3883008 2025-05-04 11:59 fzf-0.62.0-linux_amd64/fzf
-rw-r--r-- jg/staff    3883008 2025-05-04 11:59 fzf-0.62.0-linux_amd64/extra/fzf.extra
Formula type: github
Type context: REPO: junegunn/fzf
Repo description: A command-line fuzzy finder
Output:
REPO="junegunn/fzf"
DPKG_BASENAME="fzf"
HOMEPAGE="https://github.com/junegunn/fzf"
DOWNLOAD_FILENAME="fzf-\$DPKG_VERSION-linux_\$DPKG_ARCH.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "fzf-\$DPKG_VERSION-linux_amd64/fzf|755|/usr/bin/fzf"
    "fzf-\$DPKG_VERSION-linux_amd64/extra/fzf.extra|644|/usr/share/fzf/extra/fzf.extra"
    )
CLEANUP_FILES="fzf extra/fzf.extra extra"
PACKAGE_DESCRIPTION="fzf is a general-purpose command-line fuzzy finder."
PACKAGE_SUMMARY="A command-line fuzzy finder"
PACKAGE_LICENSE="MIT"
### END EXAMPLE 2 ###

### EXAMPLE 3 — url_html ###
Download url:
https://dev.yorhel.nl/download/ncdu-2.9.1-linux-x86_64.tar.gz
File listing:
tar tvf ncdu-2.9.1-linux-x86_64.tar.gz
-rwxr-xr-x 0/0    1900000 2025-01-10 ncdu
Formula type: url_html
Type context: VERSION_URL: https://dev.yorhel.nl/ncdu
Output:
# -*- mode: sh -*-
FORMULA_TYPE="url_html"
DPKG_BASENAME="ncdu"
HOMEPAGE="https://dev.yorhel.nl/ncdu"
VERSION_URL="https://dev.yorhel.nl/ncdu"
VERSION_REGEX='ncdu-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)'
DOWNLOAD_FILENAME="ncdu-\$LATEST_VER-linux-x86_64.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://dev.yorhel.nl/download/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "ncdu|755|/usr/bin/ncdu"
)
CLEANUP_FILES="ncdu"
PACKAGE_DESCRIPTION="Ncdu is a disk usage analyzer with an ncurses-based text interface."
PACKAGE_SUMMARY="Disk usage analyzer with ncurses text interface"
PACKAGE_LICENSE="MIT"
### END EXAMPLE 3 ###

### EXAMPLE 4 — hashicorp ###
Download url:
https://releases.hashicorp.com/terraform/1.15.4/terraform_1.15.4_linux_amd64.zip
File listing:
Archive: terraform_1.15.4_linux_amd64.zip
  Length    Name
---------  ----
     4950  LICENSE.txt
117080248  terraform
Formula type: hashicorp
Type context: HASHICORP_PRODUCT: terraform
Output:
# -*- mode: sh -*-
FORMULA_TYPE="hashicorp"
HASHICORP_PRODUCT="terraform"
DPKG_BASENAME="terraform"
HOMEPAGE="https://www.terraform.io"
DOWNLOAD_FILENAME="\${HASHICORP_PRODUCT}_\${LATEST_VER}_linux_amd64.zip"
DOWNLOAD_URL_TEMPLATE="https://releases.hashicorp.com/\${HASHICORP_PRODUCT}/\${LATEST_VER}/\${HASHICORP_PRODUCT}_\${LATEST_VER}_linux_amd64.zip"
EXTRACT_CMD="unzip"
INSTALL_FILES=(
    "terraform|755|/usr/bin/terraform"
    "LICENSE.txt|644|/usr/share/terraform/LICENSE.txt"
)
CLEANUP_FILES="terraform LICENSE.txt"
PACKAGE_DESCRIPTION="Terraform is an infrastructure as code tool by HashiCorp."
PACKAGE_SUMMARY="Infrastructure as Code tool by HashiCorp"
PACKAGE_LICENSE="BSL-1.1"
### END EXAMPLE 4 ###

---
Now generate the template for this package:

Download URL:
$DOWNLOAD_LINK

File listing:
$FILELIST

Formula type: $FORMULA_TYPE
Type context: $TYPE_CONTEXT
