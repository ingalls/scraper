#!/usr/bin/env bash

#PID from: http://gis.publicaccessnow.com/arcgis/rest/services/HarveyKs/HarveyKsDynamic/MapServer/0
# Download using github.com/openaddresses/esri-dump

#PID => Address
#http://www.harvey.kansasgis.com/ParcelDetail.aspx?parcel={PARCEL}&quickref=R2

set -e -o pipefail
OLDIFS=$IFS

IFS=""

#Only rewrite file if it doesn't exist
if [ ! -f $(dirname $0)/out.csv ]; then
    echo "LON,LAT,NUM,STR,CITY,ZIP,PID" > $(dirname $0)/out.csv
fi

curl -s 'http://www.harvey.kansasgis.com' -c /tmp/make_harvey_cookies.txt &>/dev/null
curl -s -X POST -d "" 'http://www.harvey.kansasgis.com/Disclaimer.aspx' -b /tmp/make_harvey_cookies.txt -c /tmp/make_harvey_pass_cookies.txt &>/dev/null

while read -r LINE; do
    CENTRE=$(echo $LINE | jq -r -c '.geometry | .coordinates' | sed -e 's/\[//' -e 's/]//')
    PID=$(echo "040$(echo $LINE | jq -r -c '.properties | .PIDNO')")

    if [ ! -z $(grep -E "${PID}$" $(dirname $0)/out.csv ) ]; then
        echo "$PIN already processed"
        continue
    fi

    if [[ ! -z $DEBUG ]]; then
        echo "-----"
        echo "WEB: http://www.harvey.kansasgis.com/ParcelDetail.aspx?parcel=${PID}&quickref=R2"
    fi

    WEB=$(curl -s "http://www.harvey.kansasgis.com/ParcelDetail.aspx?parcel=${PID}&quickref=R2" -b /tmp/make_harvey_pass_cookies.txt)

    if [ -z $(echo $WEB | grep "GeneralInfo_content_gvwPropertySitusInfo_lblSitusAddress_0") ]; then
        echo "could not find address field - you probably need to update curl creds"
        continue
    fi

    ADDR=$(echo $WEB \
        | grep "GeneralInfo_content_gvwPropertySitusInfo_lblSitusAddress_0" \
        | sed -e 's/<span.*\">//' -e 's/<.*//' | grep -Eo '[0-9].*')
    if [[ ! -z $DEBUG ]]; then echo "ADDR: $ADDR"; fi

    if [[ -z $(echo $ADDR | grep ',') ]]; then
        echo "has no street number"
        continue
    fi

    NUM=$(echo $ADDR | grep -Eo '^[0-9]+' | sed 's/,//g')
    STR=$(echo $ADDR | sed -e 's/,.*//' -e 's/[0-9]*\ //' -e 's/,//g' )
    CITY=$(echo $ADDR | grep -Eo ',.*' | sed -e 's/,\ //' -e 's/,.*//' -e 's/,//g')
    ZIP=$(echo $ADDR | grep -Eo '[0-9]{5}$' | sed 's/,//g')

    echo "$CENTRE,$NUM,$STR,$CITY,$ZIP,$PID"
    echo "$CENTRE,$NUM,$STR,$CITY,$ZIP,$PID" >> $(dirname $0)/out.csv
done <<< $($(dirname $0)/turf-cli/turf-point-on-surface.js $(dirname $)/output.geojson | jq -c -r '.features | .[]')
