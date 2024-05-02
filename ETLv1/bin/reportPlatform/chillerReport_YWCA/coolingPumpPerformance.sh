#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ]; then
        echo "請輸入SiteId Name CoolingNum CoolingName 2021-10-08 00:00 2021-10-09 00:00 gatewayId"
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"

siteId=${1}
Name=${2}
coolingNum=${3}
coolingName=${4}

startDay=${5}
startTime=${6}

endDay=${7}
endTime=${8}

gatewayId=${9}


today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")


host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

gwId=$gatewayId
Name=$coolingName
pumpId=$coolingNum
#siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))

echo "$startDay" > ./data/coolingPump.PerformanceData.$startDay.$IEEE
echo "$gwId" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
echo "$Name" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
echo "$pumpId" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE

#***********************#
#Daily Activity Overview#
#***********************#

echo "Run Daily Activity Overview"

#Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT count(*) as ActivityCount 
FROM reportplatform.dailyCoolingPumpData
WHERE siteId=$siteId
and operationDate='$startDay'
and pumpDescription='$Name';
"))

if [ "$activityNum" == "" ]; then
	echo "[ERROR]Cooling Pump ActivityNum data is null."
	exit 1
else
	if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
		echo "0" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
		echo "NO activity"
	else
		activityNum=$(($activityNum-1))
		echo "$activityNum" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
	fi
fi

activityCount="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 5 | tail -n 1)"

#Activity State
if [ $activityCount == 0 ]; then
	echo "0" >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
else
	activityState=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as time,operationFlag as PreviousState 
	FROM reportplatform.dailyCoolingPumpData
	WHERE siteId=$siteId
	and operationDate='$startDay'
	and pumpDescription='$Name'
	and startTime != '$startDay 00:00';
	"))

	dataNum=0
	jsonNum=1
	
	while :
	do
		if [ "${activityState[$dataNum]}" == "" ]; then
			break
		fi
		hours=${activityState[$dataNum]}
		hours=$((10#$hours))
		dataNum=$(($dataNum+1))
		
		minutes=${activityState[$dataNum]}
		minutes=$((10#$minutes))
		dataNum=$(($dataNum+1))
		
		state=${activityState[$dataNum]}
		dataNum=$(($dataNum+1))
		
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/coolingPump.PerformanceData.$startDay.$IEEE
		fi
		
		#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/coolingPump.PerformanceData.$startDay.$IEEE
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n">> ./data/coolingPump.PerformanceData.$startDay.$IEEE
fi

#chiller start time
operationDate="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 1 | tail -n 1)"	
gatewayId="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 2 | tail -n 1)"	
pumpDescription="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 3 | tail -n 1)"	
pumpId="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 4 | tail -n 1)"
activityCount="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 5 | tail -n 1)"
activityState="$(cat ./data/coolingPump.PerformanceData.$startDay.$IEEE | head -n 6 | tail -n 1)"

if [ "$activityState" == "0" ]; then
	echo "REPlACE INTO dailyCoolingPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','$activityState'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyCoolingPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','$activityState'
	);
	"
else
	echo "REPlACE INTO dailyCoolingPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','{$activityState}'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyCoolingPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','{$activityState}'
	);
	"
fi

rm ./data/coolingPump.PerformanceData.$startDay.$IEEE
exit 0
