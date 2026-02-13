"""RPM package builder."""

import subprocess
from pathlib import Path
from typing import Dict
from datetime import datetime

from . import config
from .utils import logme, var_substitution


def build_rpm(build_ctx: Dict) -> bool:
    """Build RPM package.
    
    Args:
        build_ctx: Build context containing package information
        
    Returns:
        True if successful, False otherwise
    """
    build_folder = Path(build_ctx['build_folder'])
    
    # Create rpmbuild directory structure
    rpmbuild_dir = build_folder / "rpmbuild"
    for subdir in ['BUILD', 'RPMS', 'SOURCES', 'SPECS']:
        (rpmbuild_dir / subdir).mkdir(parents=True, exist_ok=True)
    
    # Extract context
    repo = build_ctx['repo']
    dpkg_basename = build_ctx['dpkg_basename']
    latest_ver = build_ctx['latest_ver']
    install_files = build_ctx['install_files']
    package_description = build_ctx.get('package_description', 'No description')
    package_summary = build_ctx.get('package_summary', package_description.split('\n')[0])
    package_license = build_ctx.get('package_license', 'Unknown')
    
    logme(f"[RPM] Building {dpkg_basename} rpm")
    
    # Setup variables for template
    dpkg_version = latest_ver.lstrip('rv')
    package_vars = {
        'PACKAGER_NAME': config.MAINTAINER.split('<')[0].strip(),
        'PACKAGER_EMAIL': config.MAINTAINER.split('<')[1].rstrip('>').strip() if '<' in config.MAINTAINER else '',
        'PACKAGE_NAME': dpkg_basename,
        'PACKAGE_VERSION': dpkg_version,
        'PACKAGE_ARCH': config.TARGET_ARCH,
        'PACKAGE_DATE': datetime.now().strftime("%a %b %d %Y"),
        'PACKAGE_URL': f"https://github.com/{repo}",
        'PACKAGE_DESCRIPTION': package_description,
        'PACKAGE_SUMMARY': package_summary,
        'PACKAGE_LICENSE': package_license,
    }
    
    # Process install files
    variables = build_ctx.copy()
    variables['LATEST_VER'] = latest_ver
    
    sources = []
    files = []
    install_cmds = []
    
    for idx, entry in enumerate(install_files):
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
            # Copy to SOURCES
            dest_source = rpmbuild_dir / "SOURCES" / source_path.name
            subprocess.run(['cp', str(source_path), str(dest_source)], check=True)
            
            sources.append(f"Source{idx}: {source_path.name}")
            files.append(f"%attr({perms}, root, root) {destination}")
            install_cmds.append(f"install -Dm{perms} %{{SOURCE{idx}}} %{{buildroot}}{destination}")
        else:
            logme(f"[RPM] File doesn't exist: {source_path}")
    
    package_vars['PACKAGE_SOURCES'] = '\n'.join(sources)
    package_vars['PACKAGE_FILES'] = '\n'.join(files)
    package_vars['INSTALL_CMDS'] = '\n'.join(install_cmds)
    
    # Load and process template
    template_path = config.SCRIPT_DIR / "scripts" / "rpm_template.spec"
    
    if template_path.exists():
        with open(template_path, 'r') as f:
            template_content = f.read()
    else:
        # Create default template
        template_content = create_default_spec_template()
    
    spec_content = var_substitution(template_content, package_vars)
    
    # Write spec file
    spec_path = rpmbuild_dir / "SPECS" / f"{dpkg_basename}.spec"
    with open(spec_path, 'w') as f:
        f.write(spec_content)
    
    # Remove old RPM files
    rpm_output = config.OUTPUT_FOLDER / "rpm" / config.TARGET_ARCH
    rpm_output.mkdir(parents=True, exist_ok=True)
    
    old_pattern = f"{dpkg_basename}-*.{config.TARGET_ARCH}.rpm"
    for old_file in rpm_output.glob(old_pattern):
        logme(f"[RPM] Removing old file: {old_file}", verbose_only=True)
        old_file.unlink()
    
    # Build RPM
    result = subprocess.run(
        [
            'rpmbuild', '-bb', str(spec_path),
            '--define', f'_topdir {rpmbuild_dir}',
            '--define', f'_rpmdir {config.OUTPUT_FOLDER / "rpm"}'
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT
    )
    
    if config.RUNLOG:
        with open(config.RUNLOG, 'ab') as f:
            f.write(result.stdout)
    
    if result.returncode == 0:
        # Find the built RPM
        rpm_files = list(rpm_output.glob(f"{dpkg_basename}*"))
        if rpm_files:
            logme(f"[RPM] Successfully built rpm package: {rpm_files[0]}")
        return True
    else:
        logme(f"[RPM] Failed to build package")
        return False


def create_default_spec_template() -> str:
    """Create default RPM spec template."""
    return """Name: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Release: 1%{?dist}
Summary: $PACKAGE_SUMMARY
License: $PACKAGE_LICENSE
URL: $PACKAGE_URL
$PACKAGE_SOURCES

%description
$PACKAGE_DESCRIPTION

%prep

%build

%install
$INSTALL_CMDS

%files
$PACKAGE_FILES

%changelog
* $PACKAGE_DATE $PACKAGER_NAME <$PACKAGER_EMAIL> - $PACKAGE_VERSION-1
- Automatic build from GitHub release
"""
