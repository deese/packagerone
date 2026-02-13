#!/usr/bin/env python3
"""PackageOne - Main entry point for package building."""

import sys
import argparse
import tempfile
from pathlib import Path

# Add parent directory to path to import pkgone
sys.path.insert(0, str(Path(__file__).parent))

from pkgone import config
from pkgone.utils import read_env, logme
from pkgone.builder import build_package
from pkgone.version_check import check_all_versions
from pkgone.formula_creator import create_formula_cli


def do_upload(changes_file: Path) -> None:
    """Run upload script if configured."""
    uploader = os.environ.get('PKG1UPLOADER')
    
    if not uploader:
        return
    
    logme(f"Uploader set to: {uploader}", verbose_only=True)
    
    uploader_script = config.SCRIPT_DIR / "scripts" / f"uploader_{uploader}.sh"
    
    if not uploader_script.exists():
        logme(f"uploader_{uploader}.sh doesn't exist")
        print(f"uploader_{uploader}.sh doesn't exist")
        return
    
    logme(f"Running uploader - {uploader}")
    subprocess.run(['bash', str(uploader_script), str(changes_file)], check=True)


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description='PackageOne - Automated package builder for GitHub releases',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument('-b', '--build', metavar='FORMULA',
                        help='Build specific formula')
    parser.add_argument('-D', '--skip-deb', action='store_true',
                        help='Skip DEB package creation')
    parser.add_argument('-f', '--force', action='store_true',
                        help='Force build without checking versions')
    parser.add_argument('-F', '--create-formula', metavar='REPO',
                        help='Automatically create formulas using AI (requires human review)')
    parser.add_argument('-R', '--skip-rpm', action='store_true',
                        help='Skip RPM package creation')
    parser.add_argument('-u', '--upload', action='store_true',
                        help='Upload created packages')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose mode')
    parser.add_argument('-V', '--version-check', action='store_true',
                        help='Run version check and exit')
    
    args = parser.parse_args()
    
    # Set configuration
    config.VERBOSE = args.verbose
    config.FORCE = args.force
    config.SKIP_DEB_PACKAGE = args.skip_deb
    config.SKIP_RPM_PACKAGE = args.skip_rpm
    
    # Load environment
    env_file = config.SCRIPT_DIR / ".env"
    if env_file.exists():
        read_env(env_file)
    
    # Create changes file
    changes_file = Path(tempfile.mktemp(suffix=".changes"))
    
    try:
        # Handle specific operations
        if args.version_check:
            check_all_versions()
            return 0
        
        if args.upload:
            do_upload(changes_file)
            return 0
        
        if args.create_formula:
            # Run formula creator
            return create_formula_cli(args.create_formula, force=args.force)
        
        if args.build:
            # Build specific formula
            formula_path = config.SCRIPT_DIR / "formulas" / args.build
            if not formula_path.exists():
                # Try with .formula extension
                formula_path = config.SCRIPT_DIR / "formulas" / f"{args.build}.formula"
            
            if not formula_path.exists():
                print(f"Error: Formula not found: {args.build}")
                return 1
            
            print(f"Building package {args.build}")
            build_package(formula_path, changes_file)
            return 0
        
        # Build all formulas
        formulas_dir = config.SCRIPT_DIR / "formulas"
        for formula_file in formulas_dir.glob("*.formula"):
            # Skip legacy formulas
            if formula_file.name in ['neovim-pkg.formula']:
                continue
            
            build_package(formula_file, changes_file)
        
        # Upload if changes detected
        if changes_file.exists() and changes_file.stat().st_size > 0:
            logme("Changes detected. Running upload script if available.")
            do_upload(changes_file)
        
        return 0
        
    finally:
        # Cleanup
        if changes_file.exists():
            changes_file.unlink()


if __name__ == '__main__':
    import os
    import subprocess
    sys.exit(main())
