CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh

function upload {
	if [ -z $BK_TOKEN ] || [ -z $BK_ORG ] || [ -z $BK_REGISTRY ]; then
		echo The variables \$BK_TOKEN, \$BK_ORG and \$BK_REGISTRY must be set. Exiting
		exit
	fi
	echo Uploading to BuildKite

	for i in $OUTPUT_FOLDER/*; do 
	  if [ -f "$i" ]; then
	     if grep -Fxq $i $PKG1UPLOADTRK; then
               echo "\[$(basename ${BASH_SOURCE[0]})\] File already uploaded: $i"
	       continue
	     fi 
	     echo Uploading $i
	     OUTPUT=$(curl -X POST -qs https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$BK_REGISTRY/packages \
	     -H "Authorization: Bearer $BK_TOKEN" \
	     -F "file=@$i")
	    
	     echo $OUTPUT
	     check_output $i "$OUTPUT" 
	  fi
	done
}

function check_output {
	filename=$1
	output="$2"
	if [[ "$output" == *"This registry does not support that package type"* ]]; then
	    echo "Upload FAILED: $( echo $output | jq -r '.message')"
	elif [[ "$output" == *"A package with that name already exists"* || "$output" == *'{"id":'* ]]; then
	    echo "SUCCESS"
            echo $filename >> $PKG1UPLOADTRK
	else
	    echo "Upload FAILED: $(echo $output | jq -r '.message')"
	fi
}

function tester {
	read_env 
PACKAGES=$(curl -H "Authorization: Bearer $BK_TOKEN" \
  -X GET "https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$BK_REGISTRY/packages")

echo $PACKAGES
}

#tester

upload
