# Kopano
Scripts for Kopano.

`get-kopano-community.sh`: This script pull the community files for your OS and setup a repo so you can use apt-get to install.

Currently tested on Debian 10 but should work for Debian 8-9 and Ubuntu 16/18 .04 (LTS editions) also.
This eliminates the use of `dpkg -i *.deb on kopano-community files.`

It setups a local file repo, which is easy to adapt for a webserver repo, examples are provided in the files.
It also adds the z-push repo and libreoffice-online repo for you.
I've also added an autobackup function, so you can revert to a previous version if needed.

For the quick and unpatient, keep the defaults and run:
```
wget -O - https://raw.githubusercontent.com/thctlo/Kopano/master/get-kopano-community.sh | bash
apt install kopano-server-packages
```

And too see the new versions, you can use the following command:
```
apt-cache policy kopano-server-packages kopano-webapp z-push-kopano libreoffice-online
```

Note, when you are upgrading and you might see packages are "kept back".
This is why:
Kopano is fast moving at the moment, if new packages are added then these are not installed,
when you just run apt update, in these cases you must use `apt dist-upgrade`.
So make sure you always check for "kept back" packages.
But there are also packages which might not be removed when upgrading and to make this all work, you might want to at these 
options --autoremove --purge, so you can run : `apt dist-upgrade --autoremove --purge`
This removed obsolete files and installes the kept back packages in one go.

The script and the default settings in it, will do following for you:
- create a folder `/home/kopano` , you can adjust the path in the script if you like.
  ! Do note, if you change it after you have run it, you need to adjust the /etc/apt/sources.list.d/*.list files also.
- create a subfolder `apt`, this is the folder where the "$ARCH"/*.deb files will be placed.
- create a subfolder `tmp-extract`, this is used to download the tar.gz file and exact it in there.
  This is done due to different depts of subfolders in the tar.gz files, which made extacting and placing bit harder.
  So we dump all in a temp folder and move it when ready to $ARCH.
- create a subfolder `backups`, when you run the script, the folder apt/$ARCH is moved to backups.
  If the kopano packages had a bad release, you can revert back to a previous version.
- pulls the files from the Kopano community site.
- makes a backup of the previous version to `/home/kopano/backups/OS-ARCH-Date`
- cleanup leftovers in `apt` and `tmp-extract`.
- add z-push repo ( `/etc/apt/sources.list.d/kopano-z-push.list` )
- add libreoffice repo  ( `/etc/apt/sources.list.d/kopano-libreoffice-online.list` )
- setup the local-file repo ( `/etc/apt/sources.list.d/kopano-community.list` )
the repo example file:
  - File setup for Kopano Community: `deb [trusted=yes] file:/home/kopano/apt/ amd64/`
  - Webserver setup for Kopano Community: `deb [trusted=yes] http://localhost/apt amd64/`
  To enable the webserver, install a webserver ( apache/nginx )
  Now symlink `/home/kopano/apt/` to `/var/www/html/apt`
  And dont forget to change localhost to you hostname of ip of you server.


## Donations
If you like my work, support me a bit, even with 1 $ you are helping me.
I dont ask for hunderds, a (few) buck(s) is/are a great gift also.
- [Donate via Paypal](https://www.paypal.me/LouisVanBelle) (my paypal email is louis at van-belle .nl)
- Donate via Bitcoin: 3BMEXFUrncjVKByryNU1fcVLBLKE8i9TpX

## Thanks
