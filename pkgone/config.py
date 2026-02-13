"""Configuration and environment settings."""

import os
from pathlib import Path
from datetime import datetime

# Base paths
SCRIPT_DIR = Path(__file__).resolve().parent.parent
OUTPUT_FOLDER = SCRIPT_DIR / "dist"
BUILD_FOLDER = SCRIPT_DIR / "build"
LOGFOLDER = SCRIPT_DIR / "logs"
DB_FILE = SCRIPT_DIR / "versions.db"
PKG1UPLOADTRK = SCRIPT_DIR / ".upload_tracker"

# Package settings
MAINTAINER = "Deese <deese2k@gmail.com>"
DPKG_ARCH = "amd64"
TARGET_ARCH = "x86_64"

# Runtime settings
VERBOSE = False
FORCE = False
SKIP_RPM_PACKAGE = False
SKIP_DEB_PACKAGE = False

# Create required directories
OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)
LOGFOLDER.mkdir(parents=True, exist_ok=True)
(OUTPUT_FOLDER / "deb").mkdir(exist_ok=True)
(OUTPUT_FOLDER / "rpm").mkdir(exist_ok=True)

# Logging
RUNLOG = LOGFOLDER / f"{datetime.now().strftime('%Y%m%d%H%M%S')}-pkgone.log"
