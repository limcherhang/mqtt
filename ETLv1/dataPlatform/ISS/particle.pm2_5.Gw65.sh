#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


name=("particle#4" "particle#6" "particle#8" "particle#10" "particle#12" "particle#14" "particle#16" "particle#18")
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
	
	echo "REPLACE INTO dataPlatform.particle (ts, siteId, name, particle) SELECT 
			      ts,
				  '65',
				  '${name[$dataNum]}',
				  data->'$.pm2_5' as particle
			FROM rawData.mqttIAQ 
			where 
			  data->'$.devEUI' ='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pm2_5' is not NULL
		;"
		
	mysql -h ${host} -ss -e"REPLACE INTO dataPlatform.particle (ts, siteId, name, particle) SELECT 
			      ts,
				  '65',
				  '${name[$dataNum]}',
				  data->'$.pm2_5' as particle
			FROM rawData.mqttIAQ 
			where 
			   data->'$.devEUI'='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pm2_5' is not NULL
		;"
	
	dataNum=$(($dataNum+1))
done

exit 0
