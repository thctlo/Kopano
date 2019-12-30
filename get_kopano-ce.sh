#!/usr/bin/env bash

set -euo pipefail

# Kopano CE Packages Downloader
# Use at own risk, use it, change it if needed and share it.

# Forked from:
# https://github.com/thctlo/Kopano.git
# Sources used:
# https://download.kopano.io/community/
# https://documentation.kopano.io/kopanocore_administrator_manual
# https://wiki.z-hub.io/display/ZP/Installation

# For the quick and unpatient, keep the below defaults and run :
# wget -O - https://raw.githubusercontent.com/lcnittl/Kopano/master/get-kopano-ce.sh | bash
# apt install kopano-server-packages
# Optional, when you are upgrading:
# apt dist-upgrade && kopano-dbadm usmp

BASE_DIR="$HOME/kopano"
EXTRACT_DIR="apt"

# Autobackup the previous version.
# A backup will be made of the $BASE_DIR/$EXTRACT_DIR/$GET_ARCH_RED folder to $BASE_DIR/$BACKUP_DIR
# The backup path is relative to the BASE_DIR.
ENABLE_AUTO_BACKUP="yes"
BACKUP_DIR="bckp"

# The Kopano Community link.
KOPANO_CE_URL="https://download.kopano.io/community"
KOPANO_CE_SRCS_LIST="kopano-ce.list"
# The packages you can pull and put directly in to the repo.
KOPANO_CE_PKGS="core archiver deskapp files mdm smime webapp webmeetings"
KOPANO_CE_PKGS_ARCH_ALL="files mdm webapp webmeetings"

# TODO
# make function for regular .tar.gz files like :
# kapp konnect kweb libkcoidc mattermost-plugin-kopanowebmeetings mattermost-plugin-notifymatters

# If you want z-push available also in your apt, set this to yes.
# z-push repo stages.
# After the setup, its explained in the repo file.
ENABLE_Z_PUSH_REPO="yes"

# Please note, limited support, only Debian 9 is supported in the script.
# see deb https://download.kopano.io/community/libreofficeonline/
ENABLE_LIBREOFFICE_ONLINE="no"
LOO_SUPPORTED_OSS="Debian_8.0 Debian_9.0 Ubuntu_16.04"

################################################################################

# dependencies for this script:
REQUIRED_APPS="lsb_release apt-ftparchive curl gnupg2 lynx tee"
# the above packages can be installed with executing `apt install ${REQUIRED_APPS}`
# Note gnupg2 is using the command gpg2.

#### Program
function item_in_list {
    local item="$1"
    local list="$2"

    return $([[ $list =~ (^|[[:space:]])"$item"([[:space:]]|$) ]])
}

for app in $REQUIRED_APPS; do
    # fix for 1.5.1. 
    if app="gnupg2"; then app=gpg2; fi
    if ! command -v "$app" &> /dev/null; then
        echo "$app is missing. Please install it and rerun the script."
        exit 1
    fi
done

# Setup base folder en enter it.
if [ ! -d $BASE_DIR ] ; then
    mkdir $BASE_DIR
fi
cd $BASE_DIR

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
    if [ ! -d "$BACKUP_DIR" ] ; then
        mkdir -p $BACKUP_DIR
    fi
    if [ -d "${EXTRACT_DIR}/${GET_ARCH_RED}" ] ; then
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
        echo "deb [trusted=yes] file://${BASE_DIR}/${EXTRACT_DIR} ${GET_ARCH_RED}/"
        echo "# webserver format"
        echo "#deb [trusted=yes] http://localhost/apt ${GET_ARCH_RED}/"
        echo "# to enable the webserver, install a webserver ( apache/nginx )"
        echo "# and symlink ${BASE_DIR}/${EXTRACT_DIR}/ to /var/www/html/${EXTRACT_DIR}"
    } | tee /etc/apt/sources.list.d/${KOPANO_CE_SRCS_LIST} > /dev/null

    echo "The installed Kopano CORE apt-list file: /etc/apt/sources.list.d/${KOPANO_CE_SRCS_LIST}"
fi

### Core end
### Z-PUSH start
if [ "${ENABLE_Z_PUSH_REPO}" = "yes" ] ; then
    Z_PUSH_REPO_URL="http://repo.z-hub.io/z-push:/final/${GET_OS} /"
    Z_PUSH_SRCS_LIST="kopano-z-push.list"
    echo "Checking for Z_PUSH Repo on ${OSNAME}."
    if [ ! -e /etc/apt/sources.list.d/"${Z_PUSH_SRCS_LIST}" ] ; then
        if [ ! -f /etc/apt/sources.list.d/"${Z_PUSH_SRCS_LIST}" ] ; then
            {
            echo "# "
            echo "# Kopano z-push repo"
            echo "# Documentation: https://wiki.z-hub.io/display/ZP/Installation"
            echo "# https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
            echo "# https://documentation.kopano.io/user_manual_kopanocore/configure_mobile_devices.html"
            echo "# Options to set are :"
            echo "# old-final = old-stable, final = stable, pre-final=testing, develop = experimental"
            echo "# "
            echo "deb ${Z_PUSH_REPO_URL}"
            } | tee /etc/apt/sources.list.d/"${Z_PUSH_SRCS_LIST}" > /dev/null
            echo "Created file: /etc/apt/sources.list.d/${Z_PUSH_SRCS_LIST}"
        fi
    else
        echo "The Kopano Z_PUSH repo was already setup."
        echo
    fi

    # install the repo key once.
    if [ "$(apt-key list 2> /dev/null | grep -c kopano)" -eq 0 ] ; then
        echo -n "Installing z-push signing key : "
        curl -q -L http://repo.z-hub.io/z-push:/final/"${GET_OS}"/Release.key | apt-key add -
    else
        echo "The Kopano Z_PUSH repo key was already installed."
    fi

    echo "The z-push info: https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
    echo "Before you configure/install also read: https://wiki.z-hub.io/display/ZP/Installation"
fi
### Z_PUSH End

### LibreOffice Online start ( only tested Debian 9 )
if [ "${ENABLE_LIBREOFFICE_ONLINE}" = "yes" ] ; then
    if item_in_list "${GET_OS}" "${LOO_SUPPORTED_OSS}" ; then
        KOPANO_LOO_URL="http://download.kopano.io/community/libreofficeonline/${GET_OS} /"
        KOPANO_LOO_SRCS_LIST="kopano-libreoffice-online.list"
        echo "Checking for Kopano LibreOffice Online Repo on ${OSNAME}."
        if [ ! -e /etc/apt/sources.list.d/"${KOPANO_LOO_SRCS_LIST}" ] ; then
            if [ ! -f /etc/apt/sources.list.d/"${KOPANO_LOO_SRCS_LIST}" ] ; then
                {
                    echo "# "
                    echo "# Kopano LibreOffice Online repo"
                    echo "# Documentation: https://documentation.kopano.io/kopano_loo-documentseditor/"
                    echo "# "
                    echo "deb ${KOPANO_LOO_URL}"
                } | tee /etc/apt/sources.list.d/"${KOPANO_LOO_SRCS_LIST}" > /dev/null
                echo "Created file : /etc/apt/sources.list.d/${KOPANO_LOO_SRCS_LIST}"
            fi
        else
            echo "The Kopano LibreOffice Online repo was already setup."
        fi
    else
        echo "Sorry, your OS and/or release are not supported in this script."
    fi
fi
### LibreOffice Online End

echo
echo "Please wait, running apt update"
apt update -qy

echo "Kopano core versions available on the repo now are: "
apt-cache policy kopano-server-packages

echo
echo
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"
