Packagerone
===========

Small set of scripts that creates a debian package from binary packages (usually rust tools).

Currently the following packages are handled:

- Direct download from github in deb form: zoxide, fd, hexyl, bat, ripgrep
- Deb created from binary release: eza, fzf, fx


TODO
====


- Create the uploader for Buildkite in Python to avoid multiple uploads.
- Create a version tracker to avoid manually updating the versions.
