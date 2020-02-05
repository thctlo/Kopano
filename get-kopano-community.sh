#!/usr/bin/env bash

#set -euo pipefail

# Kopano Core Communtiy Packages Downloader
#
# By Louis van Belle
# Tested on Debian 9/10 amd64, should work on Ubuntu 16.04/18.04 also.
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
# Happy New Year release.
# Updated 2.0, changed path's, detections and added extra files to download.
# Updated 2.1,  2020-01-06, Fix, dont download Debian_10 dependencies on ubuntu.
# Updated 2.1.1 2020-01-06 add fixes from https://github.com/lcnittl/get_kopano-ce
#             Unable to pull it due to filename changes
# Updated 2.1.2 2020-02-05 small fix, works but more todo.
#
# Sources used:
# https://download.kopano.io/community/
# https://documentation.kopano.io/kopanocore_administrator_manual
# https://wiki.z-hub.io/display/ZP/Installation

# For the quick and unpatient, keep the below defaults and run :
# wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | bash
# Optional, when you are upgrading: apt dist-upgrade && kopano-dbadm usmp
#
# Dont change the base folder once its set!
# If you do you need to change the the file:
#  /etc/apt/sources.list.d/local-file.list also.
BASE_FOLDER="$HOME/kopano-repo"

# A subfolder in BASE_FOLDER.
KOPANO_APTFOLDER="apt"
KOPANO_DOWNL2FOLDER="downloads"

# Autobackup the previous version.
# A backup will be made of the apt/$ARCH folder to backukp/
# The backup path is relative to the BASE_FOLDER.
ENABLE_AUTO_BACKUP="yes"

# The Kopano Community link.
KOPANO_COMMUNITY_URL="https://download.kopano.io/community"
# The packages you can pull and put directly in to the repo.
KOPANO_COMMUNITY_PKG="core archiver files mdm smime webapp"
# dependencies"

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
# TODO functionize the script.

check_run_as_sudo_root () {
    if ! [[ $EUID -eq 0 ]]; then
        error "This script should be run using sudo or by root."
        exit 1
    fi
}

check_run_as_sudo_root

# dependencies for this script:
NEEDED_PROGRAMS="lsb_release apt-ftparchive curl gnupg2 lynx sudo tee"
# the above packages can be installed with executing `apt install apt-transport-https lsb-release apt-utils curl gnupg2 lynx sudo`
# Note gnupg2 is using the command gpg2.

#### Program
for var in $NEEDED_PROGRAMS; do
    # fix for 1.5.1.
    if var="gnupg2"; then var=gpg2; fi
    if ! command -v "$var" &> /dev/null; then
        echo "$var is missing. Please install it and rerun the script."
        exit 1
    fi
done

# Setup base folder en enter it.
if [ ! -d "$BASE_FOLDER" ]
then
    mkdir -p "$BASE_FOLDER"
fi

# set needed variables
OSNAME="$(lsb_release -si)"
OSDIST="$(lsb_release -sc)"
OSDISTVER="$(lsb_release -sr)"
OSDISTVER0="$(lsb_release -sr|cut -c1).0"

# check OS/version
if [ "${OSNAME}" = "Debian" ]
then
    if [ "${OSDISTVER}" -eq 10 ]
    then
        GET_OS="${OSNAME}_${OSDISTVER}"
    else
        # Needed for Kopano Community ( used Debian_9.0 )
        GET_OS="${OSNAME}_${OSDISTVER0}"
    fi
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
    if [ ! -d ${BASE_FOLDER}/backups ]
    then
        mkdir -p ${BASE_FOLDER}/backups
    fi
    if [ -d "${KOPANO_APTFOLDER}/${GET_ARCH}" ]
    then
        echo "Moving previous version to : backups/${OSDIST}-${GET_ARCH}-$(date +%F)"
        # we move the previous version.
        mv "${KOPANO_APTFOLDER}/${GET_ARCH}" ${BASE_FOLDER}/backups/"${OSDIST}-${GET_ARCH}-$(date +%F)"
    fi
fi

# Change to the base folders where we put everything.
cd "$BASE_FOLDER"

### Core start
echo "Getting Kopano for $OSDIST: $GET_OS $GET_ARCH"

# Create extract to folders, which is you apt files location.
if [ ! -d $KOPANO_APTFOLDER ]
then
    mkdir -p $KOPANO_APTFOLDER
fi
# Create download folder
if [ ! -d $KOPANO_DOWNL2FOLDER ]
then
    mkdir -p $KOPANO_DOWNL2FOLDER
fi

# get packages and extract them in KOPANO_APTFOLDER
echo "Downloading .tar.gz files to $BASE_FOLDER/$KOPANO_DOWNL2FOLDER"
for pkglist in $KOPANO_COMMUNITY_PKG
do
    if [ "${pkglist}" = "dependencies" ]
    then
        if [ "${GET_OS}" = "Debian_10" ]
        then
            if [ ! -f ${KOPANO_DOWNL2FOLDER}/${pkglist}-${GET_OS}-$(date +%F).tar.gz ]
            then
                echo "Downloading files to ${KOPANO_DOWNL2FOLDER} folder : $pkglist ( OS related dependencies ) "
                curl -o ${KOPANO_DOWNL2FOLDER}/${pkglist}-${GET_OS}-$(date +%F).tar.gz -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITY_URL}/${pkglist}:/" | grep "${GET_OS}"| grep tar.gz)"
            else
                echo "Already downloaded : ${pkglist}-${GET_OS}, skipping"
            fi
        else
            echo "Not downloading dependencies, only needed for Debian_10."
            echo "Things might change by Kopano, if needed verify with this link:"
            echo "https://download.kopano.io/community/dependencies:/"
        fi
    fi

    # packages listed here must be maintained manualy.. ( the -all versions )
    if [ "${pkglist}" = "mdm" ]||[ "${pkglist}" = "webapp" ]||[ "${pkglist}" = "files" ]
    then
        if [ ! -f ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz ]
        then
            echo "Downloading files to ${KOPANO_DOWNL2FOLDER} folder : $pkglist ( -all ) "
            curl -o ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITY_URL}/${pkglist}:/" | grep "${GET_OS}"| grep all.tar.gz)"

        else
            echo "Already downloaded : ${pkglist}, skipping"
        fi
    else
        # Arch specific packages.
        if [ ! -f ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz ]
        then
            echo "Getting and extracting : $pkglist ( -${GET_ARCH} ) "
            echo "Downloading files to ${KOPANO_DOWNL2FOLDER} folder : $pkglist  ( -${GET_ARCH} )"
            curl -o ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz -q -L "$(lynx -listonly -nonumbers -dump "${KOPANO_COMMUNITY_URL}/${pkglist}:/" | grep "${GET_OS}" |grep "${GET_ARCH}".tar.gz)"
        else
            echo "Already downloaded : ${pkglist}, skipping"
        fi
    fi
done

if [ ! -d tmp-extract ]
then
    mkdir tmp-extract
fi

for pkglist in $KOPANO_COMMUNITY_PKG
do
#    # packages listed here must be maintained manualy.. ( the -all versions )
    if [ "${pkglist}" = "dependencies" ]
    then
        echo "Extracting (strip1) ${pkglist} to tmp-extract folder, please wait"
        tar -xz -C tmp-extract --strip-components 2 -f ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz
    else
        echo "Extracting (strip2) ${pkglist} to tmp-extract folder, please wait"
        tar -xz -C tmp-extract --strip-components 1 -f ${KOPANO_DOWNL2FOLDER}/${pkglist}-$(date +%F).tar.gz
    fi
done

# Create arch based folder.
if [ "${GET_ARCH}" = "amd64" ]; then
    if [ ! -d "$BASE_FOLDER/$KOPANO_APTFOLDER"/amd64 ]; then
        mkdir "$BASE_FOLDER/$KOPANO_APTFOLDER"/amd64
    elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
        if [ ! -d "$BASE_FOLDER/$KOPANO_APTFOLDER"/i386 ]; then
            mkdir "$BASE_FOLDER/$KOPANO_APTFOLDER"/i386
        fi
    fi
fi

# Move files and cleanup temp folder.
cd "$BASE_FOLDER/tmp-extract"
if [ "${GET_ARCH}" = "amd64" ]; then
    mv -n ./*_amd64.deb "$BASE_FOLDER/$KOPANO_APTFOLDER"/amd64/ || true
    mv -n ./*_all.deb "$BASE_FOLDER/$KOPANO_APTFOLDER"/amd64/ || true
    # remove left overs
    rm -f ./*.deb
    rm ./${GET_OS}/Packages
    rm ./${GET_OS}/Packages.gz
    rm ./${GET_OS}/Release
    rm ./${GET_OS}/Release.gpg
    rm ./${GET_OS}/Release.key
    rm ./amd64/*.deb
    rmdir amd64

elif [ "${GET_ARCH}" == "i386" ] || [ "${GET_ARCH}" == "i686" ]; then
    mv -n ./*_i386.deb "$BASE_FOLDER/$KOPANO_APTFOLDER"/i386/ || true
    mv -n ./*_all.deb "$BASE_FOLDER/$KOPANO_APTFOLDER"/i386/ || true
    # remove left overs
    rm -f  ./*.deb
    rm ./${GET_OS}/Packages
    rm ./${GET_OS}/Packages.gz
    rm ./${GET_OS}/Release
    rm ./${GET_OS}/Release.gpg
    rm ./${GET_OS}/Release.key
    rm ./i386/*.deb
    rmdir i386
fi

# Enter the APT folder and Create the Arch Depended Packages file so apt knows what to get.
cd "$BASE_FOLDER/$KOPANO_APTFOLDER/"
echo "Please wait, generating ${GET_ARCH}/Packages File"
apt-ftparchive packages "${GET_ARCH}"/ > "${GET_ARCH}"/Packages

if [ ! -e /etc/apt/sources.list.d/kopano-community.list ]
then
    {
    echo "# File setup for Kopano Community."
    echo "deb [trusted=yes] file:${BASE_FOLDER}/${KOPANO_APTFOLDER}/ ${GET_ARCH}/"
    echo "# Webserver setup for Kopano Community."
    echo "#deb [trusted=yes] http://localhost/apt ${GET_ARCH}/"
    echo "# to enable the webserver, install a webserver ( apache/nginx )"
    echo "# and symlink ${BASE_FOLDER}/${KOPANO_APTFOLDER}/ to /var/www/html/${KOPANO_APTFOLDER}"
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
            curl -q -L http://repo.z-hub.io/z-push:/final/"${GET_OS}"/Release.key | sudo apt-key add -
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
sudo apt-get update -qqy

echo "Kopano core versions available on the repo now are: "
apt-cache policy kopano-server
echo " "
echo " "
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"
echo
echo "NOTE!"
echo "You need to manually cleanup the Backups folder and Download folder"
echo "I keep it because if you need/want and older version, now its available for you"
echo

