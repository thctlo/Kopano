# Kopano
Scripts for Kopano.

`get-kopano-community.sh`: This script pull the community files for your OS and setup a repo so you can use apt-get to install.

It's currently tested on Debian 10 and Ubuntu 20.04 but should work for Debian 8-9 and Ubuntu 16/18/20 .04 (LTS editions) also.<br>
This eliminates the use of `dpkg -i *.deb on kopano-community files.`

It sets up a local file repo, which is easy to adapt for a webserver repo, examples are provided in the files.<br>
Do note, verify if you happy with the default script settings.<br>

For the quick and unpatient, keep the defaults and run:<br>
```
wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | sudo bash
sudo apt install kopano-server-packages
```

And too see the new versions, you can use the following command:
```
apt-cache policy kopano-server-packages kopano-webapp z-push-kopano
```

Note, when you are upgrading and you might see packages are "kept back" and this is why.<br>
<br>
Kopano is fast moving at the moment, sometimes new packages are added or older removed,<br>
when you just run apt update, in these cases you must use `apt dist-upgrade --autoremove`.<br>
So make sure you always check for "kept back" packages.<br>
The `--autoremove` is very handy with the upgrades, for example.<br>
libgsoap-kopano-x.y.z. this one of often upgraded but the older version is not autoremoved.<br>
which results in possible, strange things within Kopano, autoremove removed the older version<br>
while upgradeing.<br>

<br>
But there are also packages which might not be removed when upgrading and to make this all work,<br>
you might want to at these options --autoremove --purge, so you can run : `apt dist-upgrade --autoremove --purge`<br>
This removed obsolete files and installes the kept back packages in one go.<br>

The script and the default settings in it, will do following for you:<br>
- create a folder `$BASE_FOLDER` defaults to : /srv/repo/kopano, you can adjust the path in the script if you like.<br>
  ! Do note, if you change it after you have run it, you need to adjust the /etc/apt/sources.list.d/kopano-community.list file also.<br>
- create a subfolder `amd64/i386`, this is the folder where the "$ARCH"/*.deb files will be placed.<br>
- pulls the files from the Kopano community site. <br>
  i've set as default : KOPANO_COMMUNITY_PKG="core archiver files mdm smime webapp migration-pst"  <br>
- makes a backup of the previous version to `$REPO_BASE/repo/kopano/ARCH-Date`<br>
- cleanup leftovers.<br>
- add z-push repo ( `/etc/apt/sources.list.d/kopano-z-push.list` )<br>
- setup the local-file repo ( `/etc/apt/sources.list.d/kopano-community.list` )<br>
the repo example file:<br>
  - File setup for Kopano Community: `deb [trusted=yes] file:/$BASE_FOLDER/kopano/ amd64/`<br>
  - Webserver setup for Kopano Community: `deb [trusted=yes] http://localhost/kopano/ amd64/`<br>
  To enable the webserver, install a webserver ( apache/nginx )<br>
  Now symlink `/$BASE_FOLDER/kopano/` to `/var/www/html/kopano`<br>
  And dont forget to change localhost to you hostname of ip of you server.<br>


## Donations
If you like my work, support me a bit, even with 1 $ you are helping me.<br>
I dont ask for hunderds, a (few) buck(s) is/are a great gift also.<br>
- [Donate via Paypal](https://www.paypal.me/LouisVanBelle) (my paypal email is louis at van-belle .nl)<br>
- Donate via Bitcoin: 3BMEXFUrncjVKByryNU1fcVLBLKE8i9TpX<br>

## Thanks
@Christian Knittl-Frank for fixes so far. (https://github.com/lcnittl)<br>
@fbartels (@Kopano) for helping out. (https://github.com/fbartels)<br>
