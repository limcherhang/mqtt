#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 207200 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature 00124b000be4cbf5 ultrasonicFlow 255"
		echo "		satrt date"
		echo "		satrt time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo " 		Capacity(W)"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Return Table"
		echo "		Flow IEEE"
		echo "		Flow Table"
		echo " 		Capacity(Ton)"
        exit 1
fi

if [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] || [ "${12}" == "" ] || [ "${13}" == "" ] || [ "${14}" == "" ] || [ "${15}" == "" ] || [ "${16}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 207200 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature 00124b000be4cbf5 ultrasonicFlow 255"
		echo "		satrt date"
		echo "		satrt time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo " 		Capacity(W)"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Return Table"
		echo "		Flow IEEE"
		echo "		Flow Table"
		echo " 		Capacity(Ton)"
		exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}

chillerIEEE=${6}
capacityW=${7}

tempSupplyIEEE=${8}
tempSupplyValue=${9}
tempSupplyTable=${10}

tempReturnIEEE=${11}
tempReturnValue=${12}
tempReturnTable=${13}

flowIEEE=${14}
flowTable=${15}

capacityTon=${16}

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

today=$(date "+%Y-%m-%d" --date="-1 day")
if [ $startDay == $today ]; then
	dbdata="iotmgmt"
else
	dbdata="iotdata"
fi

chiName=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))
chiId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as chillerId FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM gateway_info where gatewayId=$gwId;"))
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$startDay" > ./chillerPerformanceData
echo "$gwId" >> ./chillerPerformanceData
echo "$chiName" >> ./chillerPerformanceData
echo "$chiId" >> ./chillerPerformanceData

#***********************#
#Daily Activity Overview#
#***********************#
echo "Run Daily Activity Overview"
#Activity
activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT count(*) as ActivityCount 
FROM reportplatform.dailyChillerData
WHERE gatewayId=$gwId
and operationDate='$startDay'
and chillerDescription='$chiName';
"))

if [ "$activityNum" == "" ]; then
	echo "0" >> ./chillerPerformanceData
	exit 1
else
	if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
		echo "0" >> ./chillerPerformanceData
		echo "NO activity"
	else
		activityNum=$(($activityNum-1))
		echo "$activityNum" >> ./chillerPerformanceData
	fi 
fi

activityCount="$(cat ./chillerPerformanceData | head -n 5 | tail -n 1)"

#Activity State
if [ $activityCount == 0 ]; then
	echo "0" >> ./chillerPerformanceData
else
	activityState=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as time,operationFlag as PreviousState 
	FROM reportplatform.dailyChillerData
	WHERE gatewayId=$gwId
	and operationDate='$startDay'
	and chillerDescription='$chiName'
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
			printf ",">> ./chillerPerformanceData
		fi
		
		#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
		if [ $state == 1 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./chillerPerformanceData
		elif [ $state == 0 ]; then
			printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./chillerPerformanceData
		fi
		jsonNum=$(($jsonNum+1))
	done

	printf "\n">> ./chillerPerformanceData
fi
#**************************#
#Daily Performance Overview#
#**************************#

echo "Run Daily Performance Overview"
chillerTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H:%i') as startTime,date_format(endTime, '%H:%i') as endTime,totalPowerWh 
FROM reportplatform.dailyChillerData
WHERE gatewayId=$gwId
and operationDate='$startDay'
and chillerDescription='$chiName'
and operationFlag=1
;
"))

whileNum=0

dataCount=0
dataFlowCount=0

totalEnergyConsumption=0
totalRunMinutes=0

if [ "${chillerTime[$whileNum]}" == "" ]; then
	echo "  $chiName $startDay operation OFF"
	echo "0" > ./chillerPerformanceOperation
	rm ./chillerPerformanceData
	rm ./chillerPerformanceOperation
	exit 1
else
	echo "1" > ./chillerPerformanceOperation
fi


while :
do
	if [ "${chillerTime[$whileNum]}" == "" ]; then
		break
	fi
	
	startRunTime=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))

	endRunTime=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))
	
	totalEnergyConsumption=$(($totalEnergyConsumption+${chillerTime[$whileNum]}))
	whileNum=$(($whileNum+1))
	
	echo "  $chiName:$startDay $startRunTime~$startDay $endRunTime:59"

	data=($(mysql -h ${host} -D$dbdata -ss -e"SELECT (IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as watt
		FROM (
		SELECT * FROM pm 
		WHERE ieee='$chillerIEEE' 
		and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59:59'
		)as x  
		where receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
		GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
	;
	"))
	
	dataNum=0
	while :
	do
		if [ "${data[$dataNum]}" == "" ]; then
			break
		fi
		
		echo "${data[$dataNum]}" >> ./buffer/chillerPowerMeterKW
		
		dataNum=$(($dataNum+1))
		dataCount=$(($dataCount+1))
	done
	
	runMinutes_start=$(date -d "$startDay $startRunTime" +%s)
	runMinutes_end=$(date -d "$startDay $endRunTime" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	totalRunMinutes=$(($runMinutes+$totalRunMinutes))
	
done

echo "0"> ./buffer/totalWattBuf
echo "0"> ./buffer/powerLoadingBuf

for ((forNum=1;forNum <=$dataCount;forNum++))
do
	watt="$(cat ./buffer/chillerPowerMeterKW | head -n $forNum | tail -n 1)"
	#efficiency=(watt/Ton)
	echo "scale=2;$watt/$capacityTon"|bc >> ./buffer/efficiency

	#avgPowerLoadingNum=(watt/capacityW)
	powerLoadingNum="$(cat ./buffer/powerLoadingBuf | head -n 1 | tail -n 1)"
	echo "scale=2;$powerLoadingNum+($watt/($capacityW/1000))"|bc > ./buffer/powerLoadingBuf
	
	totalWattNum="$(cat ./buffer/totalWattBuf | head -n 1 | tail -n 1)"
	echo "scale=2;$watt+$totalWattNum"|bc > ./buffer/totalWattBuf
done

totalWatt="$(cat ./buffer/totalWattBuf | head -n 1 | tail -n 1)"


powerLoading="$(cat ./buffer/powerLoadingBuf | head -n 1 | tail -n 1)"

sort -n ./buffer/efficiency > ./buffer/efficiencySort
rm ./buffer/chillerPowerMeterKW
rm ./buffer/efficiency
rm ./buffer/totalWattBuf
rm ./buffer/powerLoadingBuf

				#<=
if [ $dataCount -le 1 ]; then
	efficiencyMin="$(cat ./buffer/efficiencySort | head -n  1 | tail -n 1)" 
	efficiencyMedian="$(cat ./buffer/efficiencySort | head -n 1 | tail -n 1)" 
	efficiencyMax="$(cat ./buffer/efficiencySort  | head -n 1 | tail -n 1)" 
else
	medianNum=$(($dataCount/2))
	efficiencyMin="$(cat ./buffer/efficiencySort | head -n  1 | tail -n 1)" 
	efficiencyMedian="$(cat ./buffer/efficiencySort | head -n $medianNum | tail -n 1)" 
	efficiencyMax="$(cat ./buffer/efficiencySort  | head -n $dataCount | tail -n 1)" 
fi

rm ./buffer/efficiencySort

#total Operation Minutes
echo "$totalRunMinutes" >> ./chillerPerformanceData

#Avg Power Consumption
echo "scale=2;$totalWatt/$dataCount"|bc >> ./chillerPerformanceData

#Total Energy Consumption (kWh) = Average Power Consumption (kW) * No. of
#hours that Chiller is ON (h)
echo "$totalEnergyConsumption" >> ./chillerPerformanceData

#Average power loading (%) = Average power consumption (kW) / Input powerof chiller (kW) * 100
#Avg Power Loading
echo "scale=2;$powerLoading/$dataCount"|bc >> ./chillerPerformanceData

#Efficiency
echo "$efficiencyMin" >> ./chillerPerformanceData
echo "$efficiencyMedian" >> ./chillerPerformanceData
echo "$efficiencyMax" >> ./chillerPerformanceData


pumpTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H:%i') as startTime,date_format(endTime, '%H:%i') as endTime 
FROM reportplatform.dailyChillerTemp
WHERE gatewayId=$gwId
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
	if [ "${pumpTime[$whileNum]}" == "" ]; then
		break
	fi
	
	startRunTime=${pumpTime[$whileNum]}
	whileNum=$(($whileNum+1))

	endRunTime=${pumpTime[$whileNum]}
	whileNum=$(($whileNum+1))

	tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT truncate($tempSupplyValue,2) as tempSupply
		 FROM (
			SELECT * FROM $tempSupplyTable
			WHERE ieee='$tempSupplyIEEE' 
			and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempSupplyValue is not NULL
		 )as x
		 WHERE receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
		GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
	"))
	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi
	
		echo "${tempData[$dataNum]}" >> ./buffer/tempSupplyBuf
		dataNum=$(($dataNum+1))
		tempSupplyCounts=$(($tempSupplyCounts+1))
	done
	
	tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT truncate($tempReturnValue,2) as tempReturn
		FROM (
			SELECT * FROM $tempReturnTable
			WHERE ieee='$tempReturnIEEE' 
			and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempReturnValue is not NULL
		 )as x  
		where receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
		GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
	"))
	
	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi

		echo "${tempData[$dataNum]}" >> ./buffer/tempReturnBuf
		dataNum=$(($dataNum+1))
		tempReturnCounts=$(($tempReturnCounts+1))
	done
	
	tempData=($(mysql -h ${host} -D$dbdata -ss -e"select Round((Round(tempReturn-tempSupply,2))*100,0) as delta
	from
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempSupplyValue,2) as tempSupply
		 FROM (
			SELECT * FROM $tempSupplyTable
			WHERE ieee='$tempSupplyIEEE' 
			and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempSupplyValue is not NULL
		 )as x
		 WHERE receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
		GROUP BY time
	) as a

	INNER join
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempReturnValue,2) as tempReturn
		FROM (
			SELECT * FROM $tempReturnTable
			WHERE ieee='$tempReturnIEEE' 
			and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempReturnValue is not NULL
		 )as x  
		where receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
		GROUP BY time
	) as b
	on a.time=b.time;
	"))
	
	dataNum=0
	while :
	do
		if [ "${tempData[$dataNum]}" == "" ]; then
			break
		fi
		
		echo "${tempData[$dataNum]}" >> ./buffer/tempDeltaBuf
		
		dataNum=$(($dataNum+1))
		tempDeltaCounts=$(($tempDeltaCounts+1))
		
	done
	

	if [ $flowIEEE != 0 ]; then
		coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select Round((Round(tempReturn-tempSupply,2))*100,0) as delta,truncate(flowRate,2)
		from
		(
		SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempSupplyValue,2) as tempSupply
			 FROM (
				SELECT * FROM $tempSupplyTable
				WHERE ieee='$tempSupplyIEEE' 
				and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempSupplyValue is not NULL
			 )as x
			 where receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
			GROUP BY time
		) as a

		INNER join
		(
		SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempReturnValue,2) as tempReturn
			FROM (
				SELECT * FROM $tempReturnTable 
				WHERE ieee='$tempReturnIEEE' 
				and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59' and $tempReturnValue is not NULL
			 )as x  
			where receivedSync>='$startDay $startRunTime' and receivedSync<='$startDay $endRunTime:59'
			GROUP BY time
		) as b
		on a.time=b.time

		INNER join
		(
		SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(flowRate,2) as flowRate
			 FROM (
				SELECT * FROM $flowTable 
				WHERE ieee='$flowIEEE' 
				and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59'
			 )as x 
			where receivedSync>='$startDay $startTime' and receivedSync<='$startDay $endRunTime:59'
			GROUP BY time
		) as c
		on a.time=c.time;
		"))
		
		dataNum=0
		while :
		do
			if [ "${coolingCapacityData[$dataNum]}" == "" ]; then
				break
			fi
			
			deltaData=${coolingCapacityData[$dataNum]}
			dataNum=$(($dataNum+1))
			flowData=${coolingCapacityData[$dataNum]}
			dataNum=$(($dataNum+1))
			
			echo "scale=3;($deltaData*4.2*977*$flowData/(3600*3.5168525))/100"|bc >> ./buffer/coolingCapacityDataBuf

			capacityCounts=$(($capacityCounts+1))
		done
	fi
done


if [ $tempSupplyCounts == 0 ]; then

	tempSupplyMin=NULL
	tempSupplyMedian=NULL
	tempSupplyMax=NULL
	
elif [ $tempSupplyCounts == 1 ]; then

	sort -n ./buffer/tempSupplyBuf > ./buffer/tempSupplySort
	
	tempSupplyMin="$(cat ./buffer/tempSupplySort | head -n  1 | tail -n 1)" 
	tempSupplyMedian="$(cat ./buffer/tempSupplySort | head -n 1 | tail -n 1)" 
	tempSupplyMax="$(cat ./buffer/tempSupplySort  | head -n 1 | tail -n 1)" 
	rm ./buffer/tempSupplyBuf 
	rm ./buffer/tempSupplySort
else

	sort -n ./buffer/tempSupplyBuf > ./buffer/tempSupplySort
	
	echo "scale=0;$(($tempSupplyCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay
	tempFirstQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)" 
	echo "[DEBUG] temp Supply FirstQuatile Num:$tempFirstQuatileNum"
	
	echo "scale=0;$(($tempSupplyCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay
	tempThirdQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)"
	echo "[DEBUG] temp Supply  ThirdQuatile Num:$tempThirdQuatileNum"	
	
	rm ./buf/data.$startDay
	medianNum=$(($tempSupplyCounts/2))
	
	tempSupplyMin="$(cat ./buffer/tempSupplySort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempSupplyMedian="$(cat ./buffer/tempSupplySort | head -n $medianNum | tail -n 1)" 
	tempSupplyMax="$(cat ./buffer/tempSupplySort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	
	rm ./buffer/tempSupplyBuf 
	rm ./buffer/tempSupplySort
fi
 

if [ $tempReturnCounts == 0 ]; then

	tempReturnMin=NULL
	tempReturnMedian=NULL
	tempReturnMax=NULL
	
elif [ $tempReturnCounts == 1 ]; then

	sort -n ./buffer/tempReturnBuf > ./buffer/tempReturnSort
	rm ./buffer/tempReturnBuf
	tempReturnMin="$(cat ./buffer/tempReturnSort | head -n  1 | tail -n 1)" 
	tempReturnMedian="$(cat ./buffer/tempReturnSort | head -n 1 | tail -n 1)" 
	tempReturnMax="$(cat ./buffer/tempReturnSort  | head -n 1 | tail -n 1)" 
	rm ./buffer/tempReturnSort
else

	sort -n ./buffer/tempReturnBuf > ./buffer/tempReturnSort
	
	
	echo "scale=0;$(($tempReturnCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay
	tempFirstQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)" 
	echo "[DEBUG] temp Return FirstQuatile Num:$tempFirstQuatileNum"
	
	echo "scale=0;$(($tempReturnCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay
	tempThirdQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)"
	echo "[DEBUG] temp Return  ThirdQuatile Num:$tempThirdQuatileNum"	
	
	rm ./buf/data.$startDay
	
	medianNum=$(($tempReturnCounts/2))
	tempReturnMin="$(cat ./buffer/tempReturnSort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempReturnMedian="$(cat ./buffer/tempReturnSort | head -n $medianNum | tail -n 1)" 
	tempReturnMax="$(cat ./buffer/tempReturnSort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	
	rm ./buffer/tempReturnBuf
	rm ./buffer/tempReturnSort
fi



if [ $tempDeltaCounts == 0 ]; then

	tempDeltaMin=NULL
	tempDeltaMedian=NULL
	tempDeltaMax=NULL
	
elif [ $tempDeltaCounts == 1 ]; then
	sort -n ./buffer/tempDeltaBuf > ./buffer/tempDeltaSort
	rm ./buffer/tempDeltaBuf
	tempDeltaMin="$(cat ./buffer/tempDeltaSort | head -n  1 | tail -n 1)" 
	tempDeltaMedian="$(cat ./buffer/tempDeltaSort | head -n 1 | tail -n 1)" 
	tempDeltaMax="$(cat ./buffer/tempDeltaSort  | head -n 1 | tail -n 1)" 
	rm ./buffer/tempDeltaSort
else
	sort -n ./buffer/tempDeltaBuf > ./buffer/tempDeltaSort
	
	echo "scale=0;$(($tempDeltaCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay
	tempFirstQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)" 
	echo "[DEBUG] temp Delta FirstQuatile Num:$tempFirstQuatileNum"
	
	echo "scale=0;$(($tempDeltaCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay
	tempThirdQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)"
	echo "[DEBUG] temp Delta  ThirdQuatile Num:$tempThirdQuatileNum"	
	rm ./buf/data.$startDay
	
	medianNum=$(($tempDeltaCounts/2))
	tempDeltaMin="$(cat ./buffer/tempDeltaSort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempDeltaMedian="$(cat ./buffer/tempDeltaSort | head -n $medianNum | tail -n 1)" 
	tempDeltaMax="$(cat ./buffer/tempDeltaSort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	
	rm ./buffer/tempDeltaBuf
	rm ./buffer/tempDeltaSort
fi

if [ $capacityCounts == 0 ]; then

	coolingCapacityMin=NULL
	coolingCapacityMedian=NULL
	coolingCapacityMax=NULL
	
elif [ $capacityCounts == 1 ]; then

	sort -n ./buffer/coolingCapacityDataBuf > ./buffer/coolingCapacityDataSort
	rm ./buffer/coolingCapacityDataBuf
	
	coolingCapacityMin="$(cat ./buffer/coolingCapacityDataSort | head -n  1 | tail -n 1)" 
	coolingCapacityMedian="$(cat ./buffer/coolingCapacityDataSort | head -n 1 | tail -n 1)" 
	coolingCapacityMax="$(cat ./buffer/coolingCapacityDataSort  | head -n 1 | tail -n 1)" 
	
	#cp ./buffer/coolingCapacityDataSort ./bug/coolingCapacityDataSort
	rm ./buffer/coolingCapacityDataSort
else

	sort -n ./buffer/coolingCapacityDataBuf > ./buffer/coolingCapacityDataSort
	rm ./buffer/coolingCapacityDataBuf
	
	echo "scale=0;$(($capacityCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay
	tempFirstQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)" 
	echo "[DEBUG] temp Delta FirstQuatile Num:$tempFirstQuatileNum"
	
	echo "scale=0;$(($capacityCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay
	tempThirdQuatileNum="$(cat ./buf/data.$startDay | head -n 1 | tail -n 1)"
	echo "[DEBUG] temp Delta  ThirdQuatile Num:$tempThirdQuatileNum"	
	rm ./buf/data.$startDay
	
	medianNum=$(($capacityCounts/2))
	coolingCapacityMin="$(cat ./buffer/coolingCapacityDataSort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	coolingCapacityMedian="$(cat ./buffer/coolingCapacityDataSort | head -n $medianNum | tail -n 1)" 
	coolingCapacityMax="$(cat ./buffer/coolingCapacityDataSort  | head -n $tempThirdQuatileNum | tail -n 1)" 
	
	#cp ./buffer/coolingCapacityDataSort ./bug/coolingCapacityDataSort
	rm ./buffer/coolingCapacityDataSort
fi

#Output Data
#CoolingCapacity(RT)
echo "$coolingCapacityMin" >> ./chillerPerformanceData
echo "$coolingCapacityMedian" >> ./chillerPerformanceData
echo "$coolingCapacityMax" >> ./chillerPerformanceData

#ChilledWaterSupplyTemp(°C)
echo "$tempSupplyMin" >> ./chillerPerformanceData
echo "$tempSupplyMedian" >> ./chillerPerformanceData
echo "$tempSupplyMax" >> ./chillerPerformanceData

#ChilledWaterReturnTemp(°C)
echo "$tempReturnMin" >> ./chillerPerformanceData
echo "$tempReturnMedian" >> ./chillerPerformanceData
echo "$tempReturnMax" >> ./chillerPerformanceData

#ChilledWaterDeltaTemp(°C)
echo "scale=2;$tempDeltaMin/100"|bc >> ./chillerPerformanceData
echo "scale=2;$tempDeltaMedian/100"|bc >> ./chillerPerformanceData
echo "scale=2;$tempDeltaMax/100"|bc >> ./chillerPerformanceData

#*************************#
#Daily Performance Details#
#*************************#
echo "Run Daily Performance Details"
chillerDetailTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
FROM reportplatform.dailyChillerData
WHERE gatewayId=$gwId
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
				printf ",">> ./powerConsumptionDetailData
				printf ",">> ./efficiencyDetailData
				printf ",">> ./coolingCapacityDetailData
			fi
			
			#data watt
			data=($(mysql -h ${host} -D$dbdata -ss -e"SELECT (IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as watt
				FROM (
					SELECT * FROM pm 
						WHERE ieee='$chillerIEEE' 
							and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59:59'
					)as x  
				where receivedSync>='$startDay $stHour:$stMin' and receivedSync<='$startDay $endHour:$endMin:59'
				GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				;
			"))
			
			dataNum=0
			while :
			do
				if [ "${data[$dataNum]}" == "" ]; then
				break
				fi

				echo "${data[$dataNum]}" >> ./buffer/dataWattDetailBuf
				#efficiency=(watt/Ton)
				echo "scale=2;${data[$dataNum]}/$capacityTon"|bc >> ./buffer/efficiencyDetailBuf
				dataNum=$(($dataNum+1))
			done
			
			if [ -f "./buffer/efficiencyDetailBuf" ]; then
				sort ./buffer/dataWattDetailBuf >> ./buffer/dataWattDetailBufSort
				sort ./buffer/efficiencyDetailBuf >> ./buffer/efficiencyDetailBufSort
				
				rm ./buffer/dataWattDetailBuf
				rm ./buffer/efficiencyDetailBuf
				
				if [ $dataNum -le 1 ]; then
					powerConsumptionDetail="$(cat ./buffer/dataWattDetailBufSort | head -n 1 | tail -n 1)" 
					efficiencyDetail="$(cat ./buffer/efficiencyDetailBufSort | head -n 1 | tail -n 1)"
				else
					medianNum=$(($dataNum/2))
					powerConsumptionDetail="$(cat ./buffer/dataWattDetailBufSort | head -n $medianNum | tail -n 1)" 
					efficiencyDetail="$(cat ./buffer/efficiencyDetailBufSort | head -n $medianNum | tail -n 1)"
				fi
				
				rm ./buffer/dataWattDetailBufSort
				rm ./buffer/efficiencyDetailBufSort
			else
				echo "[ERROR]Watt '$startDay $stHour:$stMin' ~ receivedSync<='$startDay $endHour:$endMin:59 is no data"
				powerConsumptionDetail=0 
				efficiencyDetail=0
			fi
			
			if [ $flowIEEE != 0 ]; then
			
				deltaDetailData=($(mysql -h ${host} -D$dbdata -ss -e"select Round((Round(tempReturn-tempSupply,2))*100,0) as delta,flowRate
				from
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempSupplyValue,2) as tempSupply
					 FROM (
						SELECT * FROM $tempSupplyTable
						WHERE ieee='$tempSupplyIEEE' 
						and receivedSync>='$startDay 00:00' and 
						receivedSync<='$startDay 23:59' and 
						$tempSupplyValue >= 0 and
						$tempSupplyValue is not NULL
					 )as x
					 where receivedSync>='$startDay $stHour:$stMin' and receivedSync<='$startDay $endHour:$endMin:59'
					GROUP BY time
				) as a

				INNER join
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempReturnValue,2) as tempReturn
					FROM (
						SELECT * FROM $tempReturnTable
						WHERE ieee='$tempReturnIEEE' 
						and receivedSync>='$startDay 00:00' and 
						receivedSync<='$startDay 23:59' and 
						$tempReturnValue >= 0 and
						$tempReturnValue is not NULL
					 )as x  
					where receivedSync>='$startDay $stHour:$stMin' and receivedSync<='$startDay $endHour:$endMin:59'
					GROUP BY time
				) as b
				on a.time=b.time
				
				INNER join
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(flowRate,2) as flowRate
					 FROM (
						SELECT * FROM $flowTable 
						WHERE ieee='$flowIEEE' and 
						receivedSync>='$startDay 00:00' and 
						receivedSync<='$startDay 23:59'and 
						flowRate >= 0 and
						flowRate is not NULL
					 )as x 
					where receivedSync>='$startDay $stHour:$stMin' and receivedSync<='$startDay $endHour:$endMin:59'
					GROUP BY time
				) as c
				on a.time=c.time;
				"))
		
				dataNum=0
				while :
				do
					if [ "${deltaDetailData[$dataNum]}" == "" ]; then
						break
					fi
					
					deltaData=${deltaDetailData[$dataNum]}
					dataNum=$(($dataNum+1))
					flowData=${deltaDetailData[$dataNum]}
					dataNum=$(($dataNum+1))
					
					#echo "deltaData=$deltaData flowData=$flowData"
					echo "scale=3;($deltaData*4.2*977*$flowData/(3600*3.5168525))/100"|bc >> ./buffer/coolingCapacityDetailBuf
				done
			fi
			
			if [ -f "./buffer/coolingCapacityDetailBuf" ]; then
				sort ./buffer/coolingCapacityDetailBuf >> ./buffer/coolingCapacityDetailSort
				rm ./buffer/coolingCapacityDetailBuf
				
				if [ $dataNum -le 1 ]; then
					coolingCapacityDetail="$(cat ./buffer/coolingCapacityDetailSort | head -n 1 | tail -n 1)" 
				else
					medianNum=$(($dataNum/2))
					coolingCapacityDetail="$(cat ./buffer/coolingCapacityDetailSort | head -n $medianNum | tail -n 1)" 
				fi
				
				rm ./buffer/coolingCapacityDetailSort
			else
				#echo "[ERROR]Cooling Capacity Detail '$startDay $stHour:$stMin' ~ receivedSync<='$startDay $endHour:$endMin:59 is no data"
				coolingCapacityDetail=NULL
			fi
			
			# Efficiency(kw/Ton)
			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.02f}" $jsonNum $stHour $stMin $endHour $endMin $efficiencyDetail >> ./efficiencyDetailData
			
			if [ "$coolingCapacityDetail" == "NULL" ]; then
				# Cooling Capacity(RT)
				echo "NULL" > ./coolingCapacityDetailData
			else
				printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour $stMin $endHour $endMin $coolingCapacityDetail >> ./coolingCapacityDetailData	
			fi
			
			# Power Consumption(kW)
			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour $stMin $endHour $endMin $powerConsumptionDetail >> ./powerConsumptionDetailData
		fi

		stHour=$(($stHour+1))
	done
	#next time
done

#
# temp Supply Hours
#
echo "bash ./tempDataHours.sh $startDay $startTime $endDay $endTime $tempSupplyIEEE $tempSupplyValue $tempSupplyTable"
bash ./tempDataHours.sh $startDay $startTime $endDay $endTime $tempSupplyIEEE $tempSupplyValue $tempSupplyTable

if [ -f "./data/tempHours.$startDay.$tempSupplyIEEE" ]; then
	cp ./data/tempHours.$startDay.$tempSupplyIEEE ./data/tempSupplyHours.$gwId.$startDay
	rm ./data/tempHours.$startDay.$tempSupplyIEEE
fi

#
# temp Return Hours
#
echo "bash ./tempDataHours.sh $startDay $startTime $endDay $endTime $tempReturnIEEE $tempReturnValue $tempReturnTable"
bash ./tempDataHours.sh $startDay $startTime $endDay $endTime $tempReturnIEEE $tempReturnValue $tempReturnTable


if [ -f "./data/tempHours.$startDay.$tempReturnIEEE" ]; then
	cp ./data/tempHours.$startDay.$tempReturnIEEE ./data/tempReturnHours.$gwId.$startDay
	rm ./data/tempHours.$startDay.$tempReturnIEEE
fi

#
# temp Delta Hours
#
echo "bash ./tempDeltaDataHours.sh $startDay $startTime $endDay $endTime $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable"
bash ./tempDeltaDataHours.sh $startDay $startTime $endDay $endTime $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable


if [ -f "./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE" ]; then
	cp ./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE ./data/tempDeltaHours.$gwId.$startDay
	rm ./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE
fi

echo "bash ./insertChillerPerformance.sh"
bash ./insertChillerPerformance.sh
	
echo "End Program"
exit 0
