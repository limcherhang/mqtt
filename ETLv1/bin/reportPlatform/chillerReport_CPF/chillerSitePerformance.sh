#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] ; then
        echo "請輸入SiteId Name chillerNum chillerName 2021-10-08 00:00 2021-10-09 00:00 gatewayId TempNameSupply TempNameReturn"
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
tempNameSupply=${10}
tempNameReturn=${11}

today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbTemp="temp"
	dbProcess="processETL"
	tbChiller="chiller"
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"
fi

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

#value defined
totalEnergyConsumption=0
totalRunMinutes=0
dataKWCount=0
dataKWTotal=0
powerLoading=0
avgPowerLoading=NULL

tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$siteId $Name $chillerNum $chillerName $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp $tempNameSupply $tempNameReturn"
echo "*************************************************************************************************"

if [ -f "./data/efficiency.daily" ]; then
	rm ./data/efficiency.daily
fi

if [ -f "./data/coolingCapacity.daily" ]; then
	rm ./data/coolingCapacity.daily
fi

if [ -f "./data/powerConsumed.daily" ]; then
	rm ./data/powerConsumed.daily
fi

if [ -f "./data/tempReturn.daily" ]; then
	rm ./data/tempReturn.daily
fi

if [ -f "./data/tempSupply.daily" ]; then
	rm ./data/tempSupply.daily
fi

if [ -f "./data/tempDelta.daily" ]; then
	rm ./data/tempDelta.daily
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/coolingCapacity.$whileHour" ]; then
		rm ./data/coolingCapacity.$whileHour
	fi
	if [ -f "./data/efficiency.$whileHour" ]; then
		rm ./data/efficiency.$whileHour
	fi

	if [ -f "./data/powerConsumed.$whileHour" ]; then
		rm ./data/powerConsumed.$whileHour
	fi
	
	if [ -f "./data/tempReturn.$whileHour" ]; then
		rm ./data/tempReturn.$whileHour
	fi
	
	if [ -f "./data/tempSupply.$whileHour" ]; then
		rm ./data/tempSupply.$whileHour
	fi
	
	if [ -f "./data/tempDelta.$whileHour" ]; then
		rm ./data/tempDelta.$whileHour
	fi

	whileHour=$(($whileHour+1))
done

echo "#************************************************#"
echo "#Daily Activity Overview & Performance Overview  #"
echo "#************************************************#"


echo "  --Daily Activity Overview-- "
# Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"
  SELECT count(*) as ActivityCount 
  FROM 
	 dailyChillerData
  WHERE 
	siteId='$siteId' and
	chillerId='$chillerNum' and 
	operationDate ='$startDay';
"))

if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
	activityNum=0
else
	activityNum=$(($activityNum-1))
fi

echo "    Activity $activityNum"

# Activity State
activityStateNum=0
if [ $activityNum == 0 ]; then
	activityStateNum=1
	echo "     Activity State is NULL"
else
	activityStateData=($(mysql -h ${host} -D$dbRPF -ss -e"
	SELECT 
		date_format(startTime, '%H %i') as time,
		operationFlag as PreviousState 
	FROM 
		dailyChillerData
	WHERE 
		siteId='$siteId' and 
		operationDate='$startDay' and 
		chillerId='$chillerNum' and 
		startTime != '$startDay 00:00';
	"))

	dataNum=0
	jsonNum=1
	while :
	do
		if [ "${activityStateData[$dataNum]}" == "" ]; then
			break
		fi
		hours=${activityStateData[$dataNum]}
		hours=$((10#$hours))
		dataNum=$(($dataNum+1))
		
		minutes=${activityStateData[$dataNum]}
		minutes=$((10#$minutes))
		dataNum=$(($dataNum+1))
		
		state=${activityStateData[$dataNum]}
		dataNum=$(($dataNum+1))
		
					  # >=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/activityState
		fi
		
		# "state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/activityState
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/activityState
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n">> ./data/activityState
fi

activityStateNULL=0
if [ -f "./data/activityState" ]; then
	activityState="$(cat ./data/activityState | head -n 1 | tail -n 1)"
	rm ./data/activityState
else
	activityStateNULL=1
fi

echo "    Activity State : $activityState"
echo " "
echo "--Daily Performance Overview--"

chillerTime=($(mysql -h ${host} -D$reportPlatform -ss -e"select 
	date_format(startTime, '%H:%i') as startTime,
	date_format(endTime, '%H:%i') as endTime,
	totalPowerWh 
  FROM 
     dailyChillerData
   WHERE 
	  siteId='$siteId' and
	  chillerId='$chillerNum' and 
	  operationDate ='$startDay' and
	  operationFlag=1
"))

if [ "${chillerTime[0]}" == "" ]; then
	echo "No Run Time"
	exit 0
fi

#value defined
totalEnergyConsumption=0
totalRunMinutes=0
dataKWCount=0
dataKWTotal=0
powerLoading=0

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

	#Total Energy Consumption (kWh) = Average Power Consumption (kW) * No. of hours that Chiller is ON (h)
				
	totalEnergyConsumption=$(($totalEnergyConsumption+${chillerTime[$whileNum]}))
	
	runMinutes_start=$(date -d "$startDay $startRunTime" +%s)
	runMinutes_end=$(date -d "$startDay $endRunTime" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	totalRunMinutes=$(($runMinutes+$totalRunMinutes))	
	
	echo "    $startDay $startRunTime~$endRunTime:59 Operation Minutes:$runMinutes Energy Consumption:${chillerTime[$whileNum]}"
	whileNum=$(($whileNum+1))
	
	powerMeterData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
		date_format(ts, '%H') as hoursNum,
		date_format(ts, '%i') as minuteNum,
		powerConsumed
    FROM $tbPower
	  WHERE 
	  siteId='$siteId' and
	  name='$Name' and 
	  ts >= '$startDay $startRunTime' and 
	  ts <= '$startDay $endRunTime:59'
	"))
	
	dataNum=0
	while :
	do
		if [ "${powerMeterData[$dataNum]}" == "" ]; then
			break
		fi
		
		hoursNum=${powerMeterData[$dataNum]}
		hoursNum=$((10#$hoursNum))
		dataNum=$(($dataNum+1))
		
		minuteNum=${powerMeterData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		powerConsumed=${powerMeterData[$dataNum]}
		dataNum=$(($dataNum+1))

		#echo "[DEBUG]$hoursNum:$minuteNum powerConsumed:$powerConsumed"

		echo "$powerConsumed" >> ./data/powerConsumed.$hoursNum
		echo "$powerConsumed" >> ./data/powerConsumed.daily

	done
	
	processData=($(mysql -h ${host} -D$dbProcess -ss -e"select 
		date_format(ts, '%H') as hoursNum,
		date_format(ts, '%i') as minuteNum,
		coolingCapacity,
		efficiency
    FROM $tbChiller
	  WHERE 
	  siteId='$siteId' and
	  name='$chillerName' and 
	  ts >= '$startDay $startRunTime' and 
	  ts <= '$startDay $endRunTime:59' and efficiency is not NULL
	"))
	
	dataNum=0
	while :
	do
		if [ "${processData[$dataNum]}" == "" ]; then
			break
		fi
		
		hoursNum=${processData[$dataNum]}
		hoursNum=$((10#$hoursNum))
		dataNum=$(($dataNum+1))
		
		minuteNum=${processData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		coolingCapacity=${processData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		efficiency=${processData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		echo "[DEBUG]$hoursNum:$minuteNum coolingCapacity:$coolingCapacity efficiency:$efficiency"

		echo "$coolingCapacity" >> ./data/coolingCapacity.$hoursNum
		echo "$coolingCapacity" >> ./data/coolingCapacity.daily
		
		echo "$efficiency" >> ./data/efficiency.$hoursNum
		echo "$efficiency" >> ./data/efficiency.daily
	done
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT 
			date_format(ts, '%H') as hoursNum,
			date_format(ts, '%i') as minuteNum,
			temp
		 FROM 
			$tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameSupply' and 
			ts >= '$startDay $startRunTime' and 
			ts <= '$startDay $endRunTime:59'
	"))
	

	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi
		
		hoursNum=${tempData[$dataNum]}
		hoursNum=$((10#$hoursNum))
		dataNum=$(($dataNum+1))
		
		minuteNum=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		tempSupply=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))

		#echo "[DEBUG]$hoursNum:$minuteNum tempSupply:$tempSupply"

		echo "$tempSupply" >> ./data/tempSupply.$hoursNum
		echo "$tempSupply" >> ./data/tempSupply.daily
	done
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT 
			date_format(ts, '%H') as hoursNum,
			date_format(ts, '%i') as minuteNum,
			temp
		 FROM 
			$tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameReturn' and 
			ts >= '$startDay $startRunTime' and 
			ts <= '$startDay $endRunTime:59'
	"))
	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi
		
		hoursNum=${tempData[$dataNum]}
		hoursNum=$((10#$hoursNum))
		dataNum=$(($dataNum+1))
		
		minuteNum=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		tempReturn=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))

		#echo "[DEBUG]$hoursNum:$minuteNum tempReturn:$tempReturn"

		echo "$tempReturn" >> ./data/tempReturn.$hoursNum
		echo "$tempReturn" >> ./data/tempReturn.daily
	done
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
		date_format(a.time, '%H') as hoursNum,
		date_format(a.time, '%i') as minuteNum,
		Round(tempReturn-tempSupply,2) as delta
	from
	(
	SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
	  FROM  $tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameSupply' and 
			ts >= '$startDay $startRunTime' and 
			ts <= '$startDay $endRunTime:59'
	) as a
	INNER join
	(
	  SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn 
	   FROM $tbTemp 
		WHERE 
			siteId='$siteId' and
			name='$tempNameReturn' and 
			ts >= '$startDay $startRunTime' and 
			ts <= '$startDay $endRunTime:59'
	) as b
	on a.time=b.time
	;"))
	
	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi
		
		hoursNum=${tempData[$dataNum]}
		hoursNum=$((10#$hoursNum))
		dataNum=$(($dataNum+1))
		
		minuteNum=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))
		
		tempDelta=${tempData[$dataNum]}
		dataNum=$(($dataNum+1))

		#echo "[DEBUG]$hoursNum:$minuteNum tempDelta:$tempDelta"

		echo "$tempDelta" >> ./data/tempDelta.$hoursNum
		echo "$tempDelta" >> ./data/tempDelta.daily
	done
	
done


totalOperationMinutes=$totalRunMinutes


if [ -f "./data/powerConsumed.daily" ]; then

	countNum="$(cat ./data/powerConsumed.daily |wc -l)"

	if [ $countNum == 0 ]; then

		avgPowerConsumption=NULL

	elif [ $countNum == 1 ]; then
	
		
		avgPowerConsumption="$(cat ./data/powerConsumed.daily | head -n 1 | tail -n 1)" 
		
	else

		sort -n ./data/powerConsumed.daily > ./data/powerConsumed.daily.sort
		rm ./data/powerConsumed.daily

		medianNum=$(($countNum/2))
		
		avgPowerConsumption="$(cat ./data/powerConsumed.daily.sort | head -n $medianNum | tail -n 1)" 
		
		rm ./data/powerConsumed.daily.sort
	fi
else
	avgPowerConsumption=NULL
fi

echo "avgPowerConsumption:$avgPowerConsumption"

if [ -f "./data/coolingCapacity.daily" ]; then

	countNum="$(cat ./data/coolingCapacity.daily |wc -l)"

	if [ $countNum == 0 ]; then

		coolingCapacityMin=NULL
		coolingCapacityMedian=NULL
		coolingCapacityMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/coolingCapacity.daily > ./data/coolingCapacity.daily.sort
		rm ./data/coolingCapacity.daily
		
		coolingCapacityMin="$(cat ./data/coolingCapacity.daily.sort | head -n 1 | tail -n 1)" 
		coolingCapacityMedian="$(cat ./data/coolingCapacity.daily.sort | head -n 1 | tail -n 1)" 
		coolingCapacityMax="$(cat ./data/coolingCapacity.daily.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/coolingCapacity.daily.sort
	else

		sort -n ./data/coolingCapacity.daily > ./data/coolingCapacity.daily.sort
		rm ./data/coolingCapacity.daily
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/dataQuatile
		tempFirstQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] coolingCapacity Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/dataQuatile
		tempThirdQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)"
		#echo "[DEBUG] coolingCapacity Num:$tempThirdQuatileNum"	

		rm ./buf/dataQuatile
		
		medianNum=$(($countNum/2))
		
		coolingCapacityMin="$(cat ./data/coolingCapacity.daily.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		coolingCapacityMedian="$(cat ./data/coolingCapacity.daily.sort | head -n $medianNum | tail -n 1)" 
		coolingCapacityMax="$(cat ./data/coolingCapacity.daily.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./data/coolingCapacity.daily.sort
	fi
else
	coolingCapacityMin=NULL
	coolingCapacityMedian=NULL
	coolingCapacityMax=NULL
fi

echo "coolingCapacityMin:$coolingCapacityMin coolingCapacityMedian:$coolingCapacityMedian coolingCapacityMax:$coolingCapacityMax"


if [ -f "./data/efficiency.daily" ]; then

	countNum="$(cat ./data/efficiency.daily |wc -l)"

	if [ $countNum == 0 ]; then

		efficiencyMin=NULL
		efficiencyMedian=NULL
		efficiencyMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/efficiency.daily > ./data/efficiency.daily.sort
		rm ./data/efficiency.daily
		
		efficiencyMin="$(cat ./data/efficiency.daily.sort | head -n 1 | tail -n 1)" 
		efficiencyMedian="$(cat ./data/efficiency.daily.sort | head -n 1 | tail -n 1)" 
		efficiencyMax="$(cat ./data/efficiency.daily.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/efficiency.daily.sort
	else

		sort -n ./data/efficiency.daily > ./data/efficiency.daily.sort
		rm ./data/efficiency.daily
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/dataQuatile
		tempFirstQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] Efficiency Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/dataQuatile
		tempThirdQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)"
		#echo "[DEBUG] Efficiency Num:$tempThirdQuatileNum"	

		rm ./buf/dataQuatile
		
		medianNum=$(($countNum/2))
		
		efficiencyMin="$(cat ./data/efficiency.daily.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		efficiencyMedian="$(cat ./data/efficiency.daily.sort | head -n $medianNum | tail -n 1)" 
		efficiencyMax="$(cat ./data/efficiency.daily.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./data/efficiency.daily.sort
	fi
else
	efficiencyMin=NULL
	efficiencyMedian=NULL
	efficiencyMax=NULL
fi

echo "efficiencyMin:$efficiencyMin efficiencyMedian:$efficiencyMedian efficiencyMax:$efficiencyMax"

if [ -f "./data/tempSupply.daily" ]; then

	countNum="$(cat ./data/tempSupply.daily |wc -l)"

	if [ $countNum == 0 ]; then

		tempSupplyMin=NULL
		tempSupplyMedian=NULL
		tempSupplyMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/tempSupply.daily > ./data/tempSupply.daily.sort
		rm ./data/tempSupply.daily
		
		tempSupplyMin="$(cat ./data/tempSupply.daily.sort | head -n 1 | tail -n 1)" 
		tempSupplyMedian="$(cat ./data/tempSupply.daily.sort | head -n 1 | tail -n 1)" 
		tempSupplyMax="$(cat ./data/tempSupply.daily.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/tempSupply.daily.sort
	else

		sort -n ./data/tempSupply.daily > ./data/tempSupply.daily.sort
		rm ./data/tempSupply.daily
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/dataQuatile
		tempFirstQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempSupply Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/dataQuatile
		tempThirdQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempSupply Num:$tempThirdQuatileNum"	

		rm ./buf/dataQuatile
		
		medianNum=$(($countNum/2))
		
		tempSupplyMin="$(cat ./data/tempSupply.daily.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		tempSupplyMedian="$(cat ./data/tempSupply.daily.sort | head -n $medianNum | tail -n 1)" 
		tempSupplyMax="$(cat ./data/tempSupply.daily.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./data/tempSupply.daily.sort
	fi
else
	tempSupplyMin=NULL
	tempSupplyMedian=NULL
	tempSupplyMax=NULL
fi

if [ -f "./data/tempReturn.daily" ]; then

	countNum="$(cat ./data/tempReturn.daily |wc -l)"

	if [ $countNum == 0 ]; then

		tempReturnMin=NULL
		tempReturnMedian=NULL
		tempReturnMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/tempReturn.daily > ./data/tempReturn.daily.sort
		rm ./data/tempReturn.daily
		
		tempReturnMin="$(cat ./data/tempReturn.daily.sort | head -n 1 | tail -n 1)" 
		tempReturnMedian="$(cat ./data/tempReturn.daily.sort | head -n 1 | tail -n 1)" 
		tempReturnMax="$(cat ./data/tempReturn.daily.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/tempReturn.daily.sort
	else

		sort -n ./data/tempReturn.daily > ./data/tempReturn.daily.sort
		rm ./data/tempReturn.daily
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/dataQuatile
		tempFirstQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempReturn Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/dataQuatile
		tempThirdQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempReturn Num:$tempThirdQuatileNum"	

		rm ./buf/dataQuatile
		
		medianNum=$(($countNum/2))
		
		tempReturnMin="$(cat ./data/tempReturn.daily.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		tempReturnMedian="$(cat ./data/tempReturn.daily.sort | head -n $medianNum | tail -n 1)" 
		tempReturnMax="$(cat ./data/tempReturn.daily.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./data/tempReturn.daily.sort
	fi
else
	tempReturnMin=NULL
	tempReturnMedian=NULL
	tempReturnMax=NULL
fi

if [ -f "./data/tempDelta.daily" ]; then

	countNum="$(cat ./data/tempDelta.daily |wc -l)"

	if [ $countNum == 0 ]; then

		tempDeltaMin=NULL
		tempDeltaMedian=NULL
		tempDeltaMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./data/tempDelta.daily > ./data/tempDelta.daily.sort
		rm ./data/tempDelta.daily
		
		tempDeltaMin="$(cat ./data/tempDelta.daily.sort | head -n 1 | tail -n 1)" 
		tempDeltaMedian="$(cat ./data/tempDelta.daily.sort | head -n 1 | tail -n 1)" 
		tempDeltaMax="$(cat ./data/tempDelta.daily.sort  | head -n 1 | tail -n 1)" 
		
		rm ./data/tempDelta.daily.sort
	else

		sort -n ./data/tempDelta.daily > ./data/tempDelta.daily.sort
		rm ./data/tempDelta.daily
		
		echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/dataQuatile
		tempFirstQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempDelta Num:$tempFirstQuatileNum"

		echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/dataQuatile
		tempThirdQuatileNum="$(cat ./buf/dataQuatile | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempDelta Num:$tempThirdQuatileNum"	

		rm ./buf/dataQuatile
		
		medianNum=$(($countNum/2))
		
		tempDeltaMin="$(cat ./data/tempDelta.daily.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
		tempDeltaMedian="$(cat ./data/tempDelta.daily.sort | head -n $medianNum | tail -n 1)" 
		tempDeltaMax="$(cat ./data/tempDelta.daily.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./data/tempDelta.daily.sort
	fi
else
	tempDeltaMin=NULL
	tempDeltaMedian=NULL
	tempDeltaMax=NULL
fi

#ChilledWaterSupplyTemp(°C)
echo "    tempSupplyMin $tempSupplyMin" 
echo "    tempSupplyMedian $tempSupplyMedian" 
echo "    tempSupplyMax $tempSupplyMax"

#ChilledWaterReturnTemp(°C)
echo "    tempReturnMin $tempReturnMin" 
echo "    tempReturnMedian $tempReturnMedian"
echo "    tempReturnMax $tempReturnMax"

#ChilledWaterDeltaTemp(°C)
echo "    tempDeltaMin $tempDeltaMin"
echo "    tempDeltaMedian $tempDeltaMedian"
echo "    tempDeltaMax $tempDeltaMax"

echo "***********************************"
echo "  Run PowerConsumed Data for Hours"

if [ -f "./data/powerConsumed.Json" ]; then
	rm ./data/powerConsumed.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/powerConsumed.$whileHour" ]; then

		countNum="$(cat ./data/powerConsumed.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/powerConsumed.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/powerConsumed.cal
			
			dataTotalCal="$(cat ./buf/powerConsumed.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/powerConsumed.cal
			
		dataTotalCal="$(cat ./buf/powerConsumed.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/powerConsumed.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/powerConsumed.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/powerConsumed.Json
	fi
	
	whileHour=$(($whileHour+1))
done

powerConsumedDataNULL=0
if [ -f "./data/powerConsumed.Json" ]; then
	powerConsumptionData="$(cat ./data/powerConsumed.Json | head -n 1 | tail -n 1)"
	rm ./data/powerConsumed.Json
else
	powerConsumedDataNULL=1
fi

#echo "[DEBUG]Power Consumed Data $powerConsumedData"

echo "  Run Cooling Capacity Data for hours"
			
if [ -f "./data/coolingCapacity.Json" ]; then
	rm ./data/coolingCapacity.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/coolingCapacity.$whileHour" ]; then

		countNum="$(cat ./data/coolingCapacity.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/coolingCapacity.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/coolingCapacity.cal
			
			dataTotalCal="$(cat ./buf/coolingCapacity.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/coolingCapacity.cal
			
		dataTotalCal="$(cat ./buf/coolingCapacity.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/coolingCapacity.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/coolingCapacity.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/coolingCapacity.Json
	fi
	
	whileHour=$(($whileHour+1))
done

coolingCapacityDataNULL=0
if [ -f "./data/coolingCapacity.Json" ]; then
	coolingCapacityData="$(cat ./data/coolingCapacity.Json | head -n 1 | tail -n 1)"
	rm ./data/coolingCapacity.Json
else
	coolingCapacityDataNULL=1
fi

#echo "[DEBUG]coolingCapacityData $coolingCapacityData"

echo "  Run Efficiency Data for Hours"

if [ -f "./data/efficiency.Json" ]; then
	rm ./data/efficiency.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/efficiency.$whileHour" ]; then

		countNum="$(cat ./data/efficiency.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/efficiency.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/efficiency.cal
			
			dataTotalCal="$(cat ./buf/efficiency.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/efficiency.cal
			
		dataTotalCal="$(cat ./buf/efficiency.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/efficiency.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/efficiency.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/efficiency.Json
	fi
	
	whileHour=$(($whileHour+1))
done

efficiencyDataNULL=0
if [ -f "./data/efficiency.Json" ]; then
	efficiencyData="$(cat ./data/efficiency.Json | head -n 1 | tail -n 1)"
	rm ./data/efficiency.Json
else
	efficiencyDataNULL=1
fi

#echo "[DEBUG]$efficiencyData"

echo "***********************************"
echo "  Run Temp Delta Data for Hours"

if [ -f "./data/tempDelta.Json" ]; then
	rm ./data/tempDelta.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/tempDelta.$whileHour" ]; then

		countNum="$(cat ./data/tempDelta.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/tempDelta.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempDelta.cal
			
			dataTotalCal="$(cat ./buf/tempDelta.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempDelta.cal
			
		dataTotalCal="$(cat ./buf/tempDelta.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/tempDelta.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/tempDelta.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempDelta.Json
	fi
	
	whileHour=$(($whileHour+1))
done

tempDeltaDataNULL=0
if [ -f "./data/tempDelta.Json" ]; then
	tempDeltaData="$(cat ./data/tempDelta.Json | head -n 1 | tail -n 1)"
	rm ./data/tempDelta.Json
else
	tempDeltaDataNULL=1
fi

#echo "[DEBUG]Temp Delta Data $tempDeltaData"

echo "  Run Temp Supply Data for Hours"

if [ -f "./data/tempSupply.Json" ]; then
	rm ./data/tempSupply.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/tempSupply.$whileHour" ]; then

		countNum="$(cat ./data/tempSupply.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/tempSupply.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempSupply.cal
			
			dataTotalCal="$(cat ./buf/tempSupply.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempSupply.cal
			
		dataTotalCal="$(cat ./buf/tempSupply.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/tempSupply.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/tempSupply.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempSupply.Json
	fi
	
	whileHour=$(($whileHour+1))
done

tempSupplyDataNULL=0
if [ -f "./data/tempSupply.Json" ]; then
	tempSupplyData="$(cat ./data/tempSupply.Json | head -n 1 | tail -n 1)"
	rm ./data/tempSupply.Json
else
	tempSupplyDataNULL=1
fi

echo "[DEBUG]Temp Supply Data $tempSupplyData"

echo "  Run Temp Return Data for Hours"

if [ -f "./data/tempReturn.Json" ]; then
	rm ./data/tempReturn.Json
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./data/tempReturn.$whileHour" ]; then

		countNum="$(cat ./data/tempReturn.$whileHour |wc -l)"
		
		calNum=1
		dataTotalCal=0
		calData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			calData="$(cat ./data/tempReturn.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalCal+$calData"
			echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempReturn.cal
			
			dataTotalCal="$(cat ./buf/tempReturn.cal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempReturn.cal
			
		dataTotalCal="$(cat ./buf/tempReturn.cal | head -n 1 | tail -n 1)"
		#echo " $dataTotalCal"

		rm ./data/tempReturn.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./data/tempReturn.Json
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempReturn.Json
	fi
	
	whileHour=$(($whileHour+1))
done

tempReturnDataNULL=0
if [ -f "./data/tempReturn.Json" ]; then
	tempReturnData="$(cat ./data/tempReturn.Json | head -n 1 | tail -n 1)"
	rm ./data/tempReturn.Json
else
	tempReturnDataNULL=1
fi

#echo "[DEBUG]tempReturnData :$tempReturnData"


echo "replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
			activityCount,activityState,
			totalOperationMinutes,
			avgPowerConsumption,
			totalEnergyConsumption,
			avgPowerLoading,
			efficiencyMin,efficiencyMedian,efficiencyMax,
			coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
			returnTempMin,returnTempMedian,returnTempMax,
			supplyTempMin,supplyTempMedian,supplyTempMax,
			deltaTempMin,deltaTempMedian,deltaTempMax,
			efficiencyData,
			coolingCapacityData,
			powerConsumptionData,
			returnTempData,
			supplyTempData,
			deltaTempData) 
		VALUES('$startDay','$siteId','$gatewayId', '$chillerNum', '$chillerName',
		'$activityNum','{$activityState}',
		'$totalOperationMinutes',
		'$avgPowerConsumption',
		'$totalEnergyConsumption',
		if($avgPowerLoading is NULL,NULL,'$avgPowerLoading'),
		'$efficiencyMin','$efficiencyMedian','$efficiencyMax',
		if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
		if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
		if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
		'$tempReturnMin','$tempReturnMedian','$tempReturnMax',
		'$tempSupplyMin','$tempSupplyMedian','$tempSupplyMax',
		'$tempDeltaMin','$tempDeltaMedian','$tempDeltaMax',
		'{$efficiencyData}',
		'{$coolingCapacityData}',
		'{$powerConsumptionData}',
		if($tempReturnDataNULL = 1,NULL,'{$tempReturnData}'),
		if($tempSupplyDataNULL = 1,NULL,'{$tempSupplyData}'),
		if($tempDeltaDataNULL = 1,NULL,'{$tempDeltaData}')
		);
		"
		
		
	mysql -h ${host} -D$reportPlatform -ss -e"replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
			activityCount,activityState,
			totalOperationMinutes,
			avgPowerConsumption,
			totalEnergyConsumption,
			avgPowerLoading,
			efficiencyMin,efficiencyMedian,efficiencyMax,
			coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
			returnTempMin,returnTempMedian,returnTempMax,
			supplyTempMin,supplyTempMedian,supplyTempMax,
			deltaTempMin,deltaTempMedian,deltaTempMax,
			efficiencyData,
			coolingCapacityData,
			powerConsumptionData,
			returnTempData,
			supplyTempData,
			deltaTempData) 
		VALUES('$startDay','$siteId','$gatewayId', '$chillerNum', '$chillerName',
		'$activityNum','{$activityState}',
		'$totalOperationMinutes',
		'$avgPowerConsumption',
		'$totalEnergyConsumption',
		if($avgPowerLoading is NULL,NULL,'$avgPowerLoading'),
		'$efficiencyMin','$efficiencyMedian','$efficiencyMax',
		if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
		if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
		if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
		'$tempReturnMin','$tempReturnMedian','$tempReturnMax',
		'$tempSupplyMin','$tempSupplyMedian','$tempSupplyMax',
		'$tempDeltaMin','$tempDeltaMedian','$tempDeltaMax',
		'{$efficiencyData}',
		'{$coolingCapacityData}',
		'{$powerConsumptionData}',
		if($tempReturnDataNULL = 1,NULL,'{$tempReturnData}'),
		if($tempSupplyDataNULL = 1,NULL,'{$tempSupplyData}'),
		if($tempDeltaDataNULL = 1,NULL,'{$tempDeltaData}')
		);
		"

programEndTime=$(date "+%Y-%m-%d %H:%M:%S")

st="$(date +%s -d "$programStTime")"
end="$(date +%s -d "$programEndTime")"

sec=$(($end-$st)) 

echo "End Program Run Time $programStTime ~ $programEndTime  花費:$sec"
exit 0
