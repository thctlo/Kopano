#!/usr/bin/env bash

set -euo pipefail

# Kopano Core Communtiy Packages Downloader V3.
# *(Please do note, these are development packages, use with care.)
#
# By Louis van Belle
# Tested on Debian 10 amd64, should work on Ubuntu ?? please test and report back.
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
# Updated 2.1.1 2020-01-06, add fixes from https://github.com/lcnittl/get_kopano-ce
#             Unable to pull it due to filename changes
# Updated 2.1.2 2020-02-05, small fix, works but more todo.
# Updated 2.1.3 2020-02-11, fix failed fix for 1.5.1. (thank Felix Bartels @Kopano for reporting)
# Version 3.0.0 2021-06-15, rework of complete script. code verified with : shellcheck 0.5.0-3
# Version 3.0.1 2021-06-16, small fixes on the creating/moving/deleting repo folder, change outputs a bit.
# Version 3.0.2 2021-08-21, fix corrupted kopano-community.list @Thanks @Marco for the git pull
# Version 3.0.3 2021-08-23, fix failed command detection, fixed unneeded artifact "}" in the sources.list file.
# Version 3.0.4 2021-08-23, Added part for dependencies, needs manual input of the download link. (for now). 
# Version 3.0.5 2021-08-23, The "Stupidity release.. fixed, incorrect OS detected, it was always Debian_10. 
# Version 3.0.6 2021-08-23, Made function of dependencies, needed when building from source. 
# Version 3.0.7 2021-08-30, Added support for Debian 11 Bullseye, ITS NOT IN KOPANO YET !! only enabled it in script.
# Version 3.0.8 2022-02-09, Debian 11 Bullseye, still not in Kopano, added part to exit script.

#
# Original sources used, my previous file and :
# https://github.com/zokradonh/kopano-docker/master/base/create-kopano-repo.sh
# A fantastic script from Zokradonh for the docker setup, just i dont use docker. ;-)

# Other sources used:
# https://download.kopano.io/community/
# https://documentation.kopano.io/kopanocore_administrator_manual

# For the quick and unpatient, keep the below defaults and run :
# wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | bash
# Optional, when you are upgrading: apt dist-upgrade && kopano-dbadm usmp

##### Variables you must set. #######
#####################################
# Don't change the base folder once it's set! (after you run the script once) !!!
# If you do you need to change the file:
#  /etc/apt/sources.list.d/kopano-community.list also.
# Defaults to /srv/repo/kopano"  ( if unsure, leave as is.)
# Packages will go in : /srv/repo/kopano/amd64 for example.
# $HOME/kopano is another good option.
BASE_FOLDER=""
# ! If you use a home folder for BASE_FOLDER, you probably want to run
# the script as user also. Set below to something else then "no"
DISABLE_RUN_AS_ROOT="no"

# The Kopano packages you can pull and put directly into the repo.
# Pre-selected the most used packages.
KOPANO_COMMUNITY_PKG="core archiver files mdm smime webapp migration-pst"
# Optional, you can add (is tested): deskapp kapps mattermost meet webmeetings
# (Note, webmeeting is marked predicated)

# If you want z-push available also in your apt, set this to yes.
# Z-push repo stages, final, od/pre-final, development
# See also : https://kb.kopano.io/display/ZP/Installation
# After the setup, it's explained in the repo filo.
REPO_ENABLE_Z_PUSH="yes"

# Autobackup the previous version.
# A backup will be made of the REPO_BASE_FOLDER/$GET_ARCH folder to
# REPO_BASE_FOLDER/$GET_ARCH-DATEYYYY-MM-DD
#ENABLE_AUTO_BACKUP="yes"
## TODO.. Need better one..

## DEBUGGING
# Enable (true) if you have problems
DEBUG=false
#DEBUG=true

if [ "$DEBUG" = true ]
then
    set -x
fi

RUN_DATE="$(date +%F)"
# set needed variables
OSNAME="$(lsb_release -si)"
OSDIST="$(lsb_release -sc)"
OSDISTVER="$(lsb_release -sr)"
OSDISTVER0="$(lsb_release -sr|cut -c1).0"

if [ "${OSDIST}" = "bullseye" ]
then
    echo "Sorry, this script can handle bullseye but its not yet release by Kopano, exiting now.. "
    echo "When you see its released and these lines are still here, remove them and run it again and ping me on github ;-) thanks! "
    exit 0
fi

# check OS/version
if [ "${OSNAME}" = "Debian" ]
then
    GET_ARCH="$(dpkg --print-architecture)"
    if [ "${OSDISTVER}" -ge 10 ]
    then
        GET_OS="${OSNAME}_${OSDISTVER}"
    else
        # Needed for Kopano Community ( used Debian_9.0 )
        GET_OS="${OSNAME}_${OSDISTVER0}"
    fi
elif [ "${OSNAME}" = "Ubuntu" ]
then
    # For ubuntu results in Ubuntu_20.04
    GET_OS="${OSNAME}_${OSDISTVER}"
    GET_ARCH="$(dpkg --print-architecture)"
fi

## Code Functions
function check_run_as_sudo_root {
if ! [[ $EUID -eq 0 ]]
then
    echo "This script should be run using sudo or by root."
    exit 1
fi
}
if [ "${DISABLE_RUN_AS_ROOT}" = "no" ]
then
    check_run_as_sudo_root
fi

echo "Script is running on : $OSNAME $OSDIST"

# Default Repo location for kopano
REPO_BASE_FOLDER="${BASE_FOLDER:-/srv/repo/kopano}"

function check_package_or_commands_are_installed {
# check if needed packages are installed.
NEEDED_PGK="curl jq apt-ftparchive gnupg"
for check_pkg in $NEEDED_PGK
do
    if [ -z "$(command -v $check_pkg)" ]
    then
        if [ "$check_pkg" = "apt-ftparchive" ]
        then
            echo "apt-ftparchive is coming from apt-utils, installing now.."
            apt-get -q=2 install apt-utils > /dev/null
        else
            echo -n "Script is missing a needed program/package: $check_pkg, installing now : "
            apt-get -q=2 install "$check_pkg" > /dev/null
        fi
    else
        echo "$check_pkg found"
    fi
done
}

# Zokradonh his functions to get the files
function urldecode { : "${*//+/ }"; echo -e "${_//%/\\x}"; }
function version_from_filename { basename "$1" | awk -F"-" '{print $2}'; }
function h5ai_query {
    component=${1:-core}
    distribution="${GET_OS}"
    channel=${3:-community} # could either be community, supported or limited
    branch=${4:-""} # could either be empty, "master/tarballs/", "pre-final/tarballs/" or "final/tarballs/"

    filename=$(curl -s -XPOST "https://download.kopano.io/$channel/?action=get&items\\[href\\]=/$channel/$component:/$branch&items\\[what\\]=1" | \
            jq -r '.items[].href' | \
            grep "$distribution-all\\|$distribution-amd64" | sed "s#/$channel/$component:/##" | sed "s#/$channel/$component%3A/##" )

    if [ -z "${filename// }" ]; then
        echo "unknown component"
        exit 1
    fi

    filename=$(urldecode "$filename")
    echo "$filename"
}

function before_dl_and_extract_doBackup {
    echo "Detected variable REPO_BASE_FOLDER/GET_ARCH : $REPO_BASE_FOLDER/$GET_ARCH/"
    if [ -d "$REPO_BASE_FOLDER/$GET_ARCH/" ]
    then
        if [ ! -d "$REPO_BASE_FOLDER/$GET_ARCH-$RUN_DATE" ]
        then
            echo "Moving older version to $REPO_BASE_FOLDER/$GET_ARCH-$RUN_DATE"
            mv "$REPO_BASE_FOLDER/$GET_ARCH" "$REPO_BASE_FOLDER/$GET_ARCH-$RUN_DATE"
            mkdir -p "$REPO_BASE_FOLDER/$GET_ARCH/"
        else
            echo "We already moved an older version to $REPO_BASE_FOLDER/$GET_ARCH-$RUN_DATE"
            if [ ! -d "$REPO_BASE_FOLDER/$GET_ARCH/" ]
            then
                mkdir -p "$REPO_BASE_FOLDER/$GET_ARCH/"
            fi
        fi
    else
        echo "NOT Detected : $REPO_BASE_FOLDER/$GET_ARCH/ creating folder now."
        mkdir -p "$REPO_BASE_FOLDER/$GET_ARCH/"
    fi
}

function dl_and_package_kopano_community {
    # Take component as first argument and fallback to core if none given
    component=${1:-core}
    distribution="${GET_OS}"
    channel=${3:-community}
    branch=${4:-""}

    if [ -d "$component" ]; then
        echo "Packages have been downloaded in a previous stage. Skipping..."
        return
    fi

    # Query community server by h5ai API
    filename=$(h5ai_query "$component" "$distribution" "$channel" "$branch")
    filename2=$(basename "$filename")

    # Download & extract packages
    curl -s -S -L -o "$filename2" https://download.kopano.io/"$channel"/"$component":/"${filename}"
    tar -zxf "$filename2" -C "$REPO_BASE_FOLDER/$GET_ARCH/" --strip-components 1

    # Save disk space.
    # Todo add option to keep these,add time stamps so we dont need to re-download if needed.

    # Some leftovers to cleanup
    rm "$filename2"

}

### Z-PUSH start
function repo_enable_ZPush {
if [ "${REPO_ENABLE_Z_PUSH}" = "yes" ]
    then

    SET_Z_PUSH_REPO="https://download.kopano.io/zhub/z-push:/final/${GET_OS}"
    SET_Z_PUSH_FILENAME="kopano-z-push.list"
    echo "Checking for Z_PUSH Repo on ${OSNAME}."

    # install the repo key once.
    if [ "$(apt-key list | grep -c kopano)" -eq 0 ]; then
        echo -n "Installing z-push signing key."
        curl -q -L "${SET_Z_PUSH_REPO}"/Release.key | apt-key add -
    else
        echo "The Kopano Z_PUSH repo key was already installed."
    fi

    if [ ! -e /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ]; then
        if [ ! -f /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" ]; then
            {
            echo "# "
            echo "# Kopano z-push repo"
            echo "# Documentation: https://kb.kopano.io/display/ZP/Installation"
            echo "# https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
            echo "# https://documentation.kopano.io/user_manual_kopanocore/configure_mobile_devices.html"
            echo "# Options to set are :"
            echo "# old-final = old-stable, final = stable, pre-final=testing, develop = experimental"
            echo "# "
            echo "deb ${SET_Z_PUSH_REPO} /"
            } | tee /etc/apt/sources.list.d/"${SET_Z_PUSH_FILENAME}" > /dev/null
            echo "Created file : /etc/apt/sources.list.d/${SET_Z_PUSH_FILENAME}"
        fi

    else
        echo "The Kopano Z_PUSH repo was already setup."
        echo ""
    fi
    echo "The z-push info : https://documentation.kopano.io/kopanocore_administrator_manual/configure_kc_components.html#configure-z-push-activesync-for-mobile-devices"
    echo "Before you configure/install also read : https://kb.kopano.io/display/ZP/Installation"
    echo ""
fi
### Z_PUSH End
}

function generate_kopano_Packages_for_repo {
    if [ ! -e /etc/apt/sources.list.d/kopano-community.list ]
    then
        cat > /etc/apt/sources.list.d/kopano-community.list << _EOF
# File setup for Kopano Community.
deb [trusted=yes] file:$REPO_BASE_FOLDER $GET_ARCH/
# Webserver setup for Kopano Community.
#deb [trusted=yes] http://localhost/kopano/ $GET_ARCH/
# to enable the webserver, install a webserver ( apache/nginx )
# and symlink $REPO_BASE_FOLDER/ to /var/www/html/kopano
# example : ln -s /srv/repo/kopano /var/www/html/kopano
_EOF

    echo " "
    echo "The installed Kopano apt-list file: /etc/apt/sources.list.d/kopano-community.list"
    echo " "
else
        echo "The Kopano apt-list file: /etc/apt/sources.list.d/kopano-community.list already exists."
fi

    cd "$REPO_BASE_FOLDER" || exit 1
    echo "Generating packages file : ${GET_ARCH}/Packages"
    apt-ftparchive packages "${GET_ARCH}"/ > "${GET_ARCH}"/Packages
    echo -n "Running apt update, please wait: "
    apt-get update -q=2
    echo "Done"
}

function cleanup {
    rm -rf "$WORK_DIR"
    echo "Deleted temp working directory $WORK_DIR"
}

### Program Code start here ###
# Safe Old Internal Field Separator values.
SAVEIFS=$IFS

WORK_DIR="$(mktemp -d)"
cd "$WORK_DIR"

# Make sure all needed packages for the program are installed.
check_package_or_commands_are_installed

# Get the files and backup previous versions
before_dl_and_extract_doBackup

for get_kopano_component in $KOPANO_COMMUNITY_PKG
do
    # New Internal Field Separator is set.
    IFS=$'\n\t'
    echo -n "Please wait, getting kopano components : $get_kopano_component : "
    dl_and_package_kopano_community "$get_kopano_component"
    echo "Done"
    # Restore Old Internal Field Separator values.
    IFS=$SAVEIFS
done
function missingBuildDepends(){
# Get missing dependecies
# https://download.kopano.io/community/dependencies%3A/ 
# Needs manual input for now. 
if [ "${OSNAME}" = "Debian" ]
then

    if [ "${OSDISTVER}" -eq 10 ]
    then
        echo
        echo "######################################################################"
        echo "Detected a ${OSNAME}_${OSDISTVER}  installation, we need to add extra dependencies."
        echo "Please go here with a browser : "
        echo " https://download.kopano.io/community/dependencies%3A/ "
        echo "Now sort on \"Last modified\" and get the latest version for your OS."
        read -r -p "Copy the link address to the file and post it here : " DEPENDS_URL
        DEPENDS_FILENAME="$(echo $DEPENDS_URL|awk -F"/" '{ print $6 }')"
        curl -s -S -L -o "$DEPENDS_FILENAME" $DEPENDS_URL
        tar -zxf "$DEPENDS_FILENAME" -C "$REPO_BASE_FOLDER/$GET_ARCH/" --strip-components 1
        unset DEPENDS_URL
    fi
elif [ "${OSNAME}" = "Ubuntu" ]
then
    # For ubuntu results in Ubuntu_20.04
    GET_OS="${OSNAME}_${OSDISTVER}"
    if [ "${GET_OS}" = "Ubuntu_20.04" ]
    then
        echo
        echo "######################################################################"
        echo "Detected a ${GET_OS} installation, we need to add extra dependencies."
        echo "Please go here with a browser : "
        echo " https://download.kopano.io/community/dependencies%3A/ "
        echo "Now sort on \"Last modified\" and get the latest version for your OS."
        read -r -p "Copy the link address to the file and post it here : " DEPENDS_URL
        DEPENDS_FILENAME="$(echo $DEPENDS_URL|awk -F"/" '{ print $6 }')"
        curl -s -S -L -o "$DEPENDS_FILENAME" $DEPENDS_URL
        tar -zxf "$DEPENDS_FILENAME" -C "$REPO_BASE_FOLDER/$GET_ARCH/" --strip-components 2
        unset DEPENDS_URL
    fi
fi
}

# Get Z-Push
repo_enable_ZPush

# Cleanup workdir
rm -rf  "$WORK_DIR"

# Remove some leftovers
rm  "$REPO_BASE_FOLDER/${GET_ARCH}/$distribution/"*
rmdir "$REPO_BASE_FOLDER/${GET_ARCH}/$distribution"

# Create the Packages index for the repo
generate_kopano_Packages_for_repo

apt-cache policy kopano-server
echo " "
echo " "
echo "The AD DC extension can be found here: https://download.kopano.io/community/adextension:/"
echo "The Outlook extension : https://download.kopano.io/community/olextension:/"
echo "Install the complete kopano stack at once with : apt install kopano-server-packages"
echo "The script got the following packages ready for install for you: "
echo "$KOPANO_COMMUNITY_PKG z-push"
echo ""
echo "When you are upgrading: apt dist-upgrade && kopano-dbadm usmp"
