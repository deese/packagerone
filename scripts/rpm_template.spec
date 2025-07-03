Name:           $PACKAGE_NAME
Version:        $PACKAGE_VERSION
Release:        1%{?dist}
Summary:        $PACKAGE_SUMMARY

License:        $PACKAGE_LICENSE
URL:            $PACKAGE_URL
$PACKAGE_SOURCES

BuildArch:      $PACKAGE_ARCH

%description
$PACKAGE_DESCRIPTION

%prep
# Nothing to prepare, we are packaging a prebuilt binary

%build
# Nothing to build

%define __brp_strip %{nil}
%define __os_install_post %{nil}

%install
mkdir -p %{buildroot}/usr/bin
$INSTALL_CMDS

%files
$PACKAGE_FILES

%changelog
* $PACKAGE_DATE $PACKAGER_NAME <$PACKAGER_EMAIL> - $PACKAGE_VERSION
- Auto RPM version

