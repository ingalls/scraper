#!/usr/bin/env bash

#PID from: http://gis.publicaccessnow.com/arcgis/rest/services/SumnerKs/SumnerKsDynamic/MapServer/0
# Download using github.com/openaddresses/esri-dump

#PID => Address
#http://www.sumner.kansasgis.com/ParcelDetail.aspx?parcel=0960110100000002000&quickref=R2

set -e -o pipefail
OLDIFS=$IFS

IFS=""
echo "LON,LAT,NUM,STR,CITY,ZIP,PID" > $(dirname $0)/out.csv
while read -r LINE; do
    CENTRE=$(echo $LINE | jq -r -c '.geometry | .coordinates' | sed -e 's/\[//' -e 's/]//')
    PID=$(echo $LINE | jq -r -c '.properties | .WEB_PUBLIC' | sed -e 's/^.*=//' -e 's/\-//g' -e 's/\.//g')

    ADDR=$(curl "http://www.sumner.kansasgis.com/ParcelDetail.aspx?parcel=${PID}&quickref=R2" \
        | grep "GeneralInfo_content_gvwPropertySitusInfo_lblSitusAddress_0" \
        | sed -e 's/<span.*\">//' -e 's/<.*//' | grep -Eo '[0-9].*')

    NUM=$(echo $ADDR | grep -Eo '^[0-9]+' | sed 's/,//g')
    STR=$(echo $ADDR | sed -e 's/,.*//' -e 's/[0-9]*\ //' -e 's/,//g' )
    CITY=$(echo $ADDR | grep -Eo ',.*' | sed -e 's/,\ //' -e 's/,.*//' -e 's/,//g')
    ZIP=$(echo $ADDR | grep -Eo '[0-9]{5}$' | sed 's/,//g')

    echo "$CENTRE,$NUM,$STR,$CITY,$ZIP,$PID" >> $(dirname $0)/out.csv
done <<< $($(dirname $0)/turf-cli/turf-point-on-surface.js $(dirname $)/output.geojson | jq -c -r '.features | .[]')
