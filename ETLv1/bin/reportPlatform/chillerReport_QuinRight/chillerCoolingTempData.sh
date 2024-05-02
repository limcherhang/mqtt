#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature"
		echo "		satrt date"
		echo "		satrt time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Return Table"
        exit 1
fi

if [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] || [ "${12}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature"
		echo "		satrt date"
		echo "		satrt time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Return Table"
		exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}

chillerIEEE=${6}

tempSupplyIEEE=${7}
tempSupplyValue=${8}
tempSupplyTable=${9}

tempReturnIEEE=${10}
tempReturnValue=${11}
tempReturnTable=${12}

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
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

chillerTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H:%i') as startTime,date_format(endTime, '%H:%i') as endTime,operationMinutes,operationFlag 
FROM reportplatform.dailyChillerData
WHERE gatewayId=$gwId
and operationDate='$startDay'
and chillerDescription='$chiName'
;
"))

if [ -f "./buf/coolingTempSupply.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
fi

if [ -f "./buf/coolingTempReturn.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempReturn.$startDay.$chillerIEEE.data
fi

if [ -f "./buf/coolingTempDelta.$startDay.$chillerIEEE.data" ]; then
	rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
fi

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

	operationMinutes=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))
	
	operationFlag=${chillerTime[$whileNum]}
	whileNum=$(($whileNum+1))

	tempSupplyCounts=0
	tempReturnCounts=0
	tempDeltaCounts=0
	capacityCounts=0
	
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
	
		echo "${tempData[$dataNum]}" >> ./buf/coolingTempSupply.$startDay.$chillerIEEE.data
		
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

		echo "${tempData[$dataNum]}" >> ./buf/coolingTempReturn.$startDay.$chillerIEEE.data

		dataNum=$(($dataNum+1))
		tempReturnCounts=$(($tempReturnCounts+1))
	done
	
	tempData=($(mysql -h ${host} -D$dbdata -ss -e"select Round(tempReturn-tempSupply,2) as delta
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

		echo "${tempData[$dataNum]}" >> ./buf/coolingTempDelta.$startDay.$chillerIEEE.data
		
		dataNum=$(($dataNum+1))
		tempDeltaCounts=$(($tempDeltaCounts+1))
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
		
		echo "scale=0;$(($tempSupplyCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)" 
		echo "[DEBUG] Cooling Temp Supply FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempSupplyCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)"
		echo "[DEBUG] Cooling Temp Supply ThirdQuatile Num:$tempThirdQuatileNum"	

		rm ./buf/data.$startDay.$chillerIEEE
		
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
		
		echo "scale=0;$(($tempReturnCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)" 
		echo "[DEBUG] Cooling Temp Return FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempReturnCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)"
		echo "[DEBUG] Cooling Temp Return ThirdQuatile Num:$tempThirdQuatileNum"	

		rm ./buf/data.$startDay.$chillerIEEE
		
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
		
		echo "scale=0;$(($tempDeltaCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)" 
		echo "[DEBUG] Cooling Temp Delta FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempDeltaCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$chillerIEEE
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$chillerIEEE | head -n 1 | tail -n 1)"
		echo "[DEBUG] Cooling Temp Delta ThirdQuatile Num:$tempThirdQuatileNum"	

		rm ./buf/data.$startDay.$chillerIEEE
		
		medianNum=$(($tempDeltaCounts/2))
		
		tempDeltaMin="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort| head -n  $tempFirstQuatileNum | tail -n 1)" 
		tempDeltaMedian="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort | head -n $medianNum | tail -n 1)" 
		tempDeltaMax="$(cat ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
		
		rm ./buf/coolingTempDelta.$startDay.$chillerIEEE.data.sort
	fi


	echo "replace INTO dailyCoolingTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyMin,supplyMedian,supplyMax,
		returnMin,returnMedian,returnMax,
		deltaMin,deltaMedian,deltaMax
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiName', '$startDay $startRunTime', '$endDay $endRunTime',
		'$operationMinutes','$operationFlag',
		if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
		if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
		if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
		if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
		if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
		if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
		if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
		if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
		if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
		);
	"
	
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyCoolingTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyMin,supplyMedian,supplyMax,
		returnMin,returnMedian,returnMax,
		deltaMin,deltaMedian,deltaMax
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiName', '$startDay $startRunTime', '$endDay $endRunTime',
		'$operationMinutes','$operationFlag',
		if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
		if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
		if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
		if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
		if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
		if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
		if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
		if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
		if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
		);
	"
done
exit 0
