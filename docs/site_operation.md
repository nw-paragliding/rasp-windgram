# Installation

See **WxToFly Installation** document. The installation root is
referenced as **\$BASEDIR**.

# Site environment settings

\$BASEDIR\\WXTOFLY\\wxtofly.env

# Run Configuration

Jobs for a machine are defined in \$BASEDIR\\WXTOFLY\\CONFIG\\run.conf

\# Defines run jobs

\#

\# TIGER, FRASER, FT_EBEY are nested regions

\# and must be below PNW

\#

\# Template for current day (UTC) runs

\# 00z

\####################

0z-PNW

0z-PNW-WINDOW

0z-TIGER-WINDOW

0z-FRASER-WINDOW

0z-FT_EBEY-WINDOW

0z-PNWRAT

\# 06z

\####################

6z-PNW

6z-PNW-WINDOW

6z-TIGER-WINDOW

6z-FRASER-WINDOW

6z-PNWRAT

\# 12z

\####################

12z-PNW

12z-PNW-WINDOW

12z-TIGER-WINDOW

12z-FRASER-WINDOW

12z-PNWRAT

\# 18z

\####################

18z-PNW

18z-PNW-WINDOW

18z-TIGER-WINDOW

18z-FRASER-WINDOW

18z-PNW+1

18z-PNW+1-WINDOW

18z-TIGER+1-WINDOW

# Machine registration

## Machine status monitoring

Status of registered machines is displayed on
<http://wxtofly.net/v2/status.html>

To add or remove a machine from status page:

-   Add new or delete entry to \[webroot\]\\status\\machines.json

> \[
>
> {
>
> \"hostname\":\"wxtofly16\",
>
> \"operator\":\"jiri\",
>
> \"registered\":\"3/4/2017\"
>
> },
>
> {
>
> \"hostname\":\"jiri-u14d64\",
>
> \"operator\":\"jiri\",
>
> \"registered\":\"2/15/2017\"
>
> },
>
> {
>
> \"hostname\":\"wxtofly1\",
>
> \"operator\":\"jiri\",
>
> \"registered\":\"3/2/2018\",
>
> \"description\":\"Ubuntu Server 16.04 LTS\"
>
> },
>
> {
>
> \"hostname\":\"wxtofly2\",
>
> \"operator\":\"jiri\",
>
> \"registered\":\"3/2/2018\",
>
> \"description\":\"Ubuntu Server 16.04 LTS\"
>
> }
>
> \]

-   Upload to wxtofly.net

-   Create a folder with the name of the machine on web server under
    /wxtofly.net/status. It must be the same name as given by
    **hostname** command.

# Run task scheduling

Cron service is used for task scheduling

## Remove all jobs

Command: **crontab -r**

## Install WXTOFLY cron jobs

**Command:** bash \$BASEDIR/WXTOFLY/CRON/setup_cron_job.sh

This creates cron job from \$BASEDIR/WXTOFLY/CRON/wxtofly.cron

# Manual run

**Command:**

-   bash \$BASEDIR/WXTOFLY/wxtofly.env

-   bash \$BASEDIR/WXTOFLY/RUN/run_wxtofly.sh \[INIT_TIME\]
