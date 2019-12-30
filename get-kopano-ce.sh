#!/usr/bin/env bash

set -euo pipefail

# Kopano Core Communtiy Packages Downloader
#
# By Louis van Belle
# Tested on Debian 9 amd64, should work on Ubuntu 16.04/18.04 also.
#
# You run it, it get the lastest versions of Kopano and your ready to install.
# A local file repo is create, which you can use for a webserver also.
#
# Use at own risk, use it, change it if needed and share it.!

# Version 1.0, 2019 Feb 12, Added on github.
# https://github.com/thctlo/Kopano/blob/master/get-kopano-community.sh
#
# Updated 1.1, 2019-02-12, added z-push repo.
# Updated 1.2, 2019-02-12, added libreoffice online repo.
# Updated 1.3, 2019-02-12, added check on lynx and curl
# Updated 1.3.1, 2019-02-14, added check for failing packages at install
# Updated Fix typos
# Updates 1.4, 2019-02-15, added autobackup
# Updates 1.4.1, 2019-02-15, few small fixes
# Updates 1.4.2, 2019-02-18, added sudo/root check.
# Updates 1.5.0, 2019-04-24, simplify a few bits
# Updates 1.5.1, 2019-04-29, fix incorrect gpg2 package name to gnupg2
# Updates 1.5.2, 2019-06-17, fix incorrect gnupg/gpg2 detection. package name/command did not match.
# Updates 1.6,   2019-08-18, add buster detection, as kopano change the way it shows the debian version ( removed .0)
# Updates 1.7,   2019-09-24, Update for kopano-site changes, removed unsupported version from default settings.

# Sources used:
# https://download.kopano.io/community/
# https://documentation.kopano.io/kopanocore_administrator_manual
# https://wiki.z-hub.io/display/ZP/Installation

# For the quick and unpatient, keep the below defaults and run :
# wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | bash
# apt install kopano-server-packages
# Optional, when you are upgrading: apt dist-upgrade && kopano-dbadm usmp
#
# Dont change the base folder once its set!
# If you do you need to change the the file:
#  /etc/apt/sources.list.d/local-file.list also.
BASE_FOLDER="$HOME/kopano"

# A subfolder in BASE_FOLDER.
EXTRACT_DIR="apt"

# Autobackup the previous version.
# A backup will be made of the apt/$ARCH folder to backukp/
# The backup path is relative to the BASE_FOLDER.
ENABLE_AUTO_BACKUP="yes"

# The Kopano Community link.
KOPANO_CE_URL="https://download.kopano.io/community"
# The packages you can pull and put directly in to the repo.
KOPANO_CE_PKGS="core archiver deskapp files mdm smime webapp webmeetings"
KOPANO_CE_PKGS_ARCH_ALL="files mdm webapp webmeetings"

# TODO
# make function for regular .tar.gz files like :
# kapp konnect kweb libkcoidc mattermost-plugin-kopanowebmeetings
# mattermost-plugin-notifymatters

# If you want z-push available also in your apt, set this to yes.
# z-push repo stages.
# After the setup, its explained in the repo filo.
ENABLE_Z_PUSH_REPO="yes"

# Please note, limited support, only Debian 9 is supported in the script.
# see deb https://download.kopano.io/community/libreofficeonline/
ENABLE_LIBREOFFICE_ONLINE="no"

################################################################################

# dependencies for this script:
NEEDED_PROGRAMS="lsb_release apt-ftparchive curl gnupg2 lynx tee"
# the above packages can be installed with executing `apt install ${NEEDED_PROGRAMS}`
# Note gnupg2 is using the command gpg2.

#### Program
function item_in_list {
    local item="$1"
    local list="$2"

    return $([[ $list =~ (^|[[:space:]])"$item"([[:space:]]|$) ]])
}

for program in $NEEDED_PROGRAMS; do
    # fix for 1.5.1. 
    if program="gnupg2"; then program=gpg2; fi
    if ! command -v "$program" &> /dev/null; then
        echo "$program is missing. Please install it and rerun the script."
        exit 1
    fi
done

# Setup base folder en enter it.
if [ ! -d $BASE_FOLDER ] ; then
    mkdir $BASE_FOLDER
fi
cd $BASE_FOLDER

# set needed variables
OSNAME="$(lsb_release -si)"
OSDIST="$(lsb_release -sc)"
if [ "${OSNAME}" = "Debian" ] && [ ! "${OSDIST}" = "buster" ] ; then
    # Needed for Debian <10
    OSDISTVER="$(lsb_release -sr|cut -c1).0"
else
    OSDISTVER="$(lsb_release -sr)"
fi
GET_OS="${OSNAME}_${OSDISTVER}"
GET_ARCH="$(dpkg --print-architecture)"
if [ "${GET_ARCH}" = "i686" ] ; then
    GET_ARCH_RED="i386"
else
    GET_ARCH_RED=${GET_ARCH}
fi

# TODO this block does not really make sense, rewrite it so that if moves artifacts from previous runs in a more compact way
### Autobackup
if [ "${ENABLE_AUTO_BACKUP}" = "yes" ]
then
    if [ ! -d "bckp" ] ; then
        mkdir -p bckp
    fi
    if [ -d "${EXTRACT_DIR}/${GET_ARCH_RED}" ]
    then
        echo "Moving previous version to : backups/${OSDIST}-${GET_ARCH_RED}-$(date +%F)"
        # we move the previous version.
        mv "${EXTRACT_DIR}/${GET_ARCH_RED}" bckp/"${OSDIST}-${GET_ARCH_RED}-$(date +%F)"
    fi
fi

### Core start
echo "Getting Kopano for $OSDIST: $GET_OS $GET_ARCH"

# Create extract to folders, needed for then next part. get packages.
if [ ! -d "${EXTRACT_DIR}/${GET_ARCH_RED}" ] ; then
    mkdir -p $EXTRACT_DIR/$GET_ARCH_RED
fi

# get packages and extract them in KOPANO_EXTRACT2FOLDER
for pkg in $KOPANO_CE_PKGS ; do
    if item_in_list "${pkg}" "${KOPANO_CE_PKGS_ARCH_ALL}" ; then
        PKG_ARCH="all"
    else
        PKG_ARCH=${GET_ARCH}
    fi
    echo "Getting and extracting $pkg ( ${GET_OS}-${PKG_ARCH} ) to ${EXTRACT_DIR}."
    curl -q -L $(lynx -listonly -nonumbers -dump "${KOPANO_CE_URL}/${pkg}:/" | grep "${GET_OS}-${PKG_ARCH}".tar.gz) \
    | tar -xz -C ${EXTRACT_DIR}/${GET_ARCH_RED} --strip-components=1 --wildcards "*.deb" -f -
done

cd $EXTRACT_DIR

# Create the Packages file so apt knows what to get.
read -p "Create a local apt repo from the dowloaded packages? [Y/n] " RESP
RESP=${RESP:-y}
if [ "$RESP" = "y" ] ; then
        echo "Please wait, generating ${GET_ARCH}/Packages File"
        apt-ftparchive packages "${GET_ARCH_RED}"/ > "${GET_ARCH_RED}"/Packages

    {
        echo "# file repo format"
        echo "deb [trusted=yes] file://${BASE_FOLDER}/${EXTRACT_DIR} ${GET_ARCH_RED}/"
        echo "# webserver format"
        echo "#deb [trusted=yes] http://localhost/apt ${GET_ARCH_RED}/"
        echo "# to enable the webserver, install a webserver ( apache/nginx )"
        echo "# and symlink ${BASE_FOLDER}/${EXTRACT_DIR}/ to /var/www/html/${EXTRACT_DIR}"
    } | tee /etc/apt/sources.list.d/kopano-ce.list > /dev/null

    echo
    echo "The installed Kopano CORE apt-list file: /etc/apt/sources.list.d/kopano-ce.list"
    echo
fi

### Core end
### Z-PUSH start
if [ "${ENABLE_Z_PUSH_REPO}" = "yes" ] ; then
    SET_Z_PUSH_REPO="http://repo.z-hub.io/z-push:/final/${GET_OS} /"
    SET_Z_PUSH_FILENAME="kopano-z-push.list"
    echo "Checking for Z_PUSH Repo on ${OSNAME}."
    if [ ! -e /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ] ; then
        if [ ! -f /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ] ; then
            {
            echo "# "
            echo "# Kopano z-push repo"
            echo "# Documentation: https://wiki.z-hub.io/display/ZP/Installation"
            echo "# https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
            echo "# https://documentation.kopano.io/user_manual_kopanocore/configure_mobile_devices.html"
            echo "# Options to set are :"
            echo "# old-final = old-stable, final = stable, pre-final=testing, develop = experimental"
            echo "# "
            echo "deb ${SET_Z_PUSH_REPO}"
            } | tee /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" > /dev/null
            echo "Created file: /etc/apt/sources.list.d/${SET_Z_PUSH_FILENAME}"
        fi

        # install the repo key once.
        if [ "$(apt-key list | grep -c kopano)" -eq 0 ] ; then
            echo -n "Installing z-push signing key : "
            curl -vs http://repo.z-hub.io/z-push:/final/"${GET_OS}"/Release.key | apt-key add -
        else
            echo "The Kopano Z_PUSH repo key was already installed."
        fi
    else
        echo "The Kopano Z_PUSH repo was already setup."
        echo ""
    fi
    echo "The z-push info: https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
    echo "Before you configure/install also read: https://wiki.z-hub.io/display/ZP/Installation"
    echo ""
fi
### Z_PUSH End

### LibreOffice Online start ( only tested Debian 9 )
if [ "${ENABLE_LIBREOFFICE_ONLINE}" = "yes" ] ; then
    if [ "$GET_OS" = "Debian_9.0" ] || [ "$GET_OS" = "Debian_8.0" ] || [ "${GET_OS}" = "Ubuntu_16.04" ]
    then
        SET_OFFICE_ONLINE_REPO="http://download.kopano.io/community/libreofficeonline/${GET_OS} /"
        SET_OFFICE_ONLINE_FILENAME="kopano-libreoffice-online.list"
        echo "Checking for Kopano LibreOffice Online Repo on ${OSNAME}."
        if [ ! -e /etc/apt/sources.list.d/"${SET_OFFICE-ONLINE_FILENAME}" ] ; then
            if [ ! -f /etc/apt/sources.list.d/"${SET_OFFICE_ONLINE_FILENAME}" ] ; then
                {
                echo "# "
                echo "# Kopano LibreOffice Online repo"
                echo "# Documentation: https://documentation.kopano.io/kopano_loo-documentseditor/"
                echo "# "
                echo "deb ${SET_OFFICE_ONLINE_REPO}"
                } | tee /etc/apt/sources.list.d/"${SET_OFFICE_ONLINE_FILENAME}" > /dev/null
                echo "Created file : /etc/apt/sources.list.d/${SET_OFFICE_ONLINE_FILENAME}"
            fi
        else
            echo "The Kopano LibreOffice Online repo was already setup."
            echo ""
        fi
    else
        echo "Sorry, Your os and/or version not supported in this script."
    fi
fi
### LibreOffice Online End

echo "Please wait, running apt update"
apt update -qy

echo "Kopano core versions available on the repo now are: "
apt-cache policy kopano-server-packages
echo " "
echo " "
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"