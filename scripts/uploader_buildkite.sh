CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source "$CDIR/functions.sh"

function upload_file {
    FILE="$1"
    REGISTRY="$2"
	if [ -f "$i" ]; then
         if grep -Fxq $i $PKG1UPLOADTRK; then
           logme  "\[$(basename ${BASH_SOURCE[0]})\] File already uploaded: $i"
           return 0
         fi
         logme "Uploading $i"
         OUTPUT=$(curl -X POST -qs https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$REGISTRY/packages \
         -H "Authorization: Bearer $BK_TOKEN" \
         -F "file=@$i")

         #echo $OUTPUT
         check_output $i "$OUTPUT"
    fi

}

function upload {
	if [ -z $BK_TOKEN ] || [ -z $BK_ORG ] || [ -z $BK_REGISTRY_DEB ]; then
        echo The variables \$BK_TOKEN, \$BK_ORG and \$BK_REGISTRY_DEB must be set. Exiting
		exit
	fi
	echo Uploading to BuildKite
		
	for i in $OUTPUT_FOLDER/deb/*; do 
		upload_file "$i" "$BK_REGISTRY_DEB"
	done

	for i in $OUTPUT_FOLDER/rpm/$TARGET_ARCH/*; do
		upload_file "$i" "$BK_REGISTRY_RPM"
	done
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

function tester {
	read_env 
PACKAGES=$(curl -H "Authorization: Bearer $BK_TOKEN" \
  -X GET "https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$BK_REGISTRY/packages")

    echo $PACKAGES
}

#tester

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Manual task - Running uploads"
    upload
fi
