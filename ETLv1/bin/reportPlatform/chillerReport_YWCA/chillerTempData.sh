#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ]; then
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
	
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"

fi

tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$siteId $Name $chillerNum $chillerName $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp $tempNameSupply tempNameReturn"
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

arrNum=0
dataNum=0
while :
do
	if [ "${chillerTimeData[$dataNum]}" == "" ]; then
		break
	fi
	
	arrNum=$(($arrNum+1))
	
	
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
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT temp
		 FROM 
			$tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameSupply' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
			order by temp desc
	"))
	

	whileNum=0
	while :
	do
		if [ "${tempData[$whileNum]}" == "" ]; then
			break
		fi
		
		echo "${tempData[$whileNum]}" >> ./buf/temp
		
		whileNum=$(($whileNum+1))
	done
	
	sort ./buf/temp > ./buf/temp.sort
	supplyCount="$(cat ./buf/temp.sort | wc -l)" 
	
	if [ $supplyCount == 0 ]; then

		tempSupplyMin=NULL
		tempSupplyMedian=NULL
		tempSupplyMax=NULL
		
	elif [ $supplyCount == 1 ]; then

		tempSupplyMin="$(cat ./buf/temp.sort | head -n  1 | tail -n 1)" 
		tempSupplyMedian="$(cat ./buf/temp.sort | head -n 1 | tail -n 1)" 
		tempSupplyMax="$(cat ./buf/temp.sort | head -n 1 | tail -n 1)" 
	else
		
		echo "scale=0;$(($supplyCount*$tempFirstQuatile))/100"|bc > ./buf/temp.Num
		tempFirstQuatileNum="$(cat ./buf/temp.Num | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempFirstQuatile Num:$tempFirstQuatileNum"
		
		echo "scale=0;$(($supplyCount*$tempThirdQuatile))/100"|bc > ./buf/temp.Num
		tempThirdQuatileNum="$(cat ./buf/temp.Num | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempThirdQuatile Num:$tempThirdQuatileNum"	
		
		medianNum=$(($supplyCount/2))
		
		tempSupplyMin="$(cat ./buf/temp.sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
		tempSupplyMedian="$(cat ./buf/temp.sort | head -n $medianNum | tail -n 1)" 
		tempSupplyMax="$(cat ./buf/temp.sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./buf/*
	fi

	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT temp
		 FROM 
			$tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameReturn' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
			order by temp desc
	"))
	

	whileNum=0
	while :
	do
		if [ "${tempData[$whileNum]}" == "" ]; then
			break
		fi
		
		echo "${tempData[$whileNum]}" >> ./buf/temp
		
		whileNum=$(($whileNum+1))
	done
	
	sort ./buf/temp > ./buf/temp.sort
	returnCount="$(cat ./buf/temp.sort | wc -l)" 
	
	if [ $returnCount == 0 ]; then

		tempReturnMin=NULL
		tempReturnMedian=NULL
		tempReturnMax=NULL
		
	elif [ $returnCount == 1 ]; then

		tempReturnMin="$(cat ./buf/temp.sort | head -n  1 | tail -n 1)" 
		tempReturnMedian="$(cat ./buf/temp.sort | head -n 1 | tail -n 1)" 
		tempReturnMax="$(cat ./buf/temp.sort | head -n 1 | tail -n 1)" 
	else
		
		echo "scale=0;$(($returnCount*$tempFirstQuatile))/100"|bc > ./buf/temp.Num
		tempFirstQuatileNum="$(cat ./buf/temp.Num | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempFirstQuatile Num:$tempFirstQuatileNum"
		
		echo "scale=0;$(($returnCount*$tempThirdQuatile))/100"|bc > ./buf/temp.Num
		tempThirdQuatileNum="$(cat ./buf/temp.Num | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempThirdQuatile Num:$tempThirdQuatileNum"	
		
		rm ./buf/temp.Num
		medianNum=$(($returnCount/2))
		
		tempReturnMin="$(cat ./buf/temp.sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
		tempReturnMedian="$(cat ./buf/temp.sort | head -n $medianNum | tail -n 1)" 
		tempReturnMax="$(cat ./buf/temp.sort  | head -n $tempThirdQuatileNum | tail -n 1)"
		
		rm ./buf/*
	fi

	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"select Round(tempReturn-tempSupply,2) as delta
	from
	(
	SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
	  FROM  $tbTemp 
		 WHERE 
			siteId='$siteId' and
			name='$tempNameSupply' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
	) as a
	INNER join
	(
	  SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn 
	   FROM $tbTemp 
		WHERE 
			siteId='$siteId' and
			name='$tempNameReturn' and 
			ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
			ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
	) as b
	on a.time=b.time
	order by delta desc;
	"))

	whileNum=0
	while :
	do
		if [ "${tempData[$whileNum]}" == "" ]; then
			break
		fi
		
		echo "${tempData[$whileNum]}" >> ./buf/tempDelta
		
		whileNum=$(($whileNum+1))
	done
	
	sort ./buf/tempDelta > ./buf/tempDelta.sort
	tempDeltaCounts="$(cat ./buf/tempDelta.sort | wc -l)" 
	
	#echo "tempDeltaCounts:$tempDeltaCounts"
	
	if [ $tempDeltaCounts == 0 ]; then

		tempDeltaMin=NULL
		tempDeltaMedian=NULL
		tempDeltaMax=NULL
		
	elif [ $tempDeltaCounts == 1 ]; then

		tempDeltaMin="$(cat ./buf/tempDelta.sort | head -n  1 | tail -n 1)" 
		tempDeltaMedian="$(cat ./buf/tempDelta.sort | head -n 1 | tail -n 1)" 
		tempDeltaMax="$(cat ./buf/tempDelta.sort | head -n 1 | tail -n 1)" 
	else
		
		echo "scale=0;$(($tempDeltaCounts*$tempFirstQuatile))/100"|bc > ./buf/tempDelta.Num
		tempFirstQuatileNum="$(cat ./buf/tempDelta.Num | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		#echo "[DEBUG] tempFirstQuatile Num:$tempFirstQuatileNum"
		
		echo "scale=0;$(($tempDeltaCounts*$tempThirdQuatile))/100"|bc > ./buf/tempDelta.Num
		tempThirdQuatileNum="$(cat ./buf/tempDelta.Num | head -n 1 | tail -n 1)"
		#echo "[DEBUG] tempThirdQuatile Num:$tempThirdQuatileNum"	
		
		rm ./buf/tempDelta.Num
		medianNum=$(($tempDeltaCounts/2))
		
		tempDeltaMin="$(cat ./buf/tempDelta.sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
		tempDeltaMedian="$(cat ./buf/tempDelta.sort | head -n $medianNum | tail -n 1)" 
		tempDeltaMax="$(cat ./buf/tempDelta.sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	fi
	
	echo "Operation Date : $startDay"
	echo "Site Id : $siteId"
	echo "Gateway Id : $gatewayId"
	echo "chillerId : $chillerNum"
    echo "chiliierDescription : $chillerName"
	echo "startTime ${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" 
	echo "endTime ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"
	echo "opMinutes : $runMinutes"
	echo "tempSupplyMin : $tempSupplyMin"
	echo "tempSupplyMedian : $tempSupplyMedian"
	echo "tempSupplyMax : $tempSupplyMax"
	echo "tempReturnMin : $tempReturnMin"
	echo "tempReturnMedian : $tempReturnMedian"
	echo "tempReturnMax : $tempReturnMax"
	echo "tempDeltaMin : $tempDeltaMin"
	echo "tempDeltaMedian : $tempDeltaMedian"
	echo "tempDeltaMax : $tempDeltaMax"
	
	echo "replace INTO dailyChillerTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$chillerNum', '$chillerName', '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}', '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}', 
		'$runMinutes','${operationFlag[$arrNum]}',
		if($supplyCount is NULL,NULL,'$supplyCount'),
		if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
		if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
		if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
		if($returnCount is NULL,NULL,'$returnCount'),
		if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
		if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
		if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
		if($tempDeltaCounts is NULL,NULL,'$tempDeltaCounts'),
		if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
		if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
		if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
		);
	"
	
	mysql -h ${host} -D$reportPlatform -ss -e"replace INTO dailyChillerTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$chillerNum', '$chillerName', '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}', '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}', 
		'$runMinutes','${operationFlag[$arrNum]}',
		if($supplyCount is NULL,NULL,'$supplyCount'),
		if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
		if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
		if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
		if($returnCount is NULL,NULL,'$returnCount'),
		if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
		if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
		if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
		if($tempDeltaCounts is NULL,NULL,'$tempDeltaCounts'),
		if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
		if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
		if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
		);
	"
	
	arrNum=$(($arrNum-1))
done
exit 0

