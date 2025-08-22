Packagerone
===========



Dependencies
============

sudo apt install -y curl wget jq fakeroot dpkg-dev rpm build-essential tar gzip coreutils bash
grep sed awk findutils
# Package Builder Tool

A tool for automatically building DEB and RPM packages from GitHub releases of popular command-line tools.

## Overview

This tool automates the process of:
- Downloading the latest releases from GitHub repositories
- Extracting and packaging them into DEB and RPM formats
- Tracking version changes
- Uploading packages to package registries (Buildkite)

## Features

- **Automated Package Building**: Creates both DEB and RPM packages from GitHub releases
- **Version Tracking**: Keeps track of processed versions to avoid rebuilding unchanged packages
- **AI-Powered Formula Creation**: Automatically generates package formulas using AI
- **Multiple Package Support**: Supports various archive formats (tar.gz, AppImage, single binaries)
- **Upload Integration**: Built-in support for uploading to Buildkite package registries

## Requirements

### System Dependencies
- `bash` (4.0+)
- `wget` or `curl`
- `tar`
- `gzip`
- `dpkg-deb` (for DEB packages)
- `rpmbuild` (for RPM packages)
- `fakeroot`
- `jq` (for JSON processing)

### Optional Dependencies
- **GitHub Token**: Set `GITHUB_TOKEN` environment variable to avoid API rate limits
- **OpenRouter API Key**: Set `OPENROUTER_API_KEY` for AI-powered formula creation
- **Buildkite Credentials**: Set `BK_TOKEN`, `BK_ORG`, `BK_REGISTRY_DEB`, and `BK_REGISTRY_RPM` for package uploads

## Installation

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. Make the runner script executable:
   ```bash
   chmod +x runner.sh
   ```

3. Create a `.env` file with your configuration (optional):
   ```bash
   GITHUB_TOKEN=your_github_token_here
   OPENROUTER_API_KEY=your_openrouter_key_here
   BK_TOKEN=your_buildkite_token_here
   BK_ORG=your_buildkite_org
   BK_REGISTRY_DEB=your_deb_registry
   BK_REGISTRY_RPM=your_rpm_registry
   ```

## Usage

### Basic Usage

Build all packages:
```bash
./runner.sh
```

### Command Line Options

- `-b <formula>` - Build a specific package formula
- `-D` - Skip DEB package creation
- `-f` - Force build without checking versions
- `-F <repository/name>` - Automatically create formulas using AI
- `-R` - Skip RPM package creation
- `-u` - Upload created packages
- `-v` - Enable verbose mode
- `-V` - Run version check and exit

### Examples

Check versions of all packages:
```bash
./runner.sh -V
```

Build only DEB packages:
```bash
./runner.sh -R
```

Build a specific package:
```bash
./runner.sh -b formulas/bat-pkg.formula
```

Create a new formula using AI:
```bash
./runner.sh -F sharkdp/bat
```

Force rebuild all packages:
```bash
./runner.sh -f
```

Upload packages to registry:
```bash
./runner.sh -u
```

## Package Formulas

Package formulas are configuration files that define how to build packages. They are stored in the `formulas/` directory.

### Formula Structure

```bash
REPO="owner/repository"
DPKG_BASENAME="package-name"
DOWNLOAD_FILENAME="package-\$LATEST_VER-x86_64-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "binary|755|/usr/bin/binary"
    "README.md|644|/usr/share/package-name/README.md"
)
CLEANUP_FILES="binary README.md"
PACKAGE_DESCRIPTION="Description of the package"
PACKAGE_SUMMARY="Short summary"
PACKAGE_LICENSE="MIT"
```

### Available Variables

- `$LATEST_VER` - Latest version from GitHub (e.g., v1.2.3)
- `$DPKG_VERSION` - Version without 'v' prefix (e.g., 1.2.3)
- `$TARGET_ARCH` - Target architecture (x86_64)
- `$DPKG_ARCH` - Debian architecture (amd64)
- `$REPO` - GitHub repository
- `$DPKG_BASENAME` - Package name

## Supported Packages

The tool currently supports building packages for:

- atuin - Command history tool
- bat - Cat clone with syntax highlighting
- delta - Git diff viewer
- duf - Disk usage tool
- dust - Directory size analyzer
- eza - Modern ls replacement
- fd - Find alternative
- fx - JSON viewer
- fzf - Fuzzy finder
- gitleaks - Secret detection
- helix - Text editor
- hexyl - Hex viewer
- neovim - Text editor
- ripgrep - Grep alternative
- starship - Shell prompt
- tabiew - Table viewer
- uv - Python package manager
- zoxide - Smart cd command

## Output

Built packages are stored in:
- `dist/deb/` - DEB packages
- `dist/rpm/` - RPM packages

Logs are stored in:
- `logs/` - Build logs

## AI Formula Creation

The tool can automatically create package formulas using AI:

1. Analyzes GitHub releases
2. Downloads and inspects package contents
3. Generates appropriate formula configuration
4. Prompts for user review before saving

This feature requires an OpenRouter API key.

## Troubleshooting

### Common Issues

1. **GitHub API Rate Limits**: Set `GITHUB_TOKEN` environment variable
2. **Missing Dependencies**: Install required system packages
3. **Permission Errors**: Ensure `fakeroot` is installed and working
4. **Build Failures**: Check logs in `logs/` directory

### Debug Mode

Enable verbose output:
```bash
./runner.sh -v
```

## Contributing

1. Fork the repository
2. Create a new formula in `formulas/`
3. Test the build process
4. Submit a pull request

## License

[Add your license information here]
