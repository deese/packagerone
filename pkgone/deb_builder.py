"""DEB package builder."""

import os
import subprocess
import tempfile
from pathlib import Path
from typing import Dict

from . import config
from .utils import (
    logme, get_latest_ver, set_stored_version,
    var_substitution
)


def build_deb(build_ctx: Dict) -> bool:
    """Build DEB package.
    
    Args:
        build_ctx: Build context containing package information
        
    Returns:
        True if successful, False otherwise
    """
    deb_output = config.OUTPUT_FOLDER / "deb"
    deb_output.mkdir(exist_ok=True)
    
    # Extract context
    repo = build_ctx['repo']
    dpkg_basename = build_ctx['dpkg_basename']
    latest_ver = build_ctx['latest_ver']
    dpkg_arch = build_ctx['dpkg_arch']
    build_folder = Path(build_ctx['build_folder'])
    install_files = build_ctx['install_files']
    package_description = build_ctx.get('package_description', 'No description')
    
    # Setup package variables
    dpkg_version = latest_ver.lstrip('rv')
    
    # Validate version
    if not dpkg_version.replace('.', '').replace('-', '').isdigit():
        logme(f"[DEB] Fatal error: DPKG_VERSION contains invalid characters: {dpkg_version}")
        return False
    
    dpkg_dir = build_folder / f"{dpkg_basename}-{latest_ver}-{config.TARGET_ARCH}"
    dpkg_name = f"{dpkg_basename}_{dpkg_version}_{dpkg_arch}.deb"
    dpkg_path = deb_output / dpkg_name
    
    logme(f"[DEB] Building {dpkg_basename} deb package")
    
    # Check if package already exists
    if not config.FORCE and dpkg_path.exists():
        logme(f"[DEB] File already exists: {dpkg_path}")
        return True
    
    # Install files
    variables = build_ctx.copy()
    variables['LATEST_VER'] = latest_ver
    variables['DPKG_VERSION'] = dpkg_version
    
    for entry in install_files:
        parts = entry.split('|')
        if len(parts) != 3:
            continue
        
        source, perms, destination = parts
        source = var_substitution(source, variables)
        
        if not source.startswith('/'):
            source_path = build_folder / source
        else:
            source_path = Path(source)
        
        if source_path.exists():
            dest_path = dpkg_dir / destination.lstrip('/')
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Install file with permissions
            subprocess.run(
                ['install', f'-Dm{perms}', str(source_path), str(dest_path)],
                check=True
            )
            logme(f"[DEB] Installed {source_path} -> {dest_path}", verbose_only=True)
        else:
            logme(f"[DEB] File doesn't exist: {source_path}")
    
    # Create DEBIAN directory and control file
    debian_dir = dpkg_dir / "DEBIAN"
    debian_dir.mkdir(parents=True, exist_ok=True)
    
    # Format description (indent continuation lines)
    desc_lines = package_description.split('\n')
    formatted_desc = desc_lines[0]
    if len(desc_lines) > 1:
        formatted_desc += '\n' + '\n'.join(f' {line}' for line in desc_lines[1:])
    
    control_content = f"""Package: {dpkg_basename}
Version: {dpkg_version}
Section: utils
Priority: optional
Maintainer: {config.MAINTAINER}
Homepage: https://github.com/{repo}
Architecture: {dpkg_arch}
Description: {formatted_desc}
"""
    
    with open(debian_dir / "control", 'w') as f:
        f.write(control_content)
    
    # Clean old files
    old_pattern = f"{dpkg_basename}_*_{dpkg_arch}.deb"
    for old_file in deb_output.glob(old_pattern):
        logme(f"[DEB] Removing old file: {old_file}", verbose_only=True)
        old_file.unlink()
    
    # Build package
    logme("[DEB] Running the builder", verbose_only=True)
    result = subprocess.run(
        ['fakeroot', 'dpkg-deb', '--build', str(dpkg_dir), str(dpkg_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    )
    
    if config.RUNLOG:
        with open(config.RUNLOG, 'ab') as f:
            f.write(result.stdout)
    
    if result.returncode == 0:
        logme(f"[DEB] Successfully built {dpkg_path}")
        return True
    else:
        logme(f"[DEB] Failed to build package")
        return False
