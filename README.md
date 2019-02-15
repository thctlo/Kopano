# Kopano
Usefull scripts for Kopano

get-kopano-community.sh, this script pull the community files for you OS. 
Currently tested on Debian 9, should work for Debian 8/Ubuntu 16/18 .04 also. 
This eliminates the use of dpkg -i *.deb on kopano-community. 

It setups a local file repo, which is easy to adapt for webserver repo.
It also adds the z-push repo en libreoffice-online repo for you.
I've also added an autobackup function, so you can revert to a previous version if needed.

For the quick and unpatient, keep the below defaults and run :
wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | bash
apt install kopano-server-packages

And see the new versions: 
apt-cache policy kopano-server-packages kopano-webapp z-push-kopano libreoffice-online

Note, when you are upgrading and you see packages are "kept back". 
This is why. Kopano is fast moving at the moment, if new packages are added then these are not installed 
when you just run apt update, in these cases you must use apt dist-upgrade.
So make sure you always check for "kept back" packages.


