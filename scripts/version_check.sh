#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

shopt -s nullglob
set -e
function get_ver {
    local repo="$1"
    local ver reldate current_version day_diff date_fmt

    read ver reldate <<< "$(get_latest_ver "$repo" 1)"
    current_version=$(get_stored_version "$repo")

    if [[ -n "$ver" ]]; then
        day_diff=$(date_diff "$reldate")
        date_fmt=$(date -d "$reldate" +"%Y-%m-%d")

        if [[ -n "$current_version" ]]; then
            if [[ "$current_version" == "$ver" ]]; then
                status="(unchanged)"
            else
                status="(updated from $current_version)"
            fi
        else
            status="(not previously stored)"
        fi

        printf "%-25s %10s %25s %s\n" "$repo" "$ver" "$date_fmt - $day_diff day(s) ago" "$status"
    else
        echo "Version not found for $repo"
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

