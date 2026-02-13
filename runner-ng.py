#!/usr/bin/env python3
"""PackageOne - Main entry point for package building."""

import sys
import argparse
import tempfile
from pathlib import Path

#sys.path.insert(0, str(Path(__file__).parent))
from pone import config
from pone.formula import Formula


print("Config DB_FILE:", config.DB_FILE)

print(config.RUNTIME)
config.RUNTIME["arch"] = "x86_64"
f = Formula(config.FORMULAS_DIR / "atuin-pkg.toml")
#f.set_os("linux")
print(f.get("os"))
print(f.config)
print(config.RUNTIME)

#breakpoint()