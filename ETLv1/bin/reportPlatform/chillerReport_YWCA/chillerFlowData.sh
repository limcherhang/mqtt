#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ]; then
        echo "請輸入SiteId Name chillerNum chillerName 2021-10-08 00:00 2021-10-09 00:00 gatewayId FlowName"
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"
dbRPF="reportplatform"

siteId=${1}
Name=${2}
chillerNum=${3}
chillerName=${4}

startDay=${5}
startTime=${6}

endDay=${7}
endTime=${8}

gatewayId=${9}
flowName=${10}


today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbFlow="flow"
	
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbFlow="flow_$dbdataMonth"

fi

flowFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
flowThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$siteId $Name $chillerNum $chillerName $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbFlow $flowName"
echo "*************************************************************************************************"
chillerTimeData=($(mysql -h ${host} -D$reportPlatform -ss -e"select 
	date_format(startTime, '%Y-%m-%d %H:%i')as startTime,
	date_format(endTime, '%Y-%m-%d %H:%i')as endTime,
	operationFlag
  FROM dailyChillerData
	  WHERE 
	  siteId='$siteId' and
	  chillerId='$chillerNum' and 
	  operationDate ='$startDay'
"))

arrNum=1
dataNum=0
while :
do
	if [ "${chillerTimeData[$dataNum]}" == "" ]; then
		break
	fi
	
	chillerStartDay[$arrNum]=${chillerTimeData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	chillerStartTime[$arrNum]=${chillerTimeData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	chillerEndDay[$arrNum]=${chillerTimeData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	chillerEndTime[$arrNum]=${chillerTimeData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	operationFlag[$arrNum]=${chillerTimeData[$dataNum]}
	dataNum=$(($dataNum+1))


	echo "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]} ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]} ${operationFlag[$arrNum]}"
done

#echo "$arrNum"

while :
do
	if [ $arrNum == 0 ]; then
		break
	fi
	
	#echo "  [DEBUG]${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]} ~ ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"
	
	stTime=$(date +%s -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}")
	edTime=$(date +%s -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}")
	
	runTime=$(($edTime-$stTime))
	
	#echo "  [DEBUG]$edTime-$stTime=$runTime"
	runTimeMinute=$(($runTime/60))

	#runMinutes
	runMinutes_start=$(date -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" +%s)
	runMinutes_end=$(date -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	#echo "$runMinutes"
	
	flowData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT flowRate
		 FROM 
			$tbFlow 
		 WHERE 
			siteId='$siteId' and
			name='$flowName' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
			order by flowRate asc
	"))
	

	whileNum=0
	while :
	do
		if [ "${flowData[$whileNum]}" == "" ]; then
			break
		fi
		
		echo "${flowData[$whileNum]}" >> ./buf/flow.sort
		
		whileNum=$(($whileNum+1))
	done

	flowCount="$(cat ./buf/flow.sort | wc -l)" 
	
	if [ $flowCount == 0 ]; then

		flowMin=NULL
		flowMedian=NULL
		flowMax=NULL
		
	elif [ $flowCount == 1 ]; then

		flowMin="$(cat ./buf/flow.sort | head -n  1 | tail -n 1)" 
		flowMedian="$(cat ./buf/flow.sort | head -n 1 | tail -n 1)" 
		flowMax="$(cat ./buf/flow.sort | head -n 1 | tail -n 1)" 
	else
		
		echo "scale=0;$(($flowCount*$flowFirstQuatile))/100"|bc > ./buf/flow.Num
		flowFirstQuatileNum="$(cat ./buf/flow.Num | head -n 1 | tail -n 1)"
		if [ $flowFirstQuatileNum == 0 ]; then
			flowFirstQuatileNum=1
			echo "[DEBUG] flowFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] flowFirstQuatile Num:$flowFirstQuatileNum"
		
		echo "scale=0;$(($flowCount*$flowThirdQuatile))/100"|bc > ./buf/flow.Num
		flowThirdQuatileNum="$(cat ./buf/flow.Num | head -n 1 | tail -n 1)"
		#echo "[DEBUG] flowThirdQuatile Num:$flowThirdQuatileNum"	
		
		medianNum=$(($flowCount/2))
		
		flowMin="$(cat ./buf/flow.sort | head -n  $flowFirstQuatileNum | tail -n 1)" 
		flowMedian="$(cat ./buf/flow.sort | head -n $medianNum | tail -n 1)" 
		flowMax="$(cat ./buf/flow.sort  | head -n $flowThirdQuatileNum | tail -n 1)" 
		
		rm ./buf/*
	fi


	flowData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT 
			date_format(ts, '%H') as hoursNum,
			date_format(ts, '%i') as minuteNum,
			truncate(flowRate,2)
		FROM 
			$tbFlow 
		WHERE 
			siteId='$siteId' and
			name='$flowName' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
		GROUP BY date_format(ts, '%Y-%m-%d %H:%i')
	;"))
	
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
		
		#echo "[DEBUG]$startDay $flowHoursNum:$flowMinuteNum flow:$flow"

		echo "$flow" >> ./data/flow.$hoursNum
	done

	whileHour=0
	jsonNum=0
	stHour=0
	endHour=0
	while :
	do
		if [ "$whileHour" == 24 ]; then
			break
		fi

		if [ -f "./data/flow.$whileHour" ]; then

			countNum="$(cat ./data/flow.$whileHour |wc -l)"
			
			calNum=1
			dataTotalCal=0
			calData=0

			while :
			do
				if [ $calNum == $countNum ]; then
					break
				fi
				
				calData="$(cat ./data/flow.$whileHour | head -n $calNum | tail -n 1)"
				
				#echo "$dataTotalCal+$calData"
				echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/flow.cal
				
				dataTotalCal="$(cat ./buf/flow.cal | head -n 1 | tail -n 1)"
				
				calNum=$(($calNum+1))
			done
			
			echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/flow.cal
				
			dataTotalCal="$(cat ./buf/flow.cal | head -n 1 | tail -n 1)"
			#echo " $dataTotalCal"

			rm ./data/flow.$whileHour
			
			jsonNum=$(($jsonNum+1))
					  #>=
			if [ $jsonNum -ge 2 ]; then
				printf ",">> ./data/flow.Json
			fi
			
			stHour=$whileHour
			endHour=$(($whileHour+1))

			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/flow.Json
		fi
		
		whileHour=$(($whileHour+1))
	done

	flowDataNULL=0
	if [ -f "./data/flow.Json" ]; then
		flowData="$(cat ./data/flow.Json | head -n 1 | tail -n 1)"
		rm ./data/flow.Json
	else
		flowDataNULL=1
	fi
	
	
	# echo "Operation Date : $startDay"
	# echo "Site Id : $siteId"
	# echo "Gateway Id : $gatewayId"
	# echo "chillerId : $chillerNum"
    # echo "chiliierDescription : $chillerName"
	# echo "startTime ${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" 
	# echo "endTime ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"
	# echo "opMinutes : $runMinutes"
	# echo "flowMin : $flowMin"
	# echo "flowMedian : $flowMedian"
	# echo "flowMax : $flowMax"
	# echo "$flowData"
	
	echo "replace INTO dailyChillerFlow(operationDate,siteId,gatewayId,chillerId,chillerDescription,flowMin,flowMedian,flowMax,
			flowData
		  ) 
		VALUES('$startDay','$siteId','$gatewayId','$chillerNum', '$chillerName',
			if($flowMin is NULL,NULL,'$flowMin'),
			if($flowMedian is NULL,NULL,'$flowMedian'),
			if($flowMax is NULL,NULL,'$flowMax'),
			if($flowDataNULL = 1,NULL,'{$flowData}'));
		"
	mysql -h ${host} -D$reportPlatform -ss -e"replace INTO dailyChillerFlow(operationDate,siteId,gatewayId,chillerId,chillerDescription,flowMin,flowMedian,flowMax,
			flowData
		  ) 
		VALUES('$startDay','$siteId','$gatewayId','$chillerNum', '$chillerName',
			if($flowMin is NULL,NULL,'$flowMin'),
			if($flowMedian is NULL,NULL,'$flowMedian'),
			if($flowMax is NULL,NULL,'$flowMax'),
			if($flowDataNULL = 1,NULL,'{$flowData}'));
	"
	
	arrNum=$(($arrNum-1))
done
exit 0

