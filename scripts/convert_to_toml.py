#!/usr/bin/env python3
"""Convert shell-based formulas to TOML format"""

import re
import os
from pathlib import Path

def parse_shell_formula(content):
    """Parse shell-based formula and extract variables"""
    data = {}
    
    # Simple key-value extraction
    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
            
        # Handle simple assignments
        if '=' in line and not line.startswith('('):
            key, value = line.split('=', 1)
            key = key.strip()
            value = value.strip().strip('"')
            
            # Handle arrays
            if value.startswith('('):
                # Extract array content
                array_content = re.search(r'\((.*?)\)', content, re.DOTALL)
                if array_content and key in content[:array_content.end()]:
                    items = []
                    for item in re.findall(r'"([^"]+)"', array_content.group(1)):
                        items.append(item)
                    data[key] = items
            else:
                data[key] = value
    
    return data

def convert_to_toml(data):
    """Convert parsed data to TOML format"""
    lines = []
    
    # Package metadata section
    lines.append("[package]")
    if 'REPO' in data:
        lines.append(f'repo = "{data["REPO"]}"')
    if 'DPKG_BASENAME' in data:
        lines.append(f'basename = "{data["DPKG_BASENAME"]}"')
    if 'PACKAGE_DESCRIPTION' in data:
        desc = data["PACKAGE_DESCRIPTION"].replace('"', '\\"')
        lines.append(f'description = "{desc}"')
    if 'PACKAGE_SUMMARY' in data:
        lines.append(f'summary = "{data["PACKAGE_SUMMARY"]}"')
    if 'PACKAGE_LICENSE' in data:
        lines.append(f'license = "{data["PACKAGE_LICENSE"]}"')
    
    lines.append("")
    
    # Download section
    lines.append("[download]")
    if 'DOWNLOAD_FILENAME' in data:
        # Replace $LATEST_VER with {version}
        filename = data["DOWNLOAD_FILENAME"].replace("$LATEST_VER", "{version}")
        lines.append(f'filename = "{filename}"')
    if 'DOWNLOAD_URL_TEMPLATE' in data:
        url = data["DOWNLOAD_URL_TEMPLATE"].replace("$REPO", "{repo}").replace("$LATEST_VER", "{version}").replace("$DOWNLOAD_FILENAME", "{filename}")
        lines.append(f'url_template = "{url}"')
    if 'EXTRACT_CMD' in data:
        lines.append(f'extract_cmd = "{data["EXTRACT_CMD"]}"')
    
    lines.append("")
    
    # Install files
    if 'INSTALL_FILES' in data:
        for item in data['INSTALL_FILES']:
            parts = item.split('|')
            if len(parts) == 3:
                source = parts[0].replace("$LATEST_VER", "{version}")
                perms = parts[1]
                dest = parts[2]
                
                lines.append("[[install_files]]")
                lines.append(f'source = "{source}"')
                lines.append(f'permissions = "{perms}"')
                lines.append(f'dest = "{dest}"')
                lines.append("")
    
    # Cleanup
    if 'CLEANUP_FILES' in data:
        cleanup = data["CLEANUP_FILES"].replace("$LATEST_VER", "{version}")
        lines.append("[cleanup]")
        lines.append(f'files = "{cleanup}"')
    
    return '\n'.join(lines)

def main():
    formulas_dir = Path("formulas")
    
    for formula_file in formulas_dir.glob("*.formula"):
        print(f"Converting {formula_file.name}...")
        
        content = formula_file.read_text()
        data = parse_shell_formula(content)
        toml_content = convert_to_toml(data)
        
        # Write to new .toml file
        toml_file = formula_file.with_suffix('.toml')
        toml_file.write_text(toml_content)
        print(f"  -> {toml_file.name}")

if __name__ == "__main__":
    main()
