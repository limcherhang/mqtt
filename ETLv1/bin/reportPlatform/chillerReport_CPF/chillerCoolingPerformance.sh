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
gwId=${9}
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



chiName=$chillerName
chiId=$chillerNum

tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

#**************************#
#Daily Performance Overview#
#**************************#

echo "Run Daily Performance Overview"

if [ -f "./buf/coolingTempSupply.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
fi

if [ -f "./buf/coolingTempReturn.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data
fi

if [ -f "./buf/coolingTempDelta.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
fi

chillerTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H:%i') as startTime,date_format(endTime, '%H:%i') as endTime 
FROM reportplatform.dailyChillerData
WHERE siteId=$siteId
and operationDate='$startDay'
and chillerDescription='$chiName'
and operationFlag=1
;
"))

whileNum=0
tempSupplyCounts=0
tempReturnCounts=0
tempDeltaCounts=0
capacityCounts=0

while :
do
	if [ "${chillerTime[$whileNum]}" == "" ]; then
		break
	fi
	
	startRunTime=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))

	endRunTime=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))

	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT
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
	
		echo "${tempData[$dataNum]}" >> ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
		
		dataNum=$(($dataNum+1))
		tempSupplyCounts=$(($tempSupplyCounts+1))
	done
	
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT
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

		echo "${tempData[$dataNum]}" >> ./buf/coolingTempReturn.$startDay.$chillerIEEE.data

		dataNum=$(($dataNum+1))
		tempReturnCounts=$(($tempReturnCounts+1))
	done
	
	tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
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

		echo "${tempData[$dataNum]}" >> ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
		
		dataNum=$(($dataNum+1))
		tempDeltaCounts=$(($tempDeltaCounts+1))
	done

done

if [ $tempSupplyCounts == 0 ]; then

	tempSupplyMin=NULL
	tempSupplyMedian=NULL
	tempSupplyMax=NULL
	
elif [ $tempSupplyCounts == 1 ]; then

	sort -n ./buf/coolingTempSupply.$startDay.$chillerIEEE.data > ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort
	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
	
	tempSupplyMin="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort | head -n  1 | tail -n 1)" 
	tempSupplyMedian="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort | head -n 1 | tail -n 1)" 
	tempSupplyMax="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort  | head -n 1 | tail -n 1)" 
	
	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort
else

	sort -n ./buf/coolingTempSupply.$startDay.$chillerIEEE.data > ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort
	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
	
	echo "scale=0;$(($tempSupplyCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId| head -n 1 | tail -n 1)" 
	echo "[DEBUG] Cooling Temp Supply FirstQuatile Num:$tempFirstQuatileNum"

	echo "scale=0;$(($tempSupplyCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId | head -n 1 | tail -n 1)"
	echo "[DEBUG] Cooling Temp Supply ThirdQuatile Num:$tempThirdQuatileNum"	

	rm ./buf/data.$startDay.$gwId.$chiId
					
	medianNum=$(($tempSupplyCounts/2))
	
	tempSupplyMin="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempSupplyMedian="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort | head -n $medianNum | tail -n 1)" 
	tempSupplyMax="$(cat ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort  | head -n $tempThirdQuatileNum | tail -n 1)" 

	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data.Sort
fi
 

if [ $tempReturnCounts == 0 ]; then

	tempReturnMin=NULL
	tempReturnMedian=NULL
	tempReturnMax=NULL
	
elif [ $tempReturnCounts == 1 ]; then

	sort -n ./buf/coolingTempReturn.$startDay.$chillerIEEE.data > ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data
	
	tempReturnMin="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort  | head -n  1 | tail -n 1)" 
	tempReturnMedian="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort  | head -n 1 | tail -n 1)" 
	tempReturnMax="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort  | head -n 1 | tail -n 1)" 
	
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort
else

	sort -n ./buf/coolingTempReturn.$startDay.$chillerIEEE.data > ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data
	
	echo "scale=0;$(($tempReturnCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId| head -n 1 | tail -n 1)" 
	echo "[DEBUG] Cooling Temp Return FirstQuatile Num:$tempFirstQuatileNum"

	echo "scale=0;$(($tempReturnCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId | head -n 1 | tail -n 1)"
	echo "[DEBUG] Cooling Temp Return ThirdQuatile Num:$tempThirdQuatileNum"	

	rm ./buf/data.$startDay.$gwId.$chiId
	
	medianNum=$(($tempReturnCounts/2))
	
	tempReturnMin="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempReturnMedian="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort| head -n $medianNum | tail -n 1)" 
	tempReturnMax="$(cat ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data.Sort
fi



if [ $tempDeltaCounts == 0 ]; then

	tempDeltaMin=NULL
	tempDeltaMedian=NULL
	tempDeltaMax=NULL
	
elif [ $tempDeltaCounts == 1 ]; then
	sort -n ./buf/coolingTempDelta.$startDay.$chillerIEEE.data > ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
	tempDeltaMin="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort | head -n  1 | tail -n 1)" 
	tempDeltaMedian="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort | head -n 1 | tail -n 1)" 
	tempDeltaMax="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort  | head -n 1 | tail -n 1)" 
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort
else
	sort -n ./buf/coolingTempDelta.$startDay.$chillerIEEE.data > ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
	
	echo "scale=0;$(($tempDeltaCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId| head -n 1 | tail -n 1)" 
	echo "[DEBUG] Cooling Temp Delta FirstQuatile Num:$tempFirstQuatileNum"

	echo "scale=0;$(($tempDeltaCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gwId.$chiId
	tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gwId.$chiId | head -n 1 | tail -n 1)"
	echo "[DEBUG] Cooling Temp Delta ThirdQuatile Num:$tempThirdQuatileNum"	

	rm ./buf/data.$startDay.$gwId.$chiId

	medianNum=$(($tempDeltaCounts/2))
	
	tempDeltaMin="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort| head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempDeltaMedian="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort | head -n $medianNum | tail -n 1)" 
	tempDeltaMax="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort
fi


#*************************#
#Daily Performance Details#
#*************************#
echo "Run Daily Performance Details"

if [ -f "./data/coolingTempSupply.$startDay.$chillerIEEE.data" ]; then
	rm ./data/coolingTempSupply.$startDay.$chillerIEEE.data
fi

if [ -f "./data/coolingTempReturn.$startDay.$chillerIEEE.data" ]; then
	rm ./data/coolingTempReturn.$startDay.$chillerIEEE.data
fi

if [ -f "./data/coolingTempDelta.$startDay.$chillerIEEE.data" ]; then
	rm ./data/coolingTempDelta.$startDay.$chillerIEEE.data
fi

chillerDetailTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
FROM reportplatform.dailyChillerData
WHERE siteId=$siteId
and operationDate='$startDay'
and chillerDescription='$chiName'
and operationFlag=1
;
"))



whileNum=0
jsonNum=0
while :
do
	if [ "${chillerDetailTime[$whileNum]}" == "" ]; then
		break
	fi

	runStartHour=${chillerDetailTime[$whileNum]}
	runStartHour=$((10#$runStartHour))
	whileNum=$(($whileNum+1))
	
	runStartMin=${chillerDetailTime[$whileNum]}
	runStartMin=$((10#$runStartMin))
	whileNum=$(($whileNum+1))
	
	runEndHour=${chillerDetailTime[$whileNum]}
	runEndHour=$((10#$runEndHour))
	whileNum=$(($whileNum+1))
	
	runEndMin=${chillerDetailTime[$whileNum]}
	runEndMin=$((10#$runEndMin))
	whileNum=$(($whileNum+1))

	stHour=0
	stMin=0
	endHour=0
	endMin=0
	#echo "$runStartHour:$runStartMin ~ $runEndHour:$runEndMin"
	while :
	do
		if [ $stHour == 25 ]; then
		 break
		fi
		
		#stHour >= runStartHour and  stHour <= runStartHour
		if [ $stHour -ge $runStartHour ] && [ $stHour -le $runEndHour ]; then
			
			if [ $stHour == $runEndHour ]; then
			
				if [ $runEndMin == 0 ]; then
					echo "End time"
					break
				fi
				
				endHour=$stHour
				stMin=0
				endMin=$runEndMin
			else
				endHour=$(($stHour+1))
				checkMin=$(($endHour-$runStartHour))
				
				if [ $checkMin == 1 ]; then
					stMin=$runStartMin
				else
					stMin=0
				fi
			fi
			
			#echo "$stHour:$stMin ~ $endHour:$endMin"
			#JSON formeat
			jsonNum=$(($jsonNum+1))
						  #>=
			if [ $jsonNum -ge 2 ]; then
				printf ",">> ./data/coolingTempSupply.$startDay.$chillerIEEE.data
				printf ",">> ./data/coolingTempReturn.$startDay.$chillerIEEE.data
				printf ",">> ./data/coolingTempDelta.$startDay.$chillerIEEE.data
			fi
			
			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT
					avg(temp)
				 FROM 
					$tbTemp 
				 WHERE 
					siteId='$siteId' and
					name='$tempNameSupply' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin:59'
			"))
			
			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.02f}" $jsonNum $stHour $stMin $endHour $endMin $tempData >> ./data/coolingTempSupply.$startDay.$chillerIEEE.data
			
			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT
					avg(temp)
				 FROM 
					$tbTemp 
				 WHERE 
					siteId='$siteId' and
					name='$tempNameReturn' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin:59'
			"))
				
			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.02f}" $jsonNum $stHour $stMin $endHour $endMin $tempData >> ./data/coolingTempReturn.$startDay.$chillerIEEE.data
			
			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
				Round(tempReturn-tempSupply,2) as delta
			from
			(
			SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
			  FROM  $tbTemp 
				 WHERE 
					siteId='$siteId' and
					name='$tempNameSupply' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin:59'
			) as a
			INNER join
			(
			  SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn 
			   FROM $tbTemp 
				WHERE 
					siteId='$siteId' and
					name='$tempNameReturn' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin:59'
			) as b
			on a.time=b.time
			;"))
			

			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.02f}" $jsonNum $stHour $stMin $endHour $endMin $tempData >> ./data/coolingTempDelta.$startDay.$chillerIEEE.data
		fi

		stHour=$(($stHour+1))
	done
	#next time
done

supplyTempDataNULL=0
if [ -f "./data/coolingTempSupply.$startDay.$chillerIEEE.data" ]; then
	supplyTempData="$(cat ./data/coolingTempSupply.$startDay.$chillerIEEE.data  | head -n 1 | tail -n 1)"
else
	supplyTempDataNULL=1
fi

returnTempDataNULL=0
if [ -f "./data/coolingTempReturn.$startDay.$chillerIEEE.data" ]; then
	returnTempData="$(cat ./data/coolingTempReturn.$startDay.$chillerIEEE.data  | head -n 1 | tail -n 1)"
else
	returnTempDataNULL=1
fi

deltaTempDataNULL=0
if [ -f "./data/coolingTempDelta.$startDay.$chillerIEEE.data" ]; then
	deltaTempData="$(cat ./data/coolingTempDelta.$startDay.$chillerIEEE.data | head -n 1 | tail -n 1)"
else
	deltaTempDataNULL=1
fi





echo "replace INTO dailyCoolingPerformance(
	operationDate,siteId,gatewayId,chillerId,chillerDescription,
	supplyTempMin,supplyTempMedian,supplyTempMax,
	returnTempMin,returnTempMedian,returnTempMax,
	deltaTempMin,deltaTempMedian,deltaTempMax,
	supplyTempData,
	returnTempData,
	deltaTempData
	) 
	VALUES(
	'$startDay','$siteId','$gwId', '$chiId', '$chiName',
	if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
	if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
	if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
	if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
	if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
	if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
	if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
	if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
	if($tempDeltaMax is NULL,NULL,'$tempDeltaMax'),
	if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
	if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
    if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
	);
"
mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyCoolingPerformance(
	operationDate,siteId,gatewayId,chillerId,chillerDescription,
	supplyTempMin,supplyTempMedian,supplyTempMax,
	returnTempMin,returnTempMedian,returnTempMax,
	deltaTempMin,deltaTempMedian,deltaTempMax,
	supplyTempData,
	returnTempData,
	deltaTempData
	) 
	VALUES(
	'$startDay','$siteId','$gwId', '$chiId', '$chiName',
	if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
	if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
	if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
	if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
	if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
	if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
	if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
	if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
	if($tempDeltaMax is NULL,NULL,'$tempDeltaMax'),
	if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
	if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
    if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
	);
"
exit 0
