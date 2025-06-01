#!/bin/bash
source scripts/environ.sh

read_env

for i in deb-updater.sh eza-pkg.sh fzf-pkg.sh fx-pkg.sh; do
  bash ./scripts/$i
done

if [ ! -z "$PKG1UPLOADER" ]; then
  if [ ! -f "./scripts/uploader_$PKG1UPLOADER.sh" ]; then
     echo "uploader_$PKG1UPLOADER.sh doesn't exit"
     exit
  fi
  echo "Running uploader - $PKG1UPLOADER"
  bash ./scripts/uploader_$PKG1UPLOADER.sh
fi 
