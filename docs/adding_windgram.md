# Adding Windgram

1. Add a site to wwwroot\status\sites.csv as State,Area,Site,Lat,Lon,Region,Domain
2. Run py\create_sites_json.py to crate sites.json

```
create_sites_json.py -c [ROOT-PATH]\wwwroot\status\sites.csv -j [ROOT-PATH]\wwwroot\v2\json\sites.json
```
3. Run Grunt to publish V2 web file to publish\wwwroot\v2
4. Upload V2 web files with py\upload-website.py

```
upload-website.py -u [USERNAME] -p [PASSWORD] -w [ROOT-PATH]\publish\v2 -f v2
```

5. Upload status files with py\upload-website.py

```
upload-website.py -u [USERNAME] -p [PASSWORD] -w [ROOT-PATH]\wwwroot\status -f status
```

