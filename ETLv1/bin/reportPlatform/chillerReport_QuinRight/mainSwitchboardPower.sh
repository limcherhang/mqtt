#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ] || [ "${8}" == "" ]; then
		echo "		起始日期 2019-12-15"
		echo "		00:00"
		echo "		結束日期 2019-12-16"
		echo "		00:00"
		echo "		gatewayId"
		echo "		Main Switchboard Power IEEE"
		echo " 		chiller IEEE"
		echo "      operation W"
        exit 1
fi

host="127.0.0.1"

startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}
mainIEEE=${6}
chillerIEEE=${7}
operationKwh=${8}

dbRPF="reportplatform"
dbMgmt="iotmgmt"

Name=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$mainIEEE';"))
Id=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) FROM iotmgmtChiller.vDeviceInfo where ieee='$mainIEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))

today=$(date "+%Y-%m-%d" --date="-1 day")

if [ $startDay == $today ]; then

	rawData=($(mysql -h ${host} -Diotmgmt -ss -e"select
		chilleTime,
		if(mainWatt-chillerWatt > 1,1,0) as Flag
	FROM(
		select
				date_format(receivedSync, '%Y-%m-%d %H:%i')as chilleTime,
				ieee as chillerIEEE,
				truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as chillerWatt
		FROM 
			 pm 
		WHERE ieee='$chillerIEEE' and
				receivedSync >='$startDay $startTime' and 
				receivedSync <'$endDay $endTime' and
				(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
		GROUP BY chilleTime
	) as a
	left join
	(
		select
				date_format(receivedSync, '%Y-%m-%d %H:%i') as mainTime,
				ieee as mainIEEE,
				truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) mainWatt
		FROM 
			 pm 
		WHERE ieee='$mainIEEE' and
				receivedSync >='$startDay $startTime' and 
		        receivedSync <'$endDay $endTime' and
				(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
		GROUP BY mainTime
	) as b
	on chilleTime=mainTime
	where 
		truncate(mainWatt-chillerWatt,0) is not NULL
	;"))
	
else
	
	dbdataMonth=$(date +%m -d "$startDay")
	
	rawData=($(mysql -h ${host} -Diotdata2021 -ss -e"select
		chilleTime,
		if(mainWatt-chillerWatt > 1,1,0) as Flag
	FROM(
		select
				date_format(receivedSync, '%Y-%m-%d %H:%i')as chilleTime,
				ieee as chillerIEEE,
				truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as chillerWatt
		FROM 
			 pm_$dbdataMonth
		WHERE ieee='$chillerIEEE' and
				receivedSync >='$startDay $startTime' and 
				receivedSync <'$endDay $endTime' and
				(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
		GROUP BY chilleTime
	) as a
	left join
	(
		select
				date_format(receivedSync, '%Y-%m-%d %H:%i') as mainTime,
				ieee as mainIEEE,
				truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) mainWatt
		FROM 
			 pm_$dbdataMonth
		WHERE ieee='$mainIEEE' and
				receivedSync >='$startDay $startTime' and 
				receivedSync <'$endDay $endTime' and
				(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
		GROUP BY mainTime
	) as b
	on chilleTime=mainTime
	where 
		truncate(mainWatt-chillerWatt,0) is not NULL
	;"))	
fi

dataNum=0
if [ "${rawData[$dataNum]}" == "" ]; then
	echo "[ERROR]$startDay $startTime~$endDay $endTime chiller:$chillerIEEE main:$mainIEEE Power Meter no data"
	exit 0
fi

arrNum=1

FlagStatus=0
while :
do
	if [ "${rawData[$dataNum]}" == "" ]; then
		break
	fi
	
	tsDay=${rawData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	tsTime=${rawData[$dataNum]}
	dataNum=$(($dataNum+1))

	flag=${rawData[$dataNum]}
	dataNum=$(($dataNum+1))

	echo "[DEBUG]$tsDay $tsTime $flag"
	if [ $flag == 0 ]; then

		if [ $FlagStatus == 0 ]; then
			echo "[DEBUG]$tsDay $tsTime $flag"
			startDayArr[$arrNum]=$tsDay
		    startTimeArr[$arrNum]=$tsTime
			flagArr[$arrNum]=$flag
			
			FlagStatus=1
		elif [ $FlagStatus == 2 ]; then
			PreNum=$dataNum
			PreNum=$(($PreNum-4))
			Preflag=${rawData[$PreNum]}
			PreNum=$(($PreNum-1))
			tsPreTime=${rawData[$PreNum]}
			PreNum=$(($PreNum-1))
			tsPreDay=${rawData[$dataNum]}
			
			echo "[DEBUG]$tsPreDay $tsPreTime $Preflag"
			endDayArr[$arrNum]=$tsPreDay
		    endTimeArr[$arrNum]=$tsPreTime
			
			arrNum=$(($arrNum+1))
			echo "[DEBUG]$tsDay $tsTime $flag"
			startDayArr[$arrNum]=$tsDay
		    startTimeArr[$arrNum]=$tsTime
			flagArr[$arrNum]=$flag
			
			FlagStatus=1
			
		fi

	elif [ $flag == 1 ]; then
		
		if [ $FlagStatus == 0 ]; then
			echo "[DEBUG]$tsDay $tsTime $flag"
			startDayArr[$arrNum]=$tsDay
		    startTimeArr[$arrNum]=$tsTime
			flagArr[$arrNum]=$flag
			
			FlagStatus=2
		elif [ $FlagStatus == 1 ]; then
			PreNum=$dataNum
			PreNum=$(($PreNum-4))
			Preflag=${rawData[$PreNum]}
			PreNum=$(($PreNum-1))
			tsPreTime=${rawData[$PreNum]}
			PreNum=$(($PreNum-1))
			tsPreDay=${rawData[$dataNum]}
			
			echo "[DEBUG]$tsPreDay $tsPreTime $Preflag"
			endDayArr[$arrNum]=$tsPreDay
		    endTimeArr[$arrNum]=$tsPreTime
			
			
			arrNum=$(($arrNum+1))
			echo "[DEBUG] $tsDay $tsTime $flag"
			startDayArr[$arrNum]=$tsDay
		    startTimeArr[$arrNum]=$tsTime
			flagArr[$arrNum]=$flag
			
			FlagStatus=2
		fi
	fi
	
done
echo "[DEBUG]End flag:$flag FlagStatus:$FlagStatus"
if [ $flag == 0 ]; then

	if [ $FlagStatus == 1 ]; then
		echo "[DEBUG]End $tsDay $tsTime $flag"
		endDayArr[$arrNum]=$tsDay
	    endTimeArr[$arrNum]=$tsTime
	fi

elif [ $flag == 1 ]; then

	if [ $FlagStatus == 0 ]; then
		echo "[DEBUG]End $tsDay $tsTime $flag"
		endDayArr[$arrNum]=$tsDay
		endTimeArr[$arrNum]=$tsTime
	fi
	
	if [ $FlagStatus == 2 ]; then
		echo "[DEBUG]End $tsDay $tsTime $flag"
		endDayArr[$arrNum]=$tsDay
		endTimeArr[$arrNum]=$tsTime
	fi
fi

whileNum=$arrNum
while :
do
	if [ $whileNum == 0 ]; then
		break
	fi
	
	echo "receivedSync >='${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}' and 
		  receivedSync <='${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}'"
	if [ $startDay == $today ]; then

		totalPowerWh=($(mysql -h ${host} -Diotmgmt -ss -e"
		select
                mainTotalW-chillerTotalW
        FROM(
                select
					date_format(receivedSync, '%Y-%m-%d %H:%i')as chillerTime,
					Max(totalPositiveWattHour)-Min(totalPositiveWattHour) as chillerTotalW
				FROM
					 pm
				WHERE ieee='$chillerIEEE' and
					receivedSync >='${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}' and 
					receivedSync <='${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}'
        ) as a
        left join
        (
               select
					date_format(receivedSync, '%Y-%m-%d %H:%i')as mainTime,
					Max(totalPositiveWattHour)-Min(totalPositiveWattHour) as mainTotalW
				FROM
					 pm
				WHERE ieee='$mainIEEE' and
					receivedSync >='${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}' and 
					receivedSync <='${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}'
        ) as b
        on chillerTime=mainTime
		;"))
		
	else
		
		dbdataMonth=$(date +%m -d "$startDay")
		
		totalPowerWh=($(mysql -h ${host} -Diotdata2021 -ss -e"
		select
                mainTotalW-chillerTotalW
        FROM(
                select
					date_format(receivedSync, '%Y-%m-%d %H:%i')as chillerTime,
					Max(totalPositiveWattHour)-Min(totalPositiveWattHour) as chillerTotalW
				FROM
					 pm
				WHERE ieee='$chillerIEEE' and
					receivedSync >='${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}' and 
					receivedSync <='${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}'
        ) as a
        left join
        (
               select
					date_format(receivedSync, '%Y-%m-%d %H:%i')as mainTime,
					Max(totalPositiveWattHour)-Min(totalPositiveWattHour) as mainTotalW
				FROM
					 pm
				WHERE ieee='$mainIEEE' and
					receivedSync >='${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}' and 
					receivedSync <='${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}'
        ) as b
        on chillerTime=mainTime
		;"))	
	fi
	echo "${startDayArr[$whileNum]} ${startTimeArr[$whileNum]} ${endDayArr[$whileNum]} ${endTimeArr[$whileNum]} ${flagArr[$whileNum]} $totalPowerWh"
	
	echo "replace INTO dailyChillerPumpCoolingData(
		operationDate,siteId,gatewayId,Id,description,startTime,endTime,totalPowerWh,operationFlag
		) 
		VALUES(
		'${startDayArr[$whileNum]}','$siteId','$gwId', '$Id', '$Name', '${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}', '${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}', 
		 '$totalPowerWh', '${flagArr[$whileNum]}'
		);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPumpCoolingData(
		operationDate,siteId,gatewayId,Id,description,startTime,endTime,totalPowerWh,operationFlag
		) 
		VALUES(
		'${startDayArr[$whileNum]}','$siteId','$gwId', '$Id', '$Name', '${startDayArr[$whileNum]} ${startTimeArr[$whileNum]}', '${endDayArr[$whileNum]} ${endTimeArr[$whileNum]}', 
		 '$totalPowerWh', '${flagArr[$whileNum]}'
		);
	"	
	whileNum=$(($whileNum-1))
done

#***********************#
#Daily Activity Overview#
#***********************#

echo "Run Daily Activity Overview"
#Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"
SELECT 
	count(*) as ActivityCount 
FROM 
	reportplatform.dailyChillerPumpCoolingData
WHERE 
	gatewayId=$gwId and 
	operationDate='$startDay' and 
	description='$Name';
"))

if [ "$activityNum" == "" ]; then
	echo "[ERROR] no data"
	exit 1
else
	if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
		echo "NO activity"
		activityCount=0
	else
		activityNum=$(($activityNum-1))
		activityCount=$activityNum
	fi 
fi

echo "activityCount:$activityCount"
#Activity State
echo " "  > ./buf/activityState.json
if [ $activityCount == 0 ]; then
    echo "replace INTO dailyChillerPumpCoolingActivity(operationDate,siteId,gatewayId,Id,Description,
	  activityCount,activityState
	  ) 
	VALUES('$startDay','$siteId','$gwId','$Id', '$Name',
	  '$activityCount','0'
	);"
	
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPumpCoolingActivity(operationDate,siteId,gatewayId,Id,Description,
	  activityCount,activityState
	  ) 
	VALUES('$startDay','$siteId','$gwId','$Id', '$Name',
	  '$activityCount','0'
	);"
else
	activityState=($(mysql -h ${host} -D$dbRPF -ss -e"
	SELECT 
		date_format(startTime, '%H %i') as time,operationFlag as PreviousState 
	FROM 
		reportplatform.dailyChillerPumpCoolingData
	WHERE 
		gatewayId=$gwId and 
		operationDate='$startDay' and 
		description='$Name' and 
		startTime != '$startDay 00:00';
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
			printf "," >> ./buf/activityState.json
		fi
		
		#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./buf/activityState.json
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./buf/activityState.json
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n" >> ./buf/activityState.json
	activityState="$(cat ./buf/activityState.json | head -n 2 | tail -n 1)"

	echo "replace INTO dailyChillerPumpCoolingActivity(operationDate,siteId,gatewayId,Id,Description,
	  activityCount,activityState
	  ) 
	VALUES('$startDay','$siteId','$gwId','$Id', '$Name',
	  '$activityCount','{$activityState}'
	);"
	
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPumpCoolingActivity(operationDate,siteId,gatewayId,Id,Description,
	  activityCount,activityState
	  ) 
	VALUES('$startDay','$siteId','$gwId','$Id', '$Name',
	  '$activityCount','{$activityState}'
	);"
fi




exit 0
