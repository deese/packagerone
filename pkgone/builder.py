"""Common package building functions."""

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

from . import config
from .formula import Formula
from .utils import (
    logme, get_latest_ver, get_stored_version, set_stored_version,
    var_substitution, download_file, pad, max_strlen
)
from .deb_builder import build_deb
from .rpm_builder import build_rpm


def build_package(formula_path: Path, changes_file: Optional[Path] = None) -> bool:
    """Build package from formula.
    
    Args:
        formula_path: Path to formula file
        changes_file: Optional path to changes tracking file
        
    Returns:
        True if package was built, False otherwise
    """
    # Load formula
    formula = Formula(formula_path)
    
    # Get required values
    repo = formula.get('REPO')
    dpkg_basename = formula.get('DPKG_BASENAME')
    download_filename_template = formula.get('DOWNLOAD_FILENAME')
    download_url_template = formula.get('DOWNLOAD_URL_TEMPLATE')
    install_files = formula.get('INSTALL_FILES', [])
    extract_cmd = formula.get('EXTRACT_CMD', '')
    cleanup_files = formula.get('CLEANUP_FILES', '')
    package_description = formula.get('PACKAGE_DESCRIPTION', 'No description available')
    package_summary = formula.get('PACKAGE_SUMMARY', '')
    package_license = formula.get('PACKAGE_LICENSE', 'Unknown')
    
    # Validate required variables
    if not all([repo, dpkg_basename, download_filename_template, install_files]):
        logme("[PKGBUILD] Error: Missing required configuration variables")
        return False
    
    # Display package name (padded for alignment)
    formulas_dir = config.SCRIPT_DIR / "formulas"
    all_repos = []
    for f in formulas_dir.glob("*.formula"):
        try:
            temp_formula = Formula(f)
            if 'REPO' in temp_formula.config:
                all_repos.append(temp_formula.config['REPO'])
        except:
            pass
    
    pad_size = max_strlen(all_repos) if all_repos else 20
    pad_repo = pad(repo, -pad_size)
    logme(f"[PKGBUILD] Building {pad_repo}", no_eol=True)
    
    # Get latest version
    latest_ver = get_latest_ver(repo)
    if not latest_ver:
        logme(f"\n[PKGBUILD] Fatal error: Could not retrieve version for {repo}")
        return False
    
    # Check if already up to date
    current_version = get_stored_version(repo)
    if not config.FORCE and latest_ver == current_version:
        logme(f" - Up to date ({current_version})")
        return False
    else:
        logme(f" - Building version: {latest_ver}")
    
    # Create build folder
    build_folder = Path(tempfile.mkdtemp(prefix="pkgone-"))
    
    try:
        # Setup variables for substitution
        variables = {
            'REPO': repo,
            'LATEST_VER': latest_ver,
            'DPKG_BASENAME': dpkg_basename,
            'DPKG_ARCH': config.DPKG_ARCH,
            'TARGET_ARCH': config.TARGET_ARCH,
            'DPKG_VERSION': latest_ver.lstrip('rv'),
        }
        
        # Download file
        download_filename = var_substitution(download_filename_template, variables)
        download_url = var_substitution(download_url_template, variables)
        
        variables['DOWNLOAD_FILENAME'] = download_filename
        
        logme(f"[PKGBUILD] Using build folder: {build_folder}", verbose_only=True)
        logme(f"[PKGBUILD] Downloading file: {download_url}", verbose_only=True)
        
        download_path = build_folder / download_filename
        if not download_file(download_url, download_path):
            logme(f"[PKGBUILD] Error downloading file: {download_url}")
            return False
        
        logme(f"[PKGBUILD] File downloaded to {download_path}", verbose_only=True)
        
        # Extract if needed
        if extract_cmd:
            logme("[PKGBUILD] Extracting file")
            
            if 'tar' in extract_cmd:
                cmd = extract_cmd.split() + [str(download_path), '-C', str(build_folder)]
                subprocess.run(cmd, check=True)
            elif extract_cmd == 'gunzip':
                subprocess.run(['gunzip', str(download_path)], check=True)
            elif extract_cmd != 'cp':
                cmd = extract_cmd.split() + [str(download_path)]
                subprocess.run(cmd, cwd=build_folder, check=True)
        
        logme("[PKGBUILD] File extracted. Running builders")
        
        # Build context
        build_ctx = {
            'repo': repo,
            'dpkg_basename': dpkg_basename,
            'latest_ver': latest_ver,
            'dpkg_arch': config.DPKG_ARCH,
            'target_arch': config.TARGET_ARCH,
            'build_folder': str(build_folder),
            'install_files': install_files,
            'package_description': package_description,
            'package_summary': package_summary,
            'package_license': package_license,
        }
        build_ctx.update(variables)
        
        # Build packages
        success = True
        
        if not config.SKIP_DEB_PACKAGE:
            if not build_deb(build_ctx):
                success = False
        
        if not config.SKIP_RPM_PACKAGE:
            if not build_rpm(build_ctx):
                success = False
        
        # Cleanup
        if cleanup_files:
            logme("[PKGBUILD] Cleaning up files.", verbose_only=True)
            cleanup_list = var_substitution(cleanup_files, variables).split()
            for cleanup_item in cleanup_list:
                cleanup_path = build_folder / cleanup_item
                if cleanup_path.exists():
                    if cleanup_path.is_dir():
                        shutil.rmtree(cleanup_path)
                    else:
                        cleanup_path.unlink()
        
        # Update version tracking
        if success:
            set_stored_version(repo, latest_ver)
            logme(f"[SUCCESS] Built {dpkg_basename}")
            
            # Mark changes
            if changes_file:
                with open(changes_file, 'w') as f:
                    f.write('1\n')
            
            return True
        
        return False
        
    finally:
        # Cleanup build folder
        if build_folder.exists():
            logme(f"[PKGBUILD] Removing build folder: {build_folder}", verbose_only=True)
            shutil.rmtree(build_folder, ignore_errors=True)
