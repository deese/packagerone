#!/bin/bash

mkdir -p dist
for i in deb-updater.sh eza-pkg.sh fzf-pkg.sh fx-pkg.sh; do
        bash ./scripts/$i
done
