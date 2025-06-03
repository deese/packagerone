Packagerone
===========

Small set of scripts that creates a debian package from binary packages (usually rust tools).

Currently the following packages are handled:

- Direct download from github in deb form: zoxide, fd, hexyl, bat, ripgrep
- Deb created from binary release: eza, fzf, fx


Configuration
=============

As an example, I'm uploading the resulting deb files to buildkite and this is my .env file

BK_TOKEN=<token>
BK_ORG=<organization>
BK_REGISTRY=<registry_name>
PKG1UPLOADER=buildkite
VERBOSE=0

TODO
====


- Create the uploader for Buildkite in Python to avoid multiple uploads.
- ~~Create a version tracker to avoid manually updating the versions.~~
