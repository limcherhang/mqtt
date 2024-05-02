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
		echo "		Cooling IEEE"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}
IEEE=${6}


host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

Name=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$IEEE';"))
Id=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as Id FROM iotmgmtChiller.vDeviceInfo where ieee='$IEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))


#***********************#
#Daily Activity Overview#
#***********************#
echo "Run Daily Activity Overview"
#Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT count(*) as ActivityCount 
FROM reportplatform.dailyCoolingData
WHERE gatewayId=$gwId
and operationDate='$startDay'
and coolingDescription='$Name';
"))

if [ "$activityNum" == "" ]; then
	echo "[ERROR]activityNum data is null."
	exit 1
else

	echo "$startDay" > ./data/$gwId.$IEEE.coolingPerformanceData
	echo "$gwId" >> ./data/$gwId.$IEEE.coolingPerformanceData
	echo "$Name" >> ./data/$gwId.$IEEE.coolingPerformanceData
	echo "$Id" >> ./data/$gwId.$IEEE.coolingPerformanceData
	
	if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
		echo "0" >> ./data/$gwId.$IEEE.coolingPerformanceData
		echo "NO activity"
	else
		activityNum=$(($activityNum-1))
		echo "$activityNum" >> ./data/$gwId.$IEEE.coolingPerformanceData
	fi 
fi

activityCount="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 5 | tail -n 1)"

#Activity State
if [ $activityCount == 0 ]; then
	echo "0" >> ./data/$gwId.$IEEE.coolingPerformanceData
else
	activityState=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as time,operationFlag as PreviousState 
	FROM reportplatform.dailyCoolingData
	WHERE gatewayId=$gwId
	and operationDate='$startDay'
	and coolingDescription='$Name'
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
			printf ",">> ./data/$gwId.$IEEE.coolingPerformanceData
		fi
		
		#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/$gwId.$IEEE.coolingPerformanceData
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/$gwId.$IEEE.coolingPerformanceData
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n">> ./data/$gwId.$IEEE.coolingPerformanceData
fi
#chiller start time
operationDate="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 1 | tail -n 1)"	
gatewayId="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 2 | tail -n 1)"	
coolingDescription="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 3 | tail -n 1)"	
Id="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 4 | tail -n 1)"
activityCount="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 5 | tail -n 1)"
activityState="$(cat ./data/$gwId.$IEEE.coolingPerformanceData | head -n 6 | tail -n 1)"

if [ "$activityState" == "0" ]; then
	echo "REPlACE INTO dailyCoolingActivity(operationDate,siteId,gatewayId,coolingId,coolingDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$Id','$coolingDescription',
	  '$activityCount','$activityState'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyCoolingActivity(operationDate,siteId,gatewayId,coolingId,coolingDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$Id','$coolingDescription',
	  '$activityCount','$activityState'
	);
	"
else
	echo "REPlACE INTO dailyCoolingActivity(operationDate,siteId,gatewayId,coolingId,coolingDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$Id','$coolingDescription',
	  '$activityCount','{$activityState}'
	);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyCoolingActivity(operationDate,siteId,gatewayId,coolingId,coolingDescription,
	  activityCount,activityState
	  ) 
	VALUES('$operationDate','$siteId','$gatewayId','$Id','$coolingDescription',
	  '$activityCount','{$activityState}'
	);
	"
fi
rm ./data/$gwId.$IEEE.coolingPerformanceData 
exit 0
