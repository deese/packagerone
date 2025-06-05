#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

shopt -s nullglob
set -e

function get_ver {
    read VER RELDATE <<< $(get_latest_ver $1 1)
    if [[ -n "$VER" ]]; then
        #echo -e "$1\t\t$VER"
        DAY_DIFF=$(date_diff "$RELDATE")
        DATE_FMT=$(date -d "$RELDATE" +"%Y-%m-%d")
        printf "%-25s %10s %10s\n" "$1" "$VER" "$DATE_FMT - $DAY_DIFF day(s) ago"
    else
        echo "Version not found for $1"
    fi
    return 0
}
## Retrieve the repository names from the package scripts
for file in $CDIR/*-pkg.sh; do
    [[ -e "$file" ]] || continue
    REPO=$(awk -F '=' '/^REPO[[:space:]]*=/ {
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
  gsub(/^["'\''"]|["'\''"]$/, "", $2);
  print $2
}' $file)
    get_ver $REPO
done

## Retrieve the repo names from the deb format
DEB_REPOS=$(grep -E '.*?\w+\/\w+\|.*?VERSION.*deb' $CDIR/deb-updater.sh  | sed -E 's/^"([^|]+)\|.*"$/\1/' | sed -nE 's/.*"([^"]*\/[^|]+)\|.*VERSION.*deb.*/\1/p')

for repo in $DEB_REPOS; do
    get_ver $repo
done

