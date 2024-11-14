# raspnw - v2

This repo contains files for RASP based soaring forecasting for PNW. This is the 2nd version which runs old WRF 2.0 and covers Washington, northern Oregon and southern British Columbia. The model runs are initiated from NAM with 32km resolution and produce forecast down to 1.3 km for certain regions.

# File structure
- model 
    - RASP files which are installed on a Linux machine
    - Installation instruction can be found on http://wxtofly.net/v2/install.html

- docs
    - Site documentation

- ps
    - PowerShell utilities mostly for content under http://wxtofly.net/v2

- py
    - Python utilities for updating web content under http://wxtofly.net/v2

- wwwroot
    - Web content related to V2
    - The file structure corresponds to file structure on the web server


# Update web site
After making changes follow this sequence to upload updated files to web host

1. Publish new files

    In VS Code terminat run ``grunt``. This will update and copy HTML files to the publish folder

2. Upload HTML files to web host

    Run ``upload-website.py -w [V2_PUBLISH_PATH] -u [USENAME] -p [PASSWORD] -f v2``

    For example: Run ``upload-website.py -w C:\\Code\\Repos\\raspnw-v2\\publish\\wwwroot\\v2 -u [USENAME] -p [PASSWORD] -f v2``

3. Upload status files to web host

    Run ``upload-website.py -w [STATUS_PUBLISH_PATH] -u [USENAME] -p [PASSWORD] -f status``
    
    For example: Run ``upload-website.py -w C:\\Code\\Repos\\raspnw-v2\\publish\\wwwroot\\status -u [USENAME] -p [PASSWORD] -f status``
