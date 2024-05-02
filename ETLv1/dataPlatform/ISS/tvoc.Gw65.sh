#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


name=("tvoc#2" "tvoc#3" "tvoc#4" "tvoc#5" "tvoc#6" "tvoc#7" "tvoc#8" "tvoc#9")
devEUI=("24e124710c409721" "24e124710c341712" "24e124710c408617" "24e124710c341912" "24e124710c340839" "24e124710c341766" "24e124710c341272" "24e124710c340856")

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-10 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

dataNum=0
while :
do
	if [ "${devEUI[$dataNum]}" == "" ]; then
		break
	fi
	
	if [ "$dataNum" == "11" ]; then
		break
	fi
	
	echo "REPLACE INTO dataPlatform.tvoc (ts, siteId, name, tvoc) SELECT 
			      ts,
				  '65',
				  '${name[$dataNum]}',
				  data->'$.tvoc' as tvoc
			FROM rawData.mqttIAQ 
			where 
			  data->'$.devEUI' ='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.tvoc' is not NULL
		;"
		
	mysql -h ${host} -ss -e"REPLACE INTO dataPlatform.tvoc (ts, siteId, name, tvoc) SELECT 
			      ts,
				  '65',
				  '${name[$dataNum]}',
				  data->'$.tvoc' as tvoc
			FROM rawData.mqttIAQ 
			where 
			   data->'$.devEUI'='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.tvoc' is not NULL
		;"
	
	dataNum=$(($dataNum+1))
done

exit 0
