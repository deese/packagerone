#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
TMPFOLDER=$(mktemp -dt "pkgone-XXXXXXXX")
WGET="wget -q"
LATEST_FILE="$TMPFOLDER/latest.json"
DOWNLOAD_LINKS="$TMPFOLDER/links.txt"
OUTPUT_GPT="output_gpt.log"

function run_clean {
    FILENAME=$(basename "$1")
    read -p "Do you want to clean the files [y/N]: " answer
	case "$answer" in
		[Yy]* )
			echo "Deleting file..."
			rm -fr "$TMPFOLDER" # "$LATEST_FILE" "$DOWNLOAD_LINKS" "$FILENAME" "$OUTPUT_GPT"
			;;
		* )
			echo "File not deleted."
			;;
	esac
}
function var_substitution {
    VARS_TO_SUBST=(FILELIST DOWNLOAD_LINK)
    RET="$1"
    shift
    if [[ $# -gt 0 ]]; then
        VARS_TO_SUBST=("$@")
    fi

    local max_loops=5
    local _count=0
    stderr "substituting.."
    while [[ "$RET" == *'$'* && $_count -lt $max_loops ]]; do
        for var in "${VARS_TO_SUBST[@]}"; do
            #stderr "echking $var"
            if [[ -n "${!var+x}" ]]; then
                #stderr "Substituting variable [$_count] $var - ${!var}"
                val="${!var}"  # Indirect expansion to get value of the variable
                RET="${RET//\$$var/$val}"
            fi
        done
        _count=$(( _count + 1 ))
    done
    echo "$RET"
}

function stderr {
    echo "$1" >&2
}

function query_ai {
    if [ -z "$OPENROUTER_API_KEY" ]; then
        echo "Set the \$OPENROUTER_API_KEY in order to use the LLM query."
        return 1
    fi
    PROMPT="$(jq -n --arg prompt "$1"  '{model: "openai/gpt-4o-mini", prompt: $prompt}')"
    #PROMPT='{model: "openai/gpt-4o-mini", prompt: "'$1'"}'
    RESP=$(curl -qsX POST "https://openrouter.ai/api/v1/completions" \
         -H "Authorization: Bearer $OPENROUTER_API_KEY" \
         -H "Content-Type: application/json" \
         -d "$PROMPT")

    #LINK=$(echo $RESP | jq -r '.choices[0].message.content')
    #if [[ "$LINK" == *"https://github.com"* ]]; then
    #    echo "$LINK"
    #else
    #    echo "ERROR: $RESP"
    #fi
    echo -e "PROMPT: $PROMPT" >> $OUTPUT_GPT
    echo "RESPONSE: $RESP" >> $OUTPUT_GPT
    echo "$RESP"
}

function download_latest_gh {
    stderr "Downloading latest from: $1"
	if [ -f "$LATEST_FILE" ]; then
		stderr "Data already exists."
		return 0
	fi
	if [[ ! -z $GITHUB_TOKEN ]]; then
	   EXTRA_ARGS=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Accept: application/vnd.github+json"
	   )
	else
           EXTRA_ARGS=() #""
    fi
	
	curl "${EXTRA_ARGS[@]}" -qs https://api.github.com/repos/$1/releases/latest > $LATEST_FILE
}

function get_download_links {
    stderr "Retrieving links"

    jq -r '.assets[] | select(.name | test("(?=.*linux)(?=.*x86_64).*")) | .browser_download_url' $LATEST_FILE > $DOWNLOAD_LINKS
    jq -r '.assets[] | select(.name | test("(?=.*linux)(?=.*amd64).*")) | .browser_download_url' $LATEST_FILE >> $DOWNLOAD_LINKS

    if [[ ! -s "$DOWNLOAD_LINKS" ]]; then
        jq -r '.assets[] | select(.name | test(".*linux.*")) | .browser_download_url' $LATEST_FILE >> $DOWNLOAD_LINKS
    fi

}

get_extension() {
    filename=$(basename -- "$1")
	ext="${filename##*.}"

    if [[ "$filename" == *".tar."* && "$ext" != *"tar."* ]]; then
        ext="tar.$ext"
    fi
	echo $ext 
}

#REPO="sharkdp/bat"

function get_repo_data {
    stderr "Get Repo Data"
    download_latest_gh "$1"
    get_download_links
    

    PROMPT_LINKS="$(<$DOWNLOAD_LINKS)"
    if [[ $(echo -e "$PROMPT_LINKS"|wc -l) -eq 1 ]]; then
        stderr "Only one link found."
        echo "$PROMPT_LINKS"
        return 0
        #stderr "Only one found"
    fi
    PROMPT="Given the following links and giving priority to tar.gz and similar,  and GNU over musl. To be run on an x64 machine. What will be best match? return only the link. $PROMPT_LINKS"
    RETR=$(query_ai "$PROMPT")
    echo "$RETR" >> "$OUTPUT_GPT"
    # | jq -r '.choices[0].message.content')

    echo "$RETR" | jq -r '.choices[0].text'
}

function get_file_listing {
    FILENAME=$(basename "$DOWNLOAD_LINK")
    FILENAME="$TMPFOLDER/$FILENAME"
    if [ ! -f $FILENAME ]; then 
        $WGET $DOWNLOAD_LINK -O $FILENAME
    fi

    if [ ! -f $FILENAME ]; then
        stderr Error downloading file
        exit 1
    fi

    EXT=$(get_extension $FILENAME)

    if [[ "$EXT" == "tar"* ]]; then
        FILELIST=$(tar tvf $FILENAME)
        echo -e "$FILELIST"
    fi
}


DOWNLOAD_LINK=$(get_repo_data "$1")
echo "Download link: $DOWNLOAD_LINK"
if [[ "$DOWNLOAD_LINK" != *"https://github.com"* ]]; then
        echo $DOWNLOAD_LINK
        exit 1
fi

FILELIST=$(get_file_listing "$DOWNLOAD_LINK")

TEMPLATE=$(<"$CDIR/chatgpt.prompt")
TEMPLATE=$(var_substitution "$TEMPLATE")

DATA=$(query_ai "$TEMPLATE")
FORMULA=$(echo $DATA | jq -r '.choices[0].text')


if [ -d "formulas" && ! -f "formulas/uv-pkg.formula" ]; then

fi


run_clean $DOWNLOAD_LINK
