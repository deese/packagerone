# Uploader failure analysis — `runner.sh -u`

## Symptom

Running `bash runner.sh -u` manually fails with:

```
cp: cannot stat '/home/deese/devel/packagerone/dist/deb/*.deb': No such file or directory
cp: cannot stat '/home/deese/devel/packagerone/dist/rpm/x86_64/*.rpm': No such file or directory
```

Works fine when launched automatically at the end of a full build run.

## Root cause

### 1. `dist/deb/` and `dist/rpm/x86_64/` are not pre-created

`scripts/environ.sh` only creates `$OUTPUT_FOLDER` (`dist/`) and `logs/`. The subdirectories `dist/deb/` and `dist/rpm/` are created by `deb-builder.sh` / `nfpm-builder.sh` / `rpm-builder.sh` at build time. If no build has run, these directories don't exist.

### 2. `mk-apt-repo.sh` and `mk-yum-repo.sh` fail hard on empty input

Both scripts in `spzrepo/repo/` use `set -euo pipefail` and copy with an unguarded glob:

```bash
# mk-apt-repo.sh:27
cp $INCOMING_DEB_FOLDER/*.deb "$APT_REPO_DIR/pool/main/"

# mk-yum-repo.sh:17
cp $INCOMING_RPM_FOLDER/*.rpm "$RPM_DIR/"
```

When the glob matches nothing (directory missing or empty), `cp` exits non-zero and `set -e` aborts the whole script.

### 3. Why automatic run works

Automatic upload is only triggered from `runner.sh` when `$CHANGES_FILE` is non-empty (i.e., at least one package was built successfully):

```bash
# runner.sh:116-118
if [ -s $CHANGES_FILE ]; then
    do_upload
fi
```

At that point, `dist/deb/*.deb` and `dist/rpm/x86_64/*.rpm` exist. Manual `-u` skips the build entirely, so the dist folders may be absent.

## Source of `INCOMING_DEB_FOLDER` / `INCOMING_RPM_FOLDER`

Defined in `spzrepo/.env`:

```
INCOMING_DEB_FOLDER=/home/deese/devel/packagerone/dist/deb
INCOMING_RPM_FOLDER=/home/deese/devel/packagerone/dist/rpm/x86_64
```

Loaded by `spzrepo/repo/functions.sh:read_env` inside both repo scripts.

## Proposed fix

In `spzrepo/repo/mk-apt-repo.sh`, before the `cp`:

```bash
if ! compgen -G "$INCOMING_DEB_FOLDER/*.deb" > /dev/null 2>&1; then
    echo "No .deb files in $INCOMING_DEB_FOLDER — nothing to upload"
    exit 0
fi
cp "$INCOMING_DEB_FOLDER"/*.deb "$APT_REPO_DIR/pool/main/"
```

In `spzrepo/repo/mk-yum-repo.sh`, before the `cp`:

```bash
if ! compgen -G "$INCOMING_RPM_FOLDER/*.rpm" > /dev/null 2>&1; then
    echo "No .rpm files in $INCOMING_RPM_FOLDER — nothing to upload"
    exit 0
fi
cp "$INCOMING_RPM_FOLDER"/*.rpm "$RPM_DIR/"
```

Both changes make the upload a no-op (exit 0) instead of a hard failure when there is nothing to upload.
