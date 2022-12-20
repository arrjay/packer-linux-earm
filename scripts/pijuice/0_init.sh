#!/usr/bin/env bash

set -ex

# we're gonna install these, build,. then remove 'em
BUILD_PACKAGES=(
    build-essential devscripts
    libavahi-client-dev libavahi-core-dev libi2c-dev libmodbus-dev libusb-1.0-0-dev
    asciidoc asciidoc-base asciidoc-common asciidoc-dblatex autopoint comerr-dev
    dblatex debhelper dh-autoreconf dh-python dh-strip-nondeterminism
    docbook-dsssl docbook-utils docbook-xml docbook-xsl dwz
    fonts-gfs-baskerville fonts-gfs-porson fonts-lmodern freeipmi-common gettext
    icu-devtools intltool-debian krb5-multidev libapache-pom-java
    libarchive-zip-perl libcairo2 libcommons-logging-java libcommons-parent-java
    libdatrie1 libdebhelper-perl libdeflate-dev libexpat1-dev
    libfile-stripnondeterminism-perl libfontbox-java libfontconfig-dev
    libfontenc1 libfreeipmi-dev libfreeipmi17 libgd-dev libgmp-dev libgmpxx4ldbl
    libgnutls-dane0 libgnutls-openssl27 libgnutls28-dev libgnutlsxx28
    libgraphite2-3 libgssrpc4 libharfbuzz0b libice-dev libice6 libicu-dev
    libidn11 libidn2-dev libipmimonitoring-dev libipmimonitoring6 libjbig-dev
    libjpeg-dev libjpeg62-turbo-dev libjs-jquery libkadm5clnt-mit12
    libkadm5srv-mit12 libkdb5-10 libkpathsea6 libltdl-dev liblzma-dev
    libmime-charset-perl libneon27-gnutls libneon27-gnutls-dev libnetsnmptrapd40
    libnspr4-dev libnss3-dev libosp5 libostyle1c2 libp11-kit-dev libpaper-utils
    libpaper1 libpci-dev libpdfbox-java libpixman-1-0 libpowerman0
    libpowerman0-dev libptexenc1 libpthread-stubs0-dev libsensors-dev
    libsgmls-perl libsm-dev libsm6 libsnmp-base libsnmp-dev libsnmp40 libsombok3
    libsub-override-perl libsynctex2 libtasn1-6-dev libteckit0 libtexlua53
    libtexluajit2 libthai-data libthai0 libtiff-dev libtiffxx5 libtool
    libudev-dev libunbound8 libunicode-linebreak-perl libusb-0.1-4 libusb-dev
    libvpx-dev libvpx6 libwrap0-dev libx11-dev libxau-dev libxaw7 libxcb-render0
    libxcb-shm0 libxcb1-dev libxdmcp-dev libxi6 libxml2-dev libxml2-utils
    libxmu6 libxpm-dev libxrender1 libxslt1.1 libxt-dev libxt6 libzzip-0-13
    lmodern lynx lynx-common nettle-dev openjade opensp po-debconf
    preview-latex-style python3-distutils python3-lib2to3 sgml-base sgml-data
    sgmlspl t1utils teckit tex-common texlive texlive-base texlive-bibtex-extra
    texlive-binaries texlive-extra-utils texlive-fonts-recommended
    texlive-formats-extra texlive-lang-greek texlive-latex-base
    texlive-latex-extra texlive-latex-recommended texlive-luatex
    texlive-pictures texlive-plain-generic texlive-science texlive-xetex tipa
    x11-common x11proto-dev xdg-utils xfonts-encodings xfonts-utils xml-core
    xorg-sgml-doctools xsltproc xtrans-dev
)

# build the latest nut debs on rpi for pijuice support.
apt-get -o APT::Sandbox::User=root update
apt-get install "${BUILD_PACKAGES[@]}"

# build it out of backports...
curl -L -o /tmp/nut.tgz http://deb.debian.org/debian/pool/main/n/nut/nut_2.8.0.orig.tar.gz
[[ "$(sha512sum /tmp/nut.tgz | awk '{print $1}')" == '3c413ae54088045a713eb80cf1bdda474f41bb3b67c7c0248aa7a0c4d441dce1ff42627a2735273d7e36892d1f2eeb895220cf28af63fec2fa0c7a267f82d577' ]]
curl -L -o /tmp/nut_debian.txz http://deb.debian.org/debian/pool/main/n/nut/nut_2.8.0-5.debian.tar.xz
[[ "$(sha512sum /tmp/nut_debian.txz | awk '{print $1}')" == '9ac46c0fa1b927ab3e9760057658950b9eabbc5e8603d9406addca77ec1f6704caae46e60eb7fb243ec96cfed63f94fa2c3a4bc1eabfe035a97e73ec6137084e' ]]
cd /usr/src
tar xf /tmp/nut.tgz
cd nut-*
tar xf /tmp/nut_debian.txz
debuild -b -uc -us
cd ..

# remove all the build packages, then install our binaries.
apt-get remove "${BUILD_PACKAGES[@]}"

# there's a dep for _this package_ we're removing somewhere. oops.
apt-get install python3-pyqt5

dpkg -i nut-i2c_* nut-server_* nut-client_* nut-monitor_* libnutscan2_* libupsclient6_* python3-nut_*

# clean up the rest of the system.
apt autoremove
apt-get clean