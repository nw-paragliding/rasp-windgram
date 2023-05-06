This document describes installation of WXTOFLY RASP site and scripts
feeding content to [http://wxtofly.net](http://wxtofly.net/) website

# Hardware

This is recommended minimum setup

-   CPU Intel i7

-   HDD 100GB min

-   8GB RAM

Current Jiri\'s installation is running in a Hyper-V virtual machine
with:

-   4 virtual CPUs

-   8GB RAM

-   128GB VHD

Jiri\'s host machine:

-   Intel i7 6700k

-   SSD 1TB

-   HDD 2TB

-   32GB RAM

-   NVIDIA GPU

Note: Current version of Hyper-V Integration Services for Linux do not
support access to GPU via RemoteFX feature. It might be possible using
pass-through PCI setup

# OS

Currently the installation scripts support only 64-bit Ubuntu and were
tested on Desktop version 14.04 and 16.10 and Server version 16.10.
Adding support for other distributions should be possible.

# Installation instructions

-   Select a version of Ubuntu and download the setup ISO
    from <https://www.ubuntu.com/download>. Direct links to images used
    for testing:

    -   [ubuntu-16.10-desktop-amd64.iso](http://mirror.pnl.gov/releases/16.10/ubuntu-16.10-desktop-amd64.iso)

    -   [ubuntu-14.04.5-desktop-amd64.iso](http://mirror.pnl.gov/releases/14.04/ubuntu-14.04.5-desktop-amd64.iso)

    -   [ubuntu-16.10-server-amd64.iso](http://mirror.pnl.gov/releases/16.10/ubuntu-16.10-server-amd64.iso)

-   Install the OS on a physical or virtual machine

-   After installation, login using credentials created during OS
    install. This must be the administrator user.

-   Decide on BASEDIR directory name for the RASP site installation and
    create it under the home directory, eg. myrasp \
    mkdir \~/myrasp

-   Download installation package
    from <http://wxtofly.net/install/wxtofly.tgz> and save it in the
    BASEDIR directory \
    curl --o \~/myrasp/wxtofly.tgz
    http://wxtofly.net/install/wxtofly.tgz

-   Change directory to BASEDIR and extract files from instalation
    package \
    cd \~/myrasp \
    tar xvzf wxtofly.tgz

-   Run installation script providing path to BASEDIR as the only
    argument \
    bash INSTALL/install_wxtofly.sh \~/myrasp

-   The installation script goes through multiple steps. Installation of
    dependent packages requires running as administrator. When prompted
    enter the password of the currently logged in user.

-   When the installation completes successfully the script will
    proceeds to set up the site:

    -   CRON -- if selected this will create a cron job to run the RASP
        site.

    -   Uploading to wxtofly.net - if selected the script will asks for
        ftp access credentials and configures the site to upload run
        output plots to the website.

See WxToFly guide document for details about the site operation

# References

-   DrJack RASP installation instructions: \
    <http://www.drjack.info/twiki/bin/view/RASPop/ProgramOverview>

-   RASP support forums: \
    <http://www.drjack.info/cgi-bin/rasp-forum.cgi>

-   TJ Olney RASP installation instructions: \
    <http://wxtofly.net/rasp_scripts/index.html>
