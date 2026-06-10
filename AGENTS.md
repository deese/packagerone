# PackageOne — Agent Reference

This file is written for AI agents (Claude Code, etc.) working on this repository.
It covers the architecture, formula system, and everything needed to create or modify formulas correctly without running the interactive creator script.

---

## What this project does

PackageOne downloads pre-built Linux binaries from upstream sources, packages them as `.deb` and `.rpm`, and optionally pushes them to a package repository. Each tool is described by a **formula file** in `formulas/`.

The only output is standard Linux packages. No compilation happens here.

---

## Repository layout

```
runner.sh                   # Main entry point
scripts/
  functions.sh              # Shared utilities: logging, version DB, var substitution
  environ.sh                # Default env vars (paths, arch, maintainer)
  pkg-common.sh             # build_package() — orchestrates one formula end-to-end
  nfpm-builder.sh           # build_nfpm() — builds .deb and .rpm via nfpm (default)
  deb-builder.sh            # build_deb() — legacy DEB builder (used when USE_NFPM=0)
  rpm-builder.sh            # build_rpm() — legacy RPM builder (used when USE_NFPM=0)
  deb-updater.sh            # APT repo update
  uploader_local.sh         # Local upload backend
  creator/
    formula_creator.sh      # Interactive AI-assisted formula generator
    system_prompt.md        # System prompt for the AI
    user_prompt.md          # User prompt template (uses var substitution)
formulas/
  *.formula                 # Active formulas (processed by runner.sh)
  *.sformula                # Inactive/draft formulas (ignored by runner.sh)
versions.db                 # key=version pairs tracking last-built versions
dist/
  deb/                      # Built .deb files (accumulates across runs)
  rpm/x86_64/               # Built .rpm files (accumulates across runs)
.env                        # Runtime secrets and overrides (not committed)
```

---

## Formula types

Three types are supported. The type is set via `FORMULA_TYPE` (defaults to `github` if not present).

### 1. `github` (default)

Fetches the latest release from the GitHub API and downloads a release asset.

**Version source:** `GET https://api.github.com/repos/{REPO}/releases/latest` → `.tag_name`
**Version DB key:** value of `$REPO`

```bash
# -*- mode: sh -*-
REPO="owner/repo"
DPKG_BASENAME="toolname"
DOWNLOAD_FILENAME="toolname-\$LATEST_VER-x86_64-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://github.com/\$REPO/releases/download/\$LATEST_VER/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "toolname-\$LATEST_VER-x86_64-unknown-linux-gnu/toolname|755|/usr/bin/toolname"
    "toolname-\$LATEST_VER-x86_64-unknown-linux-gnu/README.md|644|/usr/share/toolname/README.md"
)
CLEANUP_FILES="toolname-\$LATEST_VER-x86_64-unknown-linux-gnu"
PACKAGE_DESCRIPTION="Long description of the tool."
PACKAGE_SUMMARY="One-line summary"
PACKAGE_LICENSE="MIT"
```

### 2. `url_html`

Downloads from any URL. Version is scraped from a web page using a PCRE regex.

**Version source:** `curl` the page at `VERSION_URL`, then `grep -oP "$VERSION_REGEX"`
**Version DB key:** value of `$DPKG_BASENAME`

```bash
# -*- mode: sh -*-
FORMULA_TYPE="url_html"
DPKG_BASENAME="toolname"
VERSION_URL="https://example.com/downloads"
VERSION_REGEX='toolname-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)'
DOWNLOAD_FILENAME="toolname-\$LATEST_VER-linux-x86_64.tar.gz"
DOWNLOAD_URL_TEMPLATE="https://example.com/downloads/\$DOWNLOAD_FILENAME"
EXTRACT_CMD="tar zxf"
INSTALL_FILES=(
    "toolname|755|/usr/bin/toolname"
)
CLEANUP_FILES="toolname"
PACKAGE_DESCRIPTION="Long description."
PACKAGE_SUMMARY="One-line summary"
PACKAGE_LICENSE="MIT"
```

**Writing `VERSION_REGEX`:**
The regex is passed directly to `grep -oP` and must return only the version string.
Use `\K` to discard the prefix from the match and a lookahead `(?=...)` to anchor the suffix:

```
toolname-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^
          this is what gets returned
```

To derive it from a known download URL:
1. Take the filename: `toolname-2.1.0-linux-x86_64.tar.gz`
2. Identify prefix: `toolname-` and suffix: `-linux-x86_64.tar.gz`
3. Escape dots in suffix: `-linux-x86_64\.tar\.gz`
4. Choose version pattern depth: 3-part → `[0-9]+\.[0-9]+\.[0-9]+`
5. Result: `toolname-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)`

Validate before saving:
```bash
curl -sL "https://example.com/downloads" \
  | grep -oP 'toolname-\K[0-9]+\.[0-9]+\.[0-9]+(?=-linux-x86_64\.tar\.gz)' \
  | head -1
```

### 3. `hashicorp`

Downloads from `releases.hashicorp.com` using their standard URL scheme.

**Version source:** `GET https://api.releases.hashicorp.com/v1/releases/{product}/latest` → `.version`
**Version DB key:** `hashicorp/{HASHICORP_PRODUCT}`

```bash
# -*- mode: sh -*-
FORMULA_TYPE="hashicorp"
HASHICORP_PRODUCT="vault"
DPKG_BASENAME="vault"
HOMEPAGE="https://www.vaultproject.io"
DOWNLOAD_FILENAME="\${HASHICORP_PRODUCT}_\${LATEST_VER}_linux_amd64.zip"
DOWNLOAD_URL_TEMPLATE="https://releases.hashicorp.com/\${HASHICORP_PRODUCT}/\${LATEST_VER}/\${HASHICORP_PRODUCT}_\${LATEST_VER}_linux_amd64.zip"
EXTRACT_CMD="unzip"
INSTALL_FILES=(
    "vault|755|/usr/bin/vault"
    "LICENSE.txt|644|/usr/share/vault/LICENSE.txt"
)
CLEANUP_FILES="vault LICENSE.txt"
PACKAGE_DESCRIPTION="Vault is a tool for secrets management and data protection by HashiCorp."
PACKAGE_SUMMARY="Secrets management tool by HashiCorp"
PACKAGE_LICENSE="BSL-1.1"
```

**Note:** Always use `\${HASHICORP_PRODUCT}` (not the literal product name) in `DOWNLOAD_FILENAME` and `DOWNLOAD_URL_TEMPLATE`. HashiCorp zips always contain the binary at the root alongside `LICENSE.txt`.

---

## Field reference

| Field | Required | Description |
|---|---|---|
| `FORMULA_TYPE` | No | `github` (default), `url_html`, or `hashicorp` |
| `REPO` | github only | `owner/repo` — also used as version DB key |
| `HASHICORP_PRODUCT` | hashicorp only | Product name: `terraform`, `vault`, `consul`, etc. |
| `VERSION_URL` | url_html only | Page URL to scrape for the version |
| `VERSION_REGEX` | url_html only | PCRE regex returning only the version string |
| `HOMEPAGE` | optional | Overrides the package homepage (defaults to `https://github.com/$REPO`) |
| `DPKG_BASENAME` | Yes | Package name: lowercase, no spaces |
| `DOWNLOAD_FILENAME` | Yes | Filename of the archive (supports variable substitution) |
| `DOWNLOAD_URL_TEMPLATE` | Yes | Full download URL (supports variable substitution) |
| `EXTRACT_CMD` | Yes* | `tar zxf`, `tar xf`, `tar jxf`, `unzip`, `gunzip`, `cp`, or `""` (no extraction) |
| `INSTALL_FILES` | Yes | Array of `"src\|perms\|dest"` entries |
| `CLEANUP_FILES` | Recommended | Space-separated files/dirs to remove after build (relative to build folder, supports variable substitution) |
| `PACKAGE_DESCRIPTION` | Yes | Full package description (multi-line ok) |
| `PACKAGE_SUMMARY` | Yes | Single-line summary |
| `PACKAGE_LICENSE` | Yes | SPDX identifier: `MIT`, `Apache-2.0`, `BSL-1.1`, etc. |

---

## Variable substitution

These variables are available inside `DOWNLOAD_FILENAME`, `DOWNLOAD_URL_TEMPLATE`, `INSTALL_FILES`, and `CLEANUP_FILES`. Use `\$VAR` (escaped) in the formula file so expansion happens at build time, not when the file is sourced.

| Variable | Value | Example |
|---|---|---|
| `$LATEST_VER` | Full version tag from upstream | `v2.9.1`, `2.9.1`, `r41` |
| `$DPKG_VERSION` | Version with any leading non-digit prefix stripped | `2.9.1`, `41` |
| `$TARGET_ARCH` | CPU arch for filenames | `x86_64` |
| `$DPKG_ARCH` | Debian arch string | `amd64` |
| `$REPO` | GitHub repo path | `sharkdp/bat` |
| `$DPKG_BASENAME` | Package name | `bat` |
| `$DOWNLOAD_FILENAME` | Resolved filename (after its own substitution) | `bat-2.9.1-x86_64-...tar.gz` |
| `$HASHICORP_PRODUCT` | HashiCorp product name | `terraform` |

**Version prefix rule:**
- If the upstream URL uses a bare version like `2.9.1` → use `$DPKG_VERSION`
- If it uses `v2.9.1` → use `$LATEST_VER`
- `$DPKG_VERSION` strips **any** leading non-digit characters (not just `v`): `r41` → `41`, `v1.0` → `1.0`

---

## `INSTALL_FILES` format

Each entry is a string: `"source_path|permissions|destination_path"`

```bash
INSTALL_FILES=(
    "bat-\$LATEST_VER-x86_64-unknown-linux-gnu/bat|755|/usr/bin/bat"
    "bat-\$LATEST_VER-x86_64-unknown-linux-gnu/bat.1|644|/usr/share/bat/bat.1"
)
```

- `source_path`: relative to the build folder (after extraction). Supports variable substitution.
- `permissions`: octal, e.g. `755` for executables, `644` for data files.
- `destination_path`: absolute path in the installed system.
  - Binaries → `/usr/bin/`
  - Everything else → `/usr/share/$DPKG_BASENAME/`

---

## `CLEANUP_FILES` format

Space-separated list of files and/or directories to delete after a successful build.
Paths are **relative to the build folder** (the temp dir where extraction happened), not the project root.
Variable substitution is applied to each entry before deletion.

```bash
# Delete the entire extracted directory
CLEANUP_FILES="toolname-\$LATEST_VER-x86_64-unknown-linux-gnu"

# Or list individual files
CLEANUP_FILES="toolname LICENSE.txt README.md"
```

Cleanup only runs on success — if the build fails, the build folder is left intact for debugging.

---

## `EXTRACT_CMD` notes

| Value | When to use |
|---|---|
| `tar zxf` | `.tar.gz` / `.tgz` |
| `tar jxf` | `.tar.bz2` / `.tbz` |
| `tar xf` | `.tar.xz` / `.txz` or auto-detect |
| `unzip` | `.zip` — extracts to `$BUILD_FOLDER` automatically |
| `gunzip` | `.gz` single compressed file (no tar) |
| `cp` | Already a plain binary, no extraction needed |
| `""` | Skip extraction (e.g. AppImage, just install as-is) |

---

## `dist/` package management

`dist/deb/` and `dist/rpm/x86_64/` accumulate packages across builds — they are never wiped between runs. When a new version of a package is built successfully, the previous version for that package is automatically removed from `dist/`. If a build fails, the old version is preserved.

This means the upload always has all packages (not just the latest batch), and the uploader can be run independently of a build.

---

## How `runner.sh` processes a formula

1. Unset all formula variables (prevents leakage between formulas)
2. `source formula_file` — loads all variables into the current shell
3. Detect `FORMULA_TYPE` (default: `github`)
4. Call the appropriate version-fetch function → sets `$LATEST_VER`
5. Compute `$DPKG_VERSION` by stripping any leading non-digit prefix from `$LATEST_VER`
6. Compare with `versions.db` — skip if already up to date (unless `-f`)
7. Run `var_substitution` on `DOWNLOAD_FILENAME` and `DOWNLOAD_URL_TEMPLATE`
8. `wget` the file into a temp build folder (`/tmp/pkgone-*/build/`)
9. Run `EXTRACT_CMD`
10. Call `build_nfpm` (or `build_deb` + `build_rpm` if `USE_NFPM=0`)
11. On success: remove old versions from `dist/`, update `versions.db`

---

## Creating a formula manually (step by step)

### For a GitHub tool

1. Find the GitHub repo and check the latest release assets:
   ```
   https://api.github.com/repos/OWNER/REPO/releases/latest
   ```
2. Identify the Linux x86_64 asset (prefer `gnu` over `musl`, prefer `.tar.gz` over `.zip`).
3. Download and list the archive contents:
   ```bash
   wget -q <url> -O /tmp/tool.tar.gz && tar tvf /tmp/tool.tar.gz
   ```
4. Note which files you need: binary, man page, completions, license.
5. Write the formula. Key decisions:
   - Does the URL use `v2.1.0` or `2.1.0`? → choose `\$LATEST_VER` or `\$DPKG_VERSION`
   - Does the archive extract to a subdirectory? → include the path in `INSTALL_FILES`
   - Only include files that actually exist in the archive
6. Save as `formulas/<toolname>-pkg.formula`
7. Test: `bash runner.sh -b <toolname> -f`

### For a url_html tool

1. Open the download page and find a direct download link for the latest Linux x86_64 binary.
2. Derive the `VERSION_REGEX` from the filename (see the regex section above).
3. Validate the regex:
   ```bash
   curl -sL <page_url> | grep -oP '<your_regex>' | head -1
   ```
4. Write the formula with `FORMULA_TYPE="url_html"`.
5. Test with `bash runner.sh -b <toolname> -f`.

### For a HashiCorp tool

1. Check the product exists:
   ```bash
   curl -s https://api.releases.hashicorp.com/v1/releases/<product>/latest | jq .version
   ```
2. Verify the zip contents:
   ```bash
   VERSION=$(curl -s https://api.releases.hashicorp.com/v1/releases/<product>/latest | jq -r .version)
   wget -q https://releases.hashicorp.com/<product>/$VERSION/<product>_${VERSION}_linux_amd64.zip -O /tmp/hc.zip
   unzip -l /tmp/hc.zip
   ```
3. Write the formula using the `hashicorp` template above, adjusting `INSTALL_FILES` based on the zip contents.
4. Set the correct `HOMEPAGE` for the product.
5. Test with `bash runner.sh -b <toolname> -f`.

---

## Common mistakes

| Mistake | Effect | Fix |
|---|---|---|
| Using `$LATEST_VER` when URL has no `v` prefix | Download 404 | Use `$DPKG_VERSION` instead |
| Not escaping `$` in formula (`$VAR` instead of `\$VAR`) | Variable expands at source time with empty value | Escape: `\$LATEST_VER` |
| Hardcoding a version number in `INSTALL_FILES` paths | Build fails when version changes | Use `\$LATEST_VER` or `\$DPKG_VERSION` |
| Including files in `INSTALL_FILES` that don't exist in the archive | Build fails with "file does not exist" | Check archive contents with `tar tvf` or `unzip -l` first |
| Using `dist` or another project-root name in `CLEANUP_FILES` | No longer an issue (cleanup now runs from build folder) | — |
| `FORMULA_TYPE` but no `DPKG_BASENAME` | Build fails with validation error | Always set `DPKG_BASENAME` |
| Literal product name in HashiCorp template | Wrong package if formula is reused | Use `\${HASHICORP_PRODUCT}` |
| `url_html` with regex that doesn't match | Build fails with "could not extract version" | Validate regex with `curl + grep -oP` before saving |

---

## Automated formula creation

The interactive script at `scripts/creator/formula_creator.sh` handles data gathering and calls the AI. It is invoked via `runner.sh -F <input>`:

```bash
bash runner.sh -F sharkdp/bat                        # GitHub
bash runner.sh -F hashicorp:vault                    # HashiCorp
bash runner.sh -F https://dev.yorhel.nl/ncdu         # URL/HTML
```

For url_html formulas, the script automatically derives and validates `VERSION_REGEX` from the selected download link before passing it to the AI.

The formula is shown for human review before saving. Always verify the output before committing.

---

## Keeping README.md in sync

After creating or modifying a formula, always check whether `README.md` needs updating.

**Rule:** every `.formula` file in `formulas/` must have a corresponding row in the "Currently packaged tools" table in `README.md`. If any are missing, add them.

### How to detect missing entries

```bash
# List all active formula basenames
for f in formulas/*.formula; do basename "$f" -pkg.formula 2>/dev/null || basename "$f" .formula; done | sort

# List all tool names already in the README table
grep '| [a-z]' README.md | awk -F'|' '{print $2}' | tr -d ' ' | sort
```

Compare the two lists. Any name in the first list but not the second needs a new row.

### Row format

```markdown
| toolname | github    | owner/repo              |
| toolname | url_html  | hostname/path           |
| toolname | hashicorp | releases.hashicorp.com  |
```

Rows are sorted alphabetically by tool name. Insert in the correct position.

---

## Environment / `.env`

```
GITHUB_TOKEN=...           # Increases GitHub API rate limit (recommended)
OPENROUTER_API_KEY=...     # Required for formula_creator.sh
PKG1UPLOADER=local         # Upload backend
PACKAGER_NAME=...
PACKAGER_EMAIL=...
VERBOSE=0
USE_NFPM=1                 # Use nfpm for building (recommended, default)
```
