#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
        echo "請輸入 2020-01-09 104 1 00124b000be4cbb8 ultrasonicFlow2"
		echo "		start day"
		echo "		gateway id"
		echo "		chiller id"
		echo "		Flow IEEE"
		echo "		Flow table"
        exit 1
fi

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

today=$(date "+%Y-%m-%d" --date="-1 day")

startDay=${1}
gId=${2}
chiId=${3}
flowIEEE=${4}

siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gId;"))
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

if [ $startDay == $today ]; then
	dbdata="iotmgmt"
	flowTable=${5}
else
	#dbdata="iotdata"
	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	flowTable=${5}_$dbdataMonth

	dbdata="iotdata$dbdataYear"
fi

if [ $flowIEEE == 0 ] || [ $flowTable == 0 ] ; then
	echo "  flowIEEE:$flowIEEE dbdata:$dbdata flowTable:$flowTable"
	exit 0
fi

flowName=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$flowIEEE';"))
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gId;"))

chillerTime=($(mysql -h ${host} -D$dbRPF -ss -e"
	SELECT 
	   date_format(startTime, '%H:%i') as startTime,
	   date_format(endTime, '%H:%i') as endTime,
	   totalPowerWh 
	FROM 
	  reportplatform.dailyChillerData
	WHERE 
	  gatewayId=$gId and 
	  operationDate='$startDay' and 
	  chillerId='$chiId' and 
	  operationFlag=1
	;
	"))
	
if [ -f "./data/flow.$startDay.$gId.$chiId" ]; then
	rm ./data/flow.$startDay.$gId.$chiId
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/flow.$startDay.$gId.$chiId.$whileHour" ]; then
		rm ./data/flow.$startDay.$gId.$chiId.$whileHour
	fi

	whileHour=$(($whileHour+1))
done
if [ "${chillerTime[0]}" == "" ]; then
		echo "  chillerId='$chiId' Operation OFF"
else
	
	echo "  chillerId='$chiId' flowIEEE:$flowIEEE dbdata:$dbdata flowTable:$flowTable "
	
	whileNum=0
	while :
	do
		if [ "${chillerTime[$whileNum]}" == "" ]; then
			break
		fi
		
		startRunTime=${chillerTime[$whileNum]}
		whileNum=$(($whileNum+1))

		endRunTime=${chillerTime[$whileNum]}
		whileNum=$(($whileNum+1))

		echo "    $startDay $startRunTime~$endRunTime:59"
		whileNum=$(($whileNum+1))

		flowData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT 
						date_format(receivedSync, '%H') as hoursNum,
						date_format(receivedSync, '%i') as minuteNum,
						truncate(flowRate,2)
					FROM 
						$flowTable
					WHERE 
						ieee='$flowIEEE' and 
						receivedSync>='$startDay $startRunTime' and 
						receivedSync<='$startDay $endRunTime:59'
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				;
		"))
				
		flowDataNum=0
		while :
		do
			if [ "${flowData[$flowDataNum]}" == "" ]; then
				break
			fi
			
			flowHoursNum=${flowData[$flowDataNum]}
			hoursNum=$((10#$flowHoursNum))
			flowDataNum=$(($flowDataNum+1))
			
			flowMinuteNum=${flowData[$flowDataNum]}
			flowDataNum=$(($flowDataNum+1))
			
			flow=${flowData[$flowDataNum]}
			flowDataNum=$(($flowDataNum+1))
			
			echo "[DEBUG]$startDay $flowHoursNum:$flowMinuteNum flow:$flow"

			echo "$flow" >> ./data/flow.$startDay.$gId.$chiId.$hoursNum
			echo "$flow" >> ./data/flow.$startDay.$gId.$chiId
		done
	done
fi

if [ -f "./data/flow.$startDay.$gId.$chiId" ]; then

	countNum="$(cat ./data/flow.$startDay.$gId.$chiId |wc -l)"

	if [ $countNum == 0 ]; then

		flowMin=NULL
		flowMedian=NULL
		flowMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/flow.$startDay.$gId.$chiId > ./data/flow.$startDay.$gId.$chiId.sort
		rm ./data/flow.$startDay.$gId.$chiId
		
		flowMin="$(cat ./data/flow.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
		flowMedian="$(cat ./data/flow.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
		flowMax="$(cat ./data/flow.$startDay.$gId.$chiId.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/flow.$startDay.$gId.$chiId.sort
	else

		sort -n ./data/flow.$startDay.$gId.$chiId > ./data/flow.$startDay.$gId.$chiId.sort
		rm ./data/flow.$startDay.$gId.$chiId
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] countNum FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] countNum ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($countNum/2))
		
		flowMin="$(cat ./data/flow.$startDay.$gId.$chiId.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		flowMedian="$(cat ./data/flow.$startDay.$gId.$chiId.sort | head -n $medianNum | tail -n 1)" 
		flowMax="$(cat ./data/flow.$startDay.$gId.$chiId.sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./data/flow.$startDay.$gId.$chiId.sort
	fi
else
	flowMin=NULL
	flowMedian=NULL
	flowMax=NULL
fi

echo "    flowMin $flowMin" 
echo "    flowMedian $flowMedian" 
echo "    flowMax $flowMax"
whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/flow.$startDay.$gId.$chiId.$whileHour" ]; then
	
		#echo "./data/flow.$startDay.$gId.$chiId.$whileHour"
		
		countNum="$(cat ./data/flow.$startDay.$gId.$chiId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/flow.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/flow.$startDay.$gId
			
			dataTotalCal="$(cat ./buf/flow.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/flow.$startDay.$gId
			
		dataTotalCal="$(cat ./buf/flow.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/flow.$startDay.$gId.$chiId.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/flow.$startDay.$gId.$chiId.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/flow.$startDay.$gId.$chiId.Json
	fi
	
	whileHour=$(($whileHour+1))
done

flowDataNULL=0
if [ -f "./data/flow.$startDay.$gId.$chiId.Json" ]; then
	flowData="$(cat ./data/flow.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
	rm ./data/flow.$startDay.$gId.$chiId.Json
else
	flowDataNULL=1
fi

echo "replace INTO dailyChillerFlow(operationDate,siteId,gatewayId,chillerId,chillerDescription,flowMin,flowMedian,flowMax,
  flowData
  ) 
VALUES('$startDay','$siteId','$gId','$chiId','$flowName',
	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax'),
	if($flowDataNULL = 1,NULL,'{$flowData}'));
"
mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerFlow(operationDate,siteId,gatewayId,chillerId,chillerDescription,flowMin,flowMedian,flowMax,
  flowData
  ) 
VALUES('$startDay','$siteId','$gId','$chiId','$flowName',
  	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax'),
  if($flowDataNULL = 1,NULL,'{$flowData}'));
  "

exit 0
