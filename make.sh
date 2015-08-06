#!/usr/bin/env bash

#PID from: http://gis.publicaccessnow.com/arcgis/rest/services/SumnerKs/SumnerKsDynamic/MapServer/0
# Download using github.com/openaddresses/esri-dump

#PID => Address
#http://www.sumner.kansasgis.com/ParcelDetail.aspx?parcel=0960110100000002000&quickref=R2

set -e -o pipefail
OLDIFS=$IFS

IFS=""

#Only rewrite file if it doesn't exist
if [ ! -f $(dirname $0)/out.csv ]; then
    echo "LON,LAT,NUM,STR,CITY,ZIP,PID" > $(dirname $0)/out.csv
fi

while read -r LINE; do
    CENTRE=$(echo $LINE | jq -r -c '.geometry | .coordinates' | sed -e 's/\[//' -e 's/]//')
    PID=$(echo $LINE | jq -r -c '.properties | .WEB_PUBLIC' | sed -e 's/^.*=//' -e 's/\-//g' -e 's/\.//g')

    if [ ! -z $(grep -E "${PID}$" $(dirname $0)/out.csv ) ]; then
        echo "$PIN already processed"
        continue
    fi

    if [[ ! -z $DEBUG ]]; then
        echo "-----"
        echo "WEB: http://www.sumner.kansasgis.com/ParcelDetail.aspx?parcel=${PID}&quickref=R2"
    fi

    WEB=$(curl -s "http://www.sumner.kansasgis.com/ParcelDetail.aspx?parcel=${PID}&quickref=R2" -H 'Host: www.sumner.kansasgis.com' -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:29.0) Gecko/20100101 Firefox/29.0' -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' -H 'Accept-Language: en-US,en;q=0.5' --compressed -H 'DNT: 1' -H 'Referer: http://www.sumner.kansasgis.com/greybox/loader_frame.html?s=0' -H 'Cookie: __utma=165988668.91698580.1438486744.1438881524.1438885614.6; __utmz=165988668.1438486744.1.1.utmcsr=google|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided); ASP.NET_SessionId=sbkjrvatbfrj3jx42lowb0dx; __utmc=165988668; __utmb=165988668.4.10.1438885614; __utmt=1' -H 'Connection: keep-alive')

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
