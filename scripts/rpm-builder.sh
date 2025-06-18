#!/bin/bash
CDIR=$(dirname -- "${BASH_SOURCE[0]}")
source $CDIR/environ.sh
PACKAGE_VARS=(PACKAGER_NAME PACKAGE_NAME PACKAGE_VERSION PACKAGE_FILES INSTALL_CMDS PACKAGE_DATE \
          PACKAGE_DESCRIPTION PACKAGER_EMAIL PACKAGE_LICENSE PACKAGE_SUMMARY \
                PACKAGE_URL PACKAGE_SOURCES PACKAGE_ARCH)

build_rpm() {
    mkdir -p $OUTPUT_FOLDER/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    #cp -a  rpm_template.spec $DEST/rpmbuild/SPECS/${PACKAGE_NAME}.spec
    #local config_file="$1"

    # Source the configuration
    #source "$config_file"
    #     
    echo Building $DPKG_BASENAME rpm

	INSTALL_CMDS=""
    PACKAGE_NAME=$DPKG_BASENAME
    PACKAGE_ARCH=$TARGET_ARCH
    PACKAGE_SOURCES=""
    PACKAGE_FILES=""
    PACKAGE_DATE=$(date +"%Y-%m-%d")
    PACKAGE_URL="https://github.com/$REPO"

    count=0
	for entry in "${INSTALL_FILES[@]}"; do
        IFS='|' read -r source perms destination <<< "$entry"
        source=$(var_substitution "$source")
        cp $source $OUTPUT_FOLDER/rpmbuild/SOURCES/
        PACKAGE_SOURCES="Source$count:\t\t$source\n"
        PACKAGE_FILES="$PACKAGE_FILES%attr($perms, root, root) $destination\n"
        INSTALL_CMDS="${INSTALL_CMDS}install -Dm$perms %{SOURCE$count}  %{buildroot}$destination\n"
		count=$((count + 1 ))
    done

    #TEMPLATE="$CDIR/rpm_template.spec"
    TEMPLATE_CONTENT="$(<"$CDIR/rpm_template.spec")"
    TEMPLATE="$(var_substitution "$TEMPLATE_CONTENT" "${PACKAGE_VARS[@]}")"
    echo -e "$TEMPLATE" >  $OUTPUT_FOLDER/rpmbuild/SPECS/$PACKAGE_NAME.spec

    rpmbuild -bb $OUTPUT_FOLDER/rpmbuild/SPECS/$PACKAGE_NAME.spec --define "_topdir $PWD/$OUTPUT_FOLDER/rpmbuild" --define "_rpmdir $PWD/$OUTPUT_FOLDER/rpm"
    
    
}
#install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/eza

