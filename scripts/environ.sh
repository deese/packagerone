SCRIPT_DIR=$(dirname "$(realpath "$0")")
MAINTAINER="Deese <deese2k@gmail.com>"
DPKG_ARCH="amd64"
TARGET_ARCH="x86_64"
WGET="wget -q"
OUTPUT_FOLDER="$SCRIPT_DIR/dist"
PKG1UPLOADTRK="$SCRIPT_DIR/.upload_tracker"
DB_FILE="$SCRIPT_DIR/versions.db"
LOGFOLDER="$SCRIPT_DIR/logs"
RUNLOG="$LOGFOLDER/$(date +"%Y%m%d%H%M%S-pkgone.log")"
VERBOSE=0

mkdir -p $OUTPUT_FOLDER $LOGFOLDER

