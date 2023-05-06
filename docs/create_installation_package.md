# Creating Installation Package

## Dev Folder

The current dev folder is **d:\\wxtofly\\tj_setup**. d:\\wxtofly is
shared on host Windows machine as **wxtofly**.

## Creating package

-   Open Terminal window

-   Create local folder:

	`mkdir \~/wxtofly`

-   Install cifs-utils:

	`sudo apt-get install cifs-utils`

-   Create a mount point folder:

	`mkdir \~/share_wxtofly`

-   Mount Windows share:

	`sudo mount -t cifs //\[HOST_IP\]/wxtofly \~/share_wxtofly -o vers=2.0,user=jiri`

-   Copy all files from the share to a new folder:

	`rsync -rvu \--delete \~/share_wxtofly/tj_setup/ \~/wxtofly`

-   Create installation package:

	`bash \~/wxtofly/create_install_tar.sh`

	This creates **\~/wxtofly/wxtofly.tgz** which can be uploaded to wxtofly.net
