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
	     echo Uploading $i
	     curl -X POST https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$BK_REGISTRY/packages \
	     -H "Authorization: Bearer $BK_TOKEN" \
	     -F "file=@$i"
	  fi
	done
}

function tester {
	read_env 
PACKAGES=$(curl -H "Authorization: Bearer $BK_TOKEN" \
  -X GET "https://api.buildkite.com/v2/packages/organizations/$BK_ORG/registries/$BK_REGISTRY/packages")

echo $PACKAGES
}

tester

# upload
