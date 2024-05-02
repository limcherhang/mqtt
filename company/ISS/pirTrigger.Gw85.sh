#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


name=("pirTrigger#2" "pirTrigger#3" "pirTrigger#4" "pirTrigger#5")
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
	
	echo "REPLACE INTO dataPlatform.pirTrigger (ts, siteId, name, pirTrigger) SELECT 
			      ts,
				  '85',
				  '${name[$dataNum]}',
				  data->'$.pir_trigger' as pirTrigger
			FROM rawData.mqttIAQ 
			where 
			  data->'$.devEUI' ='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pir_trigger' is not NULL
		;"
		
	mysql -h ${host} -ss -e"REPLACE INTO dataPlatform.pirTrigger (ts, siteId, name, pirTrigger) SELECT 
			      ts,
				  '85',
				  '${name[$dataNum]}',
				  data->'$.pir_trigger' as pirTrigger
			FROM rawData.mqttIAQ 
			where 
			   data->'$.devEUI'='${devEUI[$dataNum]}' and 
			  ts >= '$startRunTime' and 
			  ts < '$endRunTime' and data->'$.pir_trigger' is not NULL
		;"
	
	dataNum=$(($dataNum+1))
done

exit 0
