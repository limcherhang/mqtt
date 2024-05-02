#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
        echo "請輸入 日期範圍"
		echo "		2019-12-15"
		echo "		00:00"
		echo "		2019-12-16"
		echo "		00:00"
		echo "		gatewayId"
		echo "		泵浦IEEE"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}
pumpIEEE=${6}


host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"


pumpName=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$pumpIEEE';"))
pumpId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as pumpId FROM iotmgmtChiller.vDeviceInfo where ieee='$pumpIEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))

echo "$startDay" > ./pumpPerformanceData
echo "$gwId" >> ./pumpPerformanceData
echo "$pumpName" >> ./pumpPerformanceData
echo "$pumpId" >> ./pumpPerformanceData

#***********************#
#Daily Activity Overview#
#***********************#
echo "Run Daily Activity Overview"
#Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT count(*) as ActivityCount 
FROM reportplatform.dailyPumpData
WHERE gatewayId=$gwId
and operationDate='$startDay'
and pumpDescription='$pumpName';
"))

if [ "$activityNum" == "" ]; then
	echo "0" >> ./pumpPerformanceData
	exit 1
else
	if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
		echo "0" >> ./pumpPerformanceData
		echo "NO activity"
	else
		activityNum=$(($activityNum-1))
		echo "$activityNum" >> ./pumpPerformanceData
	fi 
fi

activityCount="$(cat ./pumpPerformanceData | head -n 5 | tail -n 1)"

#Activity State
if [ $activityCount == 0 ]; then
	echo "0" >> ./pumpPerformanceData
else
	activityState=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as time,operationFlag as PreviousState 
	FROM reportplatform.dailyPumpData
	WHERE gatewayId=$gwId
	and operationDate='$startDay'
	and pumpDescription='$pumpName'
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
			printf ",">> ./pumpPerformanceData
		fi
		
		#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./pumpPerformanceData
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./pumpPerformanceData
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n">> ./pumpPerformanceData
fi
#chiller start time
operationDate="$(cat ./pumpPerformanceData | head -n 1 | tail -n 1)"	
gatewayId="$(cat ./pumpPerformanceData | head -n 2 | tail -n 1)"	
pumpDescription="$(cat ./pumpPerformanceData | head -n 3 | tail -n 1)"	
pumpId="$(cat ./pumpPerformanceData | head -n 4 | tail -n 1)"
activityCount="$(cat ./pumpPerformanceData | head -n 5 | tail -n 1)"
activityState="$(cat ./pumpPerformanceData | head -n 6 | tail -n 1)"

if [ "$activityState" == "0" ]; then
	echo "replace INTO dailyPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','$activityState'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','$activityState'
	);
	"
else
	echo "replace INTO dailyPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','{$activityState}'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyPumpActivity(operationDate,siteId,gatewayId,pumpId,pumpDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$pumpId','$pumpDescription',
	  '$activityCount','{$activityState}'
	);
	"
fi
rm ./pumpPerformanceData 
echo "End Program"
exit 0
