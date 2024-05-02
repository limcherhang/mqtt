#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


name=("particle#2" "particle#4" "particle#6" "particle#8")
devEUI=("24e124710c408878" "24e124710c408261" "24e124710c408409" "24e124710c408901")

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
				  '85',
				  '${name[$dataNum]}',
				  data->'$.pm10' as particle
			FROM rawData.mqttIAQ 
			where 
			  data->'$.devEUI' ='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pm10' is not NULL
		;"
		
	mysql -h ${host} -ss -e"REPLACE INTO dataPlatform.particle (ts, siteId, name, particle) SELECT 
			      ts,
				  '85',
				  '${name[$dataNum]}',
				  data->'$.pm10' as particle
			FROM rawData.mqttIAQ 
			where 
			   data->'$.devEUI'='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pm10' is not NULL
		;"
	
	dataNum=$(($dataNum+1))
done

exit 0
