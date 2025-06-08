Packagerone
===========

Small set of scripts that creates a debian package from binary packages (usually rust tools).

Currently the following packages are handled:

- Direct download from github in deb form: zoxide, fd, hexyl, bat, ripgrep
- Deb created from binary release: eza, fzf, fx, neovim (appimage)


Configuration
=============

As an example, I'm uploading the resulting deb files to buildkite and this is my .env file

```
BK_TOKEN=<token>
BK_ORG=<organization>
BK_REGISTRY=<registry_name>
PKG1UPLOADER=buildkite
VERBOSE=0
```


If you add a variable with the name GITHUB_TOKEN and a github access token the requests will be authenticated. This is needed if you have too many packages and you hit the limit. 

Arguments
=========

The script has 2 different arguments

```
Usage: runner.sh [-V] [-v]
```

-v to enable VERBOSE mode
-V to enable version checks. 

The version check will show something similar to this:

```
Checking versions...
eza-community/eza            v0.21.4 2025-05-30 - 6 day(s) ago (unchanged)
antonmedv/fx                  36.0.3 2025-05-25 - 11 day(s) ago (unchanged)
junegunn/fzf                 v0.62.0 2025-05-04 - 33 day(s) ago (unchanged)
neovim/neovim                v0.11.2 2025-05-30 - 7 day(s) ago (unchanged)
ajeetdsouza/zoxide            v0.9.8 2025-05-26 - 10 day(s) ago (unchanged)
sharkdp/fd                   v10.2.0 2024-08-23 - 287 day(s) ago (unchanged)
sharkdp/bat                  v0.25.0 2025-01-07 - 149 day(s) ago (unchanged)
sharkdp/hexyl                v0.16.0 2024-12-27 - 161 day(s) ago (unchanged)
burntsushi/ripgrep            14.1.1 2024-09-09 - 270 day(s) ago (unchanged)

```

TODO
====


- Create the uploader for Buildkite in Python to avoid multiple uploads.
- ~~Create a version tracker to avoid manually updating the versions.~~
