# PackageOne

Automated builder for `.deb` and `.rpm` packages from upstream binary releases. No compilation — it downloads pre-built binaries, packages them, and optionally pushes them to a package repository.

Each tool is described by a **formula file** (`formulas/*.formula`). Three source types are supported: GitHub releases, arbitrary URLs (with HTML version scraping), and HashiCorp's official release system.

---

## Requirements

- `wget`, `curl`, `jq`
- `fakeroot`, `dpkg-deb` (DEB builds)
- `rpmbuild` (RPM builds)
- `unzip` (for `.zip` archives)
- `bash` ≥ 4.0

---

## Setup

Copy and fill in `.env`:

```bash
GITHUB_TOKEN=ghp_...           # Recommended — increases GitHub API rate limit
OPENROUTER_API_KEY=sk-or-...   # Required only for the formula creator
PKG1UPLOADER=local             # Upload backend: 'local' or 'buildkite'
PACKAGER_NAME=Your Name
PACKAGER_EMAIL=you@example.com
VERBOSE=0
```

---

## Usage

```bash
# Build all formulas
bash runner.sh

# Build a specific formula
bash runner.sh -b formulas/bat-pkg.formula

# Force rebuild (ignore cached version)
bash runner.sh -f

# Check current vs latest versions without building
bash runner.sh -V

# Build only DEB packages (skip RPM)
bash runner.sh -D

# Build only RPM packages (skip DEB)
bash runner.sh -R

# Upload previously built packages
bash runner.sh -u

# Enable verbose output
bash runner.sh -v
```

Flags can be combined: `bash runner.sh -f -D -v`

Built packages are written to `dist/deb/` and `dist/rpm/x86_64/`.

---

## Formula types

### GitHub releases (default)

Fetches the latest release tag from the GitHub API and downloads the matching asset.

```bash
REPO="sharkdp/bat"
DPKG_BASENAME="bat"
DOWNLOAD_FILENAME="bat-\$LATEST_VER-x86_64-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "bat-\$LATEST_VER-x86_64-unknown-linux-gnu/bat|755|/usr/bin/bat"
)
CLEANUP_FILES="bat-\$LATEST_VER-x86_64-unknown-linux-gnu"
PACKAGE_DESCRIPTION="bat is a cat(1) clone with syntax highlighting and Git integration."
PACKAGE_SUMMARY="cat clone with syntax highlighting"
PACKAGE_LICENSE="MIT"
```

### URL / HTML scraping

For tools distributed outside GitHub. The version is extracted from a web page using a PCRE regex.

```bash
FORMULA_TYPE="url_html"
DPKG_BASENAME="ncdu"
VERSION_URL="https://dev.yorhel.nl/ncdu"
VERSION_REGEX='ncdu-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)'
DOWNLOAD_FILENAME="ncdu-\$LATEST_VER-linux-x86_64.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://dev.yorhel.nl/download/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "ncdu|755|/usr/bin/ncdu"
)
CLEANUP_FILES="ncdu"
PACKAGE_DESCRIPTION="Disk usage analyzer with an ncurses text interface."
PACKAGE_SUMMARY="Disk usage analyzer with ncurses text interface"
PACKAGE_LICENSE="MIT"
```

### HashiCorp

Uses `releases.hashicorp.com` and their JSON API for version detection.

```bash
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
PACKAGE_DESCRIPTION="Infrastructure as Code tool by HashiCorp."
PACKAGE_SUMMARY="Infrastructure as Code tool by HashiCorp"
PACKAGE_LICENSE="BSL-1.1"
```

---

## Creating formulas

### Automated (interactive, requires `OPENROUTER_API_KEY`)

The creator script fetches release data, selects the best Linux binary, and generates a formula using an LLM. The result is shown for review before saving.

```bash
bash runner.sh -F sharkdp/bat                    # GitHub repo
bash runner.sh -F hashicorp:vault                # HashiCorp product
bash runner.sh -F https://dev.yorhel.nl/ncdu     # URL with HTML scraping
```

For `url_html` formulas the script also automatically derives and validates the `VERSION_REGEX` from the download link before passing it to the AI.

### Manual

1. Create `formulas/<toolname>-pkg.formula` with the appropriate fields.
2. Test it: `bash runner.sh -b formulas/<toolname>-pkg.formula -f`
3. Check `dist/deb/` and `dist/rpm/x86_64/` for the output packages.

See [AGENTS.md](AGENTS.md) for the full field reference, variable substitution rules, and step-by-step instructions per formula type.

---

## Version tracking

`versions.db` stores the last successfully built version per formula (one `key=version` per line). On each run, the stored version is compared to the upstream latest — formulas that are already up to date are skipped. Use `-f` to force a rebuild regardless.

---

## Currently packaged tools

| Tool | Type | Source |
|---|---|---|
| atuin | github | atuinsh/atuin |
| bat | github | sharkdp/bat |
| btop | github | aristocratos/btop |
| delta | github | dandavison/delta |
| dua-cli | github | Byron/dua-cli |
| duf | github | muesli/duf |
| dust | github | bootandy/dust |
| eza | github | eza-community/eza |
| fd | github | sharkdp/fd |
| fselect | github | jhspetersson/fselect |
| fx | github | antonmedv/fx |
| fzf | github | junegunn/fzf |
| gdu | github | dundee/gdu |
| gitleaks | github | gitleaks/gitleaks |
| helix | github | helix-editor/helix |
| hexyl | github | sharkdp/hexyl |
| lf | github | gokcehan/lf |
| ncdu | url_html | dev.yorhel.nl/ncdu |
| neovim | github | neovim/neovim |
| ripgrep | github | BurntSushi/ripgrep |
| starship | github | starship-rs/starship |
| tabiew | github | shshemi/tabiew |
| terraform | hashicorp | releases.hashicorp.com |
| uv | github | astral-sh/uv |
| zoxide | github | ajeetdsouza/zoxide |
