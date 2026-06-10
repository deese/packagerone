
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

function upload {
    CURRENT_FOLDER="$PWD"
    BASE_PATH="$HOME/devel/spzrepo"

    cd $BASE_PATH
    bash $BASE_PATH/repo/mk-apt-repo.sh
    bash $BASE_PATH/repo/mk-yum-repo.sh
    cd $CURRENT_FOLDER
}


function check_output {
	filename=$1
	output="$2"
	if [[ "$output" == *"This registry does not support that package type"* ]]; then
	    logme "Upload FAILED: $( echo $output | jq -r '.message')"
	elif [[ "$output" == *"A package with that name already exists"* || "$output" == *'{"id":'* ]]; then
	    logme "SUCCESS"
        echo $filename >> $PKG1UPLOADTRK
	else
	    logme "Upload FAILED: $(echo $output | jq -r '.message')"
	fi
}


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Manual task - Running uploads"
    OUTPUT_FOLDER="$PWD/dist"
    PKG1UPLOADTRK="$PWD/$(basename $PKG1UPLOADTRK)"
    upload
else
    upload
fi
