#!/usr/env bash

# Version 1.0, 2019 Feb 12
# Updated 1.1, 2019 Feb 12, added z-push repo.
# Updated 1.2, 2019 Feb 12, added libreoffice online repo.
# Updated 1.3, 2019 Feb 12, added check on lynx and curl

# By Louis van Belle
# Tested on Debian 9 amd64

# Kopano Core Communtiy Packages Downloader
# you run it, it get the lastest versions and your ready to install kopano.
# a local file repo is create, which you can use for a webserver also.
# Use at own risk, use it, change it if needed and share it.!

# Sources used:
# https://download.kopano.io/community/
# https://documentation.kopano.io/kopanocore_administrator_manual
# https://wiki.z-hub.io/display/ZP/Installation

KOPANO_COMMUNITIE_URL="https://download.kopano.io/community"
KOPANO_COMMUNITIE_PKG="core archiver deskapp files mattermost mdm meet smime webapp webmeetings"

# TODO
# make function for regular .tar.gz files like :
# kapp konnect kweb libkcoidc mattermost-plugin-kopanowebmeetings mattermost-plugin-notifymatters

# If you want z-push available also in your apt, set this to yes.
# z-push repo stages.
# After the setup, its explained in the repo filo.
ENABLE_Z_PUSH_REPO="yes"

# Please note, limited support, only Debian 9 is supported in the script.
# see deb https://download.kopano.io/community/libreofficeonline/
ENABLE_LIBREOFFICE_ONLINE="yes"

# Dont change the base once its set.
# If you do you need to change the the file:
#  /etc/apt/sources.list.d/local-file.list also.
BASE_FOLDER=/home/kopano

# A subfolder in BASE_FOLDER.
KOPANO_EXTRACT2FOLDER="apt"

# We need the lsb-release package. (space separeted).
NEEDED_PACKAGES="lsb-release curl lynx"


for NeededPackages in ${NEEDED_PACKAGES}
do
    if [ "$(dpkg -l "$NeededPackages" | grep -c 'ii')" -eq 0 ]
    then
        echo "Please wait, running apt-get update and installing lsb-release"
        apt-get update -y -q 2&>/dev/null
        apt-get install "${NeededPackages}" -y
    else
        echo "Package ${NeededPackages} was already installed."
    fi
done

#### Program
# Setup base folder.
if [ ! -d $BASE_FOLDER ]
then
    mkdir $BASE_FOLDER
    cd $BASE_FOLDER || exit
else
    cd $BASE_FOLDER || exit
fi

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

### Core start
echo "Getting Kopano for $OSDIST: $GET_OS $GET_ARCH"

for pkglist in $KOPANO_COMMUNITIE_PKG
do
    if [ "${pkglist}" = "files" ]||[ "${pkglist}" = "mdm" ]||[ "${pkglist}" = "webapp" ]
    then
        echo "Getting and extracting $pkglist to ${KOPANO_EXTRACT2FOLDER}. ( -all ) "
        curl -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITIE_URL}/${pkglist}:/" | grep "${GET_OS}-all".tar.gz)" \
        | tar -xz -C ${KOPANO_EXTRACT2FOLDER} --strip-components 1 -f -
    else
        echo "Getting and extracting $pkglist to ${KOPANO_EXTRACT2FOLDER}. ( -${GET_ARCH} ) "
        curl -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITIE_URL}/${pkglist}:/" | grep "${GET_OS}-${GET_ARCH}".tar.gz)" \
        | tar -xz -C ${KOPANO_EXTRACT2FOLDER} --strip-components 1 -f -
    fi
done

if [ ! -d $KOPANO_EXTRACT2FOLDER ]
then
    mkdir $KOPANO_EXTRACT2FOLDER
    cd $KOPANO_EXTRACT2FOLDER || exit
else
    cd $KOPANO_EXTRACT2FOLDER || exit
fi

if [ "${GET_ARCH}" = "amd64" ]; then
    if [ ! -d amd64 ]; then
        mkdir amd64
    elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
        if [ ! -d i386 ]; then
            mkdir i386
        fi
    fi
fi
# Create arch based folder.
if [ "${GET_ARCH}" = "amd64" ]; then
    mv -n ./*_amd64.deb amd64/
    mv -n ./*_all.deb amd64/
    rm ./*.deb
elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
    mv -n ./*_i386.deb i386/
    mv -n ./*_all.deb i386/
    rm ./*.deb
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
    } > /etc/apt/sources.list.d/kopano-community.list
    echo "Please wait, running apt-get update"
    apt-get update -qy 2&>/dev/null
else
    echo "Please wait, running apt-get update"
    apt-get update -qy 2&>/dev/null
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
            echo "# Documantation: https://wiki.z-hub.io/display/ZP/Installation"
            echo "# https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
            echo "# https://documentation.kopano.io/user_manual_kopanocore/configure_mobile_devices.html"
            echo "# Options to set are :"
            echo "# old-final = old-stable, final = stable, pre-final=testing, develop = experimental"
            echo "# "
            echo "deb ${SET_Z_PUSH_REPO}"
            } > /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}"
            echo "Created file : /etc/apt/sources.list.d/${SET_Z_PUSH_FILENAME}"
        fi

        # install the repo key once.
        if [ "$(apt-key list | grep -c kopano)" -eq 0 ]; then
            echo -n "Installing z-push signing key : "
            wget -qO - http://repo.z-hub.io/z-push:/final/"${GET_OS}"/Release.key | sudo apt-key add -
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
                echo "# Documantation: https://documentation.kopano.io/kopano_loo-documentseditor/"
                echo "# "
                echo "deb ${SET_OFFICE_ONLINE_REPO}"
                } > /etc/apt/sources.list.d/"${SET_OFFICE_ONLINE_FILENAME}"
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

echo "Kopano core versions available on the repo now are : "
apt-cache policy kopano-server-packages
echo " "
echo " "
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"

