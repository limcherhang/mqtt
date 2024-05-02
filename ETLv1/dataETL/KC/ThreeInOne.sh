#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


name=("ThreeInOne#1" "ThreeInOne#2" "ThreeInOne#3" "ThreeInOne#4" "ThreeInOne#5" "ThreeInOne#6" "ThreeInOne#7" "ThreeInOne#8" "ThreeInOne#9")
APIID=("838122" "837EFA" "838512" "837ED2" "837CBD" "838FA1" "837D6D" "838B86" "838F9E")

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-20 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

dataNum=0
while :
do
	if [ "${APIID[$dataNum]}" == "" ]; then
		break
	fi
	
	echo "REPLACE INTO dataETL.threeInOne(ts, gatewayId, name, temp, humidity, co2)
			SELECT APIts,'261','${name[$dataNum]}',
			(conv(substring(rawdata->'$.data',4,4),16,10))/10 as temp,
			conv(substring(rawdata->'$.data',8,2),16,10) as h,
			conv(substring(rawdata->'$.data',10,4),16,10) as co2
			FROM rawData.sigfoxAPI where deviceId='${APIID[$dataNum]}' and APIts >= '$startRunTime' and  APIts < '$endRunTime';
		;"
	
	mysql -h ${host} -ss -e"REPLACE INTO dataETL.threeInOne(ts, gatewayId, name, temp, humidity, co2)
			SELECT APIts,'261','${name[$dataNum]}',
			(conv(substring(rawdata->'$.data',4,4),16,10))/10 as temp,
			conv(substring(rawdata->'$.data',8,2),16,10) as h,
			conv(substring(rawdata->'$.data',10,4),16,10) as co2
			FROM rawData.sigfoxAPI where deviceId='${APIID[$dataNum]}' and APIts >= '$startRunTime' and  APIts < '$endRunTime'
		;"
	
	dataNum=$(($dataNum+1))
done

exit 0
