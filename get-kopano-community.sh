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
BASE_FOLDER=$HOME/kopano-repo
BASE_FOLDER=/tmp/kopano-repo

# A subfolder in BASE_FOLDER.
KOPANO_EXTRACT2FOLDER="apt"

# Autobackup the previous version.
# A backup will be made of the apt/$ARCH folder to backukp/
# The backup path is relative to the BASE_FOLDER.
ENABLE_AUTO_BACKUP="yes"

# The Kopano Community link.
KOPANO_COMMUNITY_URL="https://download.kopano.io/community"
# The packages you can pull and put directly in to the repo.
KOPANO_COMMUNITY_PKG="core archiver deskapp files mattermost mdm meet smime webapp webmeetings"

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
ENABLE_LIBREOFFICE_ONLINE="yes"

################################################################################
##### Needed for this program.
#if ! [[ $EUID -eq 0 ]]
#then
#    echo "This script should be run using sudo or by root."
#    exit 1
#fi

# We need the lsb-release package
NEEDED_PROGRAMS="lsb_release apt-ftparchive curl gpg2 lynx sudo tee"

#### Program
for var in $NEEDED_PROGRAMS; do
    if ! command -v "$var" &> /dev/null; then
        echo "$var is missing. Please install it and rerun the script."
        exit 1
    fi
done

# Setup base folder en enter it.
mkdir -p $BASE_FOLDER
cd $BASE_FOLDER

# set needed variables
OSNAME="$(lsb_release -si)"
OSDIST="$(lsb_release -sc)"
OSDISTVER="$(lsb_release -sr)"
OSDISTVER0="$(lsb_release -sr|cut -c1).0"
# check OS/version
if [ "${OSNAME}" = "Debian" ]
then
    # Needed for Kopano Community ( used Debian_9.0 )
    GET_OS="${OSNAME}_${OSDISTVER0}"
elif [ "${OSNAME}" = "Ubuntu" ]
then
    # For ubuntu results in Ubuntu_18.04
    GET_OS="${OSNAME}_${OSDISTVER}"
fi
GET_ARCH="$(dpkg --print-architecture)"

# TODO this block does not really make sense, rewrite it so that if moves artifacts from previous runs in a more compact way
### Autobackup
if [ "${ENABLE_AUTO_BACKUP}" = "yes" ]
then
    mkdir -p backups
    if [ -d "${KOPANO_EXTRACT2FOLDER}/${GET_ARCH}" ]
    then
        echo "Moving previous version to : backups/${OSDIST}-${GET_ARCH}-$(date +%F)"
        # we move the previous version.
        mv "${KOPANO_EXTRACT2FOLDER}/${GET_ARCH}" backups/"${OSDIST}-${GET_ARCH}-$(date +%F)"
    fi
fi

### Core start
echo "Getting Kopano for $OSDIST: $GET_OS $GET_ARCH"

# Create extract to folders, needed for then next part. get packages.
mkdir -p $KOPANO_EXTRACT2FOLDER

# get packages and extract them in KOPANO_EXTRACT2FOLDER
for pkglist in $KOPANO_COMMUNITY_PKG
do
    # packages listed here must be maintained manualy.. ( the -all versions )
    if [ "${pkglist}" = "files" ]||[ "${pkglist}" = "mdm" ]||[ "${pkglist}" = "webapp" ]
    then
        echo "Getting and extracting $pkglist to ${KOPANO_EXTRACT2FOLDER}. ( -all ) "
        curl -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITY_URL}/${pkglist}:/" | grep "${GET_OS}-all".tar.gz)" \
        | tar -xz -C ${KOPANO_EXTRACT2FOLDER} --strip-components 1 -f -
    else
        echo "Getting and extracting $pkglist to ${KOPANO_EXTRACT2FOLDER}. ( -${GET_ARCH} ) "
        curl -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITY_URL}/${pkglist}:/" | grep "${GET_OS}-${GET_ARCH}".tar.gz)" \
        | tar -xz -C ${KOPANO_EXTRACT2FOLDER} --strip-components 1 -f -
    fi
done

cd $KOPANO_EXTRACT2FOLDER || exit

# Create arch based folder.
if [ "${GET_ARCH}" = "amd64" ]; then
    if [ ! -d amd64 ]; then
        mkdir amd64
    elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
        if [ ! -d i386 ]; then
            mkdir i386
        fi
    fi
fi
# move files
if [ "${GET_ARCH}" = "amd64" ]; then
    mv -n ./*_amd64.deb amd64/ || true
    mv -n ./*_all.deb amd64/ || true
    # remove left overs
    rm ./*.deb
    # remove 2 left overs from kopano-archiver
    rm ./Packages
    rm ./Packages.gz
    rm ./Release
    rm ./Release.gpg
    rm ./Release.key
elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
    mv -n ./*_i386.deb i386/ || true
    mv -n ./*_all.deb i386/ || true
    # remove left overs
    rm ./*.deb
    # remove 2 left overs from kopano-archiver
    rm ./Packages
    rm ./Packages.gz
    rm ./Release
    rm ./Release.gpg
    rm ./Release.key
fi

# Create the Packages file so apt knows what to get.
echo "Please wait, generating  ${GET_ARCH}/Packages File"
apt-ftparchive packages "${GET_ARCH}"/ > "${GET_ARCH}"/Packages


if [ ! -e /etc/apt/sources.list.d/kopano-community.list ]
then
    {
    echo "# File setup for Kopano Community."
    echo "deb [trusted=yes] file:${BASE_FOLDER}/${KOPANO_EXTRACT2FOLDER}/ ${GET_ARCH}/"
    echo "# Webserver setup for Kopano Community."
    echo "#deb [trusted=yes] http://localhost/apt ${GET_ARCH}/"
    echo "# to enable the webserver, install a webserver ( apache/nginx )"
    echo "# and symlink ${BASE_FOLDER}/${KOPANO_EXTRACT2FOLDER}/ to /var/www/html/${KOPANO_EXTRACT2FOLDER}"
    } | sudo tee /etc/apt/sources.list.d/kopano-community.list > /dev/null
fi

echo " "
echo "The installed Kopano CORE apt-list file: /etc/apt/sources.list.d/kopano-community.list"
echo " "
### Core end
### Z-PUSH start
if [ "${ENABLE_Z_PUSH_REPO}" = "yes" ]; then
    SET_Z_PUSH_REPO="http://repo.z-hub.io/z-push:/final/${GET_OS} /"
    SET_Z_PUSH_FILENAME="kopano-z-push.list"
    echo "Checking for Z_PUSH Repo on ${OSNAME}."
    if [ ! -e /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ]; then
        if [ ! -f /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ]; then
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
            } | sudo tee /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" > /dev/null
            echo "Created file : /etc/apt/sources.list.d/${SET_Z_PUSH_FILENAME}"
        fi

        # install the repo key once.
        if [ "$(apt-key list | grep -c kopano)" -eq 0 ]; then
            echo -n "Installing z-push signing key : "
            curl -vs http://repo.z-hub.io/z-push:/final/"${GET_OS}"/Release.key | sudo apt-key add -
        else
            echo "The Kopano Z_PUSH repo key was already installed."
        fi
    else
        echo "The Kopano Z_PUSH repo was already setup."
        echo ""
    fi
    echo "The z-push info : https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
    echo "Before you configure/install also read : https://wiki.z-hub.io/display/ZP/Installation"
    echo ""
fi
### Z_PUSH End

### LibreOffice Online start ( only tested Debian 9 )
if [ "${ENABLE_LIBREOFFICE_ONLINE}" = "yes" ]; then
    if [ "$GET_OS" = "Debian_9.0" ] || [ "$GET_OS" = "Debian_8.0" ] || [ "${GET_OS}" = "Ubuntu_16.04" ]
    then
        SET_OFFICE_ONLINE_REPO="http://download.kopano.io/community/libreofficeonline/${GET_OS} /"
        SET_OFFICE_ONLINE_FILENAME="kopano-libreoffice-online.list"
        echo "Checking for Kopano LibreOffice Online Repo on ${OSNAME}."
        if [ ! -e /etc/apt/sources.list.d/"${SET_OFFICE-ONLINE_FILENAME}" ]; then
            if [ ! -f /etc/apt/sources.list.d/"${SET_OFFICE_ONLINE_FILENAME}" ]; then
                {
                echo "# "
                echo "# Kopano LibreOffice Online repo"
                echo "# Documentation: https://documentation.kopano.io/kopano_loo-documentseditor/"
                echo "# "
                echo "deb ${SET_OFFICE_ONLINE_REPO}"
                } | sudo tee /etc/apt/sources.list.d/"${SET_OFFICE_ONLINE_FILENAME}" > /dev/null
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

echo "Please wait, running apt-get update"
sudo apt-get update -qy 2&>/dev/null

echo "Kopano core versions available on the repo now are: "
apt-cache policy kopano-server-packages
echo " "
echo " "
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"
