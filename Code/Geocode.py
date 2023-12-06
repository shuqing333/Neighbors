import csv
import pandas as pd
from arcgis.gis import GIS
from arcgis.geocoding import geocode
from arcgis.geocoding import batch_geocode

# Change the working directory
import os
os.chdir("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Code")

# Create a GIS object to connect to your ArcGIS Online or Portal account
portal = GIS(username="cshuqing_UofMD", password="vUdjec-qazcu2-dehtoq")

#############Geocode all of the voter registration files and Infutor data
# Read the input addresses from a CSV file
files = ["/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Code/Geocode_test_address.csv"]
for file in files:
    input_file = file
    output_file = file.replace("address", "geocoded")

    addresses = []
    with open(input_file, "r") as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            addresses.append(row["Original_address"])

    # Geocode each address one by one
    with open(output_file, "w", newline="") as csvfile:
        fieldnames = ["Original_address", "Latitude", "Longitude","match_addr","score"]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for address in addresses:
            try:
                result = geocode(address, out_sr=None)[0]
                writer.writerow({"Original_address": address,
                            "Latitude": result["location"]["y"],
                            "Longitude": result["location"]["x"],
                            "match_addr": result["address"],
                            "score": result["score"]})
            except Exception as e:
                print(f"Error geocoding addresses in file '{file}': {str(e)}")
                continue
with open(input_file, "r") as csvfile:
    reader = csv.reader(csvfile)
    headers = next(reader)  # Get the header row
    print(headers)
