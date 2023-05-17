import os.path, os
import sys, getopt, csv, json

csv_file = ''
json_file = ''

opts, args = getopt.getopt(sys.argv[1:], "hc:j:", ["help,csv=,json="])
for opt, arg in opts:
    if opt == ("-h", "--help"):
        print ('upload-website.py -c|--csv <csv path> -j|--json <json path>')
        sys.exit()
    elif opt in ("-c", "--csv"):
        csv_file = arg
    elif opt in ("-j", "--json"):
        json_file = arg

if not csv_file:
    print ('CSV file option is missing')
    sys.exit()

if not json_file:
    print ('CSV file option is missing')
    sys.exit()

if not os.path.exists(csv_file) or not os.path.isfile(csv_file):
    print (f'CSV file {csv_file} not found')
    sys.exit()

if os.path.exists(json_file) and os.path.isfile(json_file):
    with open(json_file, 'r') as f:
        json_data = json.load(f)
        print(f'Current number of sites in {json_file}: {len(json_data)}')

def get_site_key(site):
    return f'{site[0].lower()}_{site[1].lower()}_{site[2].lower()}'

with open(csv_file, "r") as f:
    data = list(csv.reader(f, delimiter=","))
    f.close()

sorted_data = sorted(data[1::], key=get_site_key)

json_data = []

# {
#     "State":  "British Columbia",
#     "Area":  "Central Kootenay",
#     "Site":  "IdahoPk.",
#     "Lat":  "49.9738",
#     "Lon":  "-117.34437",
#     "Region":  "PNWRAT",
#     "Domain":  "PNWRAT"
# },

for site in sorted_data:
    if len(site) < 7:
        raise "Invalid site"

    json_data.append({
        'State': site[0],
        'Area': site[1],
        'Site': site[2],
        'Lat': float(site[3]),
        'Lon': float(site[4]),
        'Region': site[5],
        'Domain': site[6]
    })

print(f'Found {len(sorted_data)} sites in {csv_file}')    

with open(json_file, 'w') as f:
    json.dump(json_data, f)
    f.close()

print(f'Wrote {len(json_data)} sites to {json_file}')    