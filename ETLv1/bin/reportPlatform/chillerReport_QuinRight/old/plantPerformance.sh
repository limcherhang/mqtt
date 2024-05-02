#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106"
		echo "		satrt date"
		echo "		satrt time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gId=${5}

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

today=$(date "+%Y-%m-%d" --date="-1 day")

historyTable=0
if [ $startDay == $today ]; then

	dbdata="iotmgmt"
	pmTable=pm
	
else
	#dbdata="iotdata"
	
	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	pmTable=pm_$dbdataMonth

	dbdata="iotdata$dbdataYear"
	historyTable=1
fi

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata Table_$dbdataMonth pmTable $pmTable"

siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gId;"))
FirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
ThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "  ----------------Chiller Info--------------------- "
#Chiller Info
DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'Chiller#%'
order by deviceNum asc
;
"))

chillerNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'Chiller#%'
;
"))

echo "  Chiller Num:$chillerNum"

whileNum=0
arrNum=0
while :
do

	if [ $arrNum == $chillerNum ]; then
		break
	fi
	
	chillerDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	chillerId[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	chillerIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	chillerTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))

	chillerW[$arrNum]=$(mysql -h ${host} -D$dbRPF -ss -e"SELECT 
		capacityKw*1000 as capacityW
	 FROM 
		vChillerInfo
	   where 
		gatewayId=$gId and chillerId=${chillerId[$arrNum]};
	")
	
	chillerTon[$arrNum]=$(mysql -h ${host} -D$dbRPF -ss -e"SELECT 
		capacityTon
	 FROM 
		vChillerInfo
	   where 
		gatewayId=$gId and chillerId=${chillerId[$arrNum]};
	")
	echo "  ${chillerDesc[$arrNum]} ${chillerId[$arrNum]} ${chillerIEEE[$arrNum]} ${chillerTable[$arrNum]}"
		
	arrNum=$(($arrNum+1))
done

echo " "
echo "  -----------------Chiller Main Switchboard Power Info-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'ChillerPumpCooling#%'
order by deviceNum asc
;
"))

ChillerPumpCoolingNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'ChillerPumpCooling#%'
;
"))

echo "  Chiller Water Pump Cooling Num:$ChillerPumpCoolingNum"

whileNum=0
arrNum=0
while :
do

	if [ $arrNum == $ChillerPumpCoolingNum ]; then
		break
	fi

	pumpCoolingDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpCoolingId[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpCoolingIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpCoolingTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	echo "  ${pumpCoolingDesc[$arrNum]} ${pumpCoolingId[$arrNum]} ${pumpCoolingIEEE[$arrNum]} ${pumpCoolingTable[$arrNum]} "
	
	arrNum=$(($arrNum+1))
done
echo " "
echo "  -----------------Chiller Water Flow-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc != 'ChilledWaterFlow#HDR' and
		deviceDesc like 'ChilledWaterFlow#%'
	order by deviceDesc asc
	;
"))
	
chilledWaterFlowNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc != 'ChilledWaterFlow#HDR' and
	deviceDesc like 'ChilledWaterFlow#%'
;
")

echo "  Chiller Water Flow Num:$chilledWaterFlowNum"

arrNum=0
whileNum=0
while :
do
	if [ $arrNum == $chilledWaterFlowNum ]; then
		break
	fi
	
	flowIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	flowTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	flowDeviceDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))

	echo "  ${flowDeviceDesc[$arrNum]}  ${flowIEEE[$arrNum]} ${flowTable[$arrNum]}"
	
	arrNum=$(($arrNum+1))
done
echo "  -----------------Temp Info-------------------- "
coolingSupplyNum=0
coolingReturnNum=0
arrNum=0
while :
do
	
	if [ $arrNum == $chillerNum ]; then
		break
	fi
	echo "  chiller Id:${chillerId[$arrNum]}"
	
		DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,value1,value2,value3,value4
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		(
			deviceDesc like 'ChilledWaterTempReturn#${chillerId[$arrNum]}' or
			deviceDesc like 'ChilledWaterTempSupply#${chillerId[$arrNum]}' or
			deviceDesc like 'ChilledWaterTemp#${chillerId[$arrNum]}' or
			deviceDesc like 'CoolingWaterTempReturn#${chillerId[$arrNum]}' or
			deviceDesc like 'CoolingWaterTempSupply#${chillerId[$arrNum]}' or
			deviceDesc like 'CoolingWaterTemp#${chillerId[$arrNum]}'
		)
	;
	"))
	
	deviceNum=0
	while :
	do
		if [ "${DeviceInfoBuf[$deviceNum]}" == "" ]; then
		 break
		fi
		
		deviceIEEE=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		deviceTable=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		
		deviceTempName[0]=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		
		deviceTempName[1]=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		
		deviceTempName[2]=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		
		deviceTempName[3]=${DeviceInfoBuf[$deviceNum]}
		deviceNum=$(($deviceNum+1))
		
		#echo "  $deviceIEEE $deviceTable ${deviceTempName[0]} ${deviceTempName[1]} ${deviceTempName[2]} ${deviceTempName[3]}"

		for forNum in {0..3};
		do
			#echo "$forNum"
			if [ "$deviceTable" == "ain" ]; then
				tempValue="value$(($forNum+1))"
			else
				tempValue="temp$(($forNum+1))"
			fi
			
			if [ "${deviceTempName[$forNum]}" != "N/A" ]; then
				
				case ${deviceTempName[$forNum]} in
				
				TempChilledWaterReturn)
					returnValue[$arrNum]=$tempValue
					returnIEEE[$arrNum]=$deviceIEEE
					returnTable[$arrNum]=$deviceTable
					deviceDesc="TempChilledWaterReturn#${chillerId[$arrNum]}"
					echo "  $deviceDesc ${returnIEEE[$arrNum]} ${returnTable[$arrNum]} ${returnValue[$arrNum]}"
				 ;;
				TempChilledWaterSupply)
					supplyValue[$arrNum]=$tempValue
					supplyIEEE[$arrNum]=$deviceIEEE
					supplyTable[$arrNum]=$deviceTable
					deviceDesc="TempChilledWaterSupply#${chillerId[$arrNum]}"
					echo "  $deviceDesc ${supplyIEEE[$arrNum]} ${supplyTable[$arrNum]} ${supplyValue[$arrNum]}"
				 ;;
				# TempCoolingWaterSupply)

					# coolingSupplyValue[$arrNum]=$tempValue
					# coolingSupplyIEEE[$arrNum]=$deviceIEEE
					# coolingSupplyTable[$arrNum]=$deviceTable

					# deviceDesc="TempCoolingWaterSupply#${chillerId[$arrNum]}"
					# echo "  $deviceDesc ${coolingSupplyIEEE[$arrNum]} ${coolingSupplyTable[$arrNum]} ${coolingSupplyValue[$arrNum]}"
					# coolingSupplyNum=1
				 # ;;
				# TempCoolingWaterReturn)

					# coolingReturnValue[$arrNum]=$tempValue
					# coolingReturnIEEE[$arrNum]=$deviceIEEE
					# coolingReturnTable[$arrNum]=$deviceTable

					# deviceDesc="TempCoolingWaterReturn#${chillerId[$arrNum]}"
					# echo "  $deviceDesc ${coolingReturnIEEE[$arrNum]} ${coolingReturnTable[$arrNum]} ${coolingReturnValue[$arrNum]}"
					# coolingReturnNum=1
				 # ;;
				*)
				 ;;
				esac

			fi
		done
	done
	echo " "
	arrNum=$(($arrNum+1))
done

echo " "
echo "#***********************#"
echo "#Daily Plant Performance#"
echo "#***********************#"
echo " "


arrNum=0
totalEnergyConsumption=0
while :
do

	if [ $arrNum == $ChillerPumpCoolingNum ]; then
		break
	fi

	totalEnergyConsumption=($(mysql -h ${host} -D$dbdata -ss -e"
	select
		$totalEnergyConsumption+Round(if((Max(totalPositiveWattHour)-Min(totalPositiveWattHour)) is NULL,0,(Max(totalPositiveWattHour)-Min(totalPositiveWattHour))/1000),2) as totalW
	FROM
		 $pmTable
	WHERE ieee='${pumpCoolingIEEE[$arrNum]}' and
		  receivedSync >='$startDay $startTime' and
		  receivedSync <'$endDay $endTime' 
	"))

	echo "  ${pumpCoolingIEEE[$arrNum]} $totalEnergyConsumption "
	
	arrNum=$(($arrNum+1))
done
echo ""
echo "  Total Energy Consumption:$totalEnergyConsumption"
echo ""

if [ "$totalEnergyConsumption" == "NULL" ]; then
	totalEnergyConsumption=0
	echo "  totalEnergyConsumption is NULL"
fi

#utilization
TotalPossible=$(($chillerNum+$ChillerPumpCoolingNum))

utilization=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round((sum(operationMinutes)/60)/($TotalPossible*24)*100,2)  FROM(
    SELECT chillerDescription,operationMinutes FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT description,operationMinutes FROM reportplatform.dailyChillerPumpCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
) as a
"))
if [ "$utilization" == "NULL" ]; then
	utilization=0
	echo "[ERROR]utilization is NULL"
fi

echo ""
echo "[DEBUG]TotalPossible $TotalPossible=$chillerNum+$ChillerPumpCoolingNum"
echo "[DEBUG]TotalEnergyConsumption $totalEnergyConsumption"
echo "  Utilization $utilization"
echo ""

#Energy Distribution
totalEnergyConsumptionNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT sum(kWh) FROM(
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerPumpCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
) as a
"))	

energyDistributionNum=0

if [ -f "./buf/energyDistributionJson.$startDay.$gId" ]; then
	rm ./buf/energyDistributionJson.$startDay.$gId
fi

arrNum=0
jsonNum=0

while :
do
	if [ $arrNum == $chillerNum ]; then
	 break
	fi
	
	#echo "Energy Distribution ${chillerId[$arrNum]} ${chillerDesc[$arrNum]}"
	
	data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(totalPowerWh)/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh FROM reportplatform.dailyChillerData  
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
		and chillerDescription='${chillerDesc[$arrNum]}'
	"))
	
	jsonNum=$(($jsonNum+1))
				  #>=
	if [ $jsonNum -ge 2 ]; then
		printf ",">> ./buf/energyDistributionJson.$startDay.$gId
	fi
	
	if [ "$data" != "NULL" ]; then
		printf "\"%s\": {\"data\": %.2f}" ${chillerDesc[$arrNum]} $data >> ./buf/energyDistributionJson.$startDay.$gId
		
		echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum.$startDay.$gId	
		energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
	else
		printf "\"%s\": {\"data\": %.2f}" ${chillerDesc[$arrNum]} 0 >> ./buf/energyDistributionJson.$startDay.$gId
	fi

	arrNum=$(($arrNum+1))
done

#Chiller Pump Cooling Data
data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM reportplatform.dailyChillerPumpCoolingData  
			WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	"))
jsonNum=$(($jsonNum+1))

			  #>=
if [ $jsonNum -ge 2 ]; then
	printf ",">> ./buf/energyDistributionJson.$startDay.$gId
fi

if [ "$data" != "NULL" ]; then
	printf "\"ChillerPumpCooling\": {\"data\": %.2f}" $data >> ./buf/energyDistributionJson.$startDay.$gId
	
	echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum.$startDay.$gId	
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
else
	printf "\"ChillerPumpCooling\": {\"data\": 0}" >> ./buf/energyDistributionJson.$startDay.$gId
fi

energyDistributionData="$(cat ./buf/energyDistributionJson.$startDay.$gId | head -n 1 | tail -n 1)"

if [ -f "./buf/energyDistributionJson.$startDay.$gId" ]; then
	rm ./buf/energyDistributionJson.$startDay.$gId
	echo "[DEBUG]Energy Distribution Data $energyDistributionNum %"
	echo "[DEBUG]$energyDistributionData"
fi
echo " "
echo "#**********#"
echo "#Efficiency#"
echo "#**********#"
echo " "
whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/kW.$startDay.$gId.$whileHour" ]; then
		rm ./buf/kW.$startDay.$gId.$whileHour
		echo "rm ./buf/kW.$startDay.$gId.$whileHour"
	fi
	
	if [ -f "./buf/coolingCapacity.$startDay.$gId.$whileHour" ]; then
		rm ./buf/coolingCapacity.$startDay.$gId.$whileHour
		echo "rm ./buf/coolingCapacity.$startDay.$gId.$whileHour"
	fi
	
	if [ -f "./buf/efficiency.$startDay.$gId.$whileHour" ]; then
		rm ./buf/efficiency.$startDay.$gId.$whileHour
		echo "rm ./buf/efficiency.$startDay.$gId.$whileHour"
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/kW.$startDay.$gId" ]; then
	rm ./buf/kW.$startDay.$gId
fi

if [ -f "./buf/coolingCapacity.$startDay.$gId" ]; then
	rm ./buf/coolingCapacity.$startDay.$gId
fi

if [ -f "./buf/efficiency.$startDay.$gId" ]; then
	rm ./buf/efficiency.$startDay.$gId
fi

rawData=($(mysql -h ${host} -D$dbRPF -ss -e"
SELECT 
   date_format(a.ts, '%H') as hours,
   (IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as kW,
   coolingCapacity,
   round((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000/coolingCapacity,2) as efficiency
  FROM 
    processETLold.chiller as a,
    iotmgmt.pm as b
  where 
     name='chiller#1' and 
     opFlag=1 and
     ieee='ppssbms0005' and
     a.ts=date_format(b.receivedSync, '%Y-%m-%d %H:%i')
union
SELECT date_format(a.ts, '%H') as hours,(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as kW,coolingCapacity,
  round((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000/coolingCapacity,2) as efficiency
  FROM 
    processETLold.chiller as a,
    iotmgmt.pm as b
  where 
     name='chiller#2' and 
     opFlag=1 and
     ieee='ppssbms0006' and
     a.ts=date_format(b.receivedSync, '%Y-%m-%d %H:%i')
union
SELECT date_format(a.ts, '%H') as hours,(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as kW,coolingCapacity,
  round((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000/coolingCapacity,2) as efficiency
  FROM 
    processETLold.chiller as a,
    iotmgmt.pm as b
  where 
     name='chiller#3' and 
     opFlag=1 and
     ieee='ppssbms0007' and
     a.ts=date_format(b.receivedSync, '%Y-%m-%d %H:%i')
;
"))

whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi
	
	hours=${rawData[$whileNum]}
	hours=$((10#$hours))
	whileNum=$(($whileNum+1))

	kWatt=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	coolingCapacity=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	efficiency=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	

	echo "[DEBUG]$hours $kWatt $coolingCapacity $efficiency"
	
	echo "$kWatt" >> ./buf/kW.$startDay.$gId.$hours
	echo "$kWatt" >> ./buf/kW.$startDay.$gId
	
	echo "$coolingCapacity" >> ./buf/coolingCapacity.$startDay.$gId.$hours
	echo "$coolingCapacity" >> ./buf/coolingCapacity.$startDay.$gId
	
	echo "$efficiency" >> ./buf/efficiency.$startDay.$gId.$hours
	echo "$efficiency" >> ./buf/efficiency.$startDay.$gId
done

if [ -f "./buf/kW.$startDay.$gId" ]; then

	countNum="$(cat ./buf/kW.$startDay.$gId |wc -l)"

	if [ $countNum == 0 ]; then

		kWattMin=NULL
		kWattMedian=NULL
		kWattMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/kW.$startDay.$gId > ./buf/kW.$startDay.$gId.Sort
		rm ./buf/kW.$startDay.$gId
		
		kWattMin="$(cat ./buf/kW.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/kW.$startDay.$gId.Sort
	else

		sort -n ./buf/kW.$startDay.$gId > ./buf/kW.$startDay.$gId.Sort
		rm ./buf/kW.$startDay.$gId
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		FirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		ThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		medianNum=$(($countNum/2))
		
		kWattMin="$(cat ./buf/kW.$startDay.$gId.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.$startDay.$gId.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/kW.$startDay.$gId.Sort
	fi
else
	kWattMin=NULL
	kWattMedian=NULL
	kWattMax=NULL
fi

echo "$kWattMin $kWattMedian $kWattMax"

if [ -f "./buf/coolingCapacity.$startDay.$gId" ]; then

	countNum="$(cat ./buf/coolingCapacity.$startDay.$gId |wc -l)"

	if [ $countNum == 0 ]; then

		coolingCapacityMin=NULL
		coolingCapacityMedian=NULL
		coolingCapacityMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/coolingCapacity.$startDay.$gId > ./buf/coolingCapacity.$startDay.$gId.Sort
		rm ./buf/coolingCapacity.$startDay.$gId
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingCapacity.$startDay.$gId.Sort
	else

		sort -n ./buf/coolingCapacity.$startDay.$gId > ./buf/coolingCapacity.$startDay.$gId.Sort
		rm ./buf/coolingCapacity.$startDay.$gId
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		FirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		ThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		medianNum=$(($countNum/2))
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.$startDay.$gId.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingCapacity.$startDay.$gId.Sort
	fi
else
	coolingCapacityMin=NULL
	coolingCapacityMedian=NULL
	coolingCapacityMax=NULL
fi

echo "$coolingCapacityMin $coolingCapacityMedian $coolingCapacityMax"

if [ -f "./buf/efficiency.$startDay.$gId" ]; then

	countNum="$(cat ./buf/efficiency.$startDay.$gId |wc -l)"

	if [ $countNum == 0 ]; then

		Min=NULL
		Median=NULL
		Max=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/efficiency.$startDay.$gId > ./buf/efficiency.$startDay.$gId.Sort
		rm ./buf/efficiency.$startDay.$gId
		
		Min="$(cat ./buf/efficiency.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		Median="$(cat ./buf/efficiency.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		Max="$(cat ./buf/efficiency.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/efficiency.$startDay.$gId.Sort
	else

		sort -n ./buf/efficiency.$startDay.$gId > ./buf/efficiency.$startDay.$gId.Sort
		rm ./buf/efficiency.$startDay.$gId
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		FirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		ThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		medianNum=$(($countNum/2))
		
		Min="$(cat ./buf/efficiency.$startDay.$gId.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		Median="$(cat ./buf/efficiency.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		Max="$(cat ./buf/efficiency.$startDay.$gId.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/efficiency.$startDay.$gId.Sort
	fi
else
	Min=NULL
	Median=NULL
	Max=NULL
fi

efficiencyMin=$Min
efficiencyMedian=$Median
efficiencyMax=$Max

echo "$Min $Median $Max"

if [ -f "./buf/kw.Json.$startDay.$gId" ]; then
	rm ./buf/kw.Json.$startDay.$gId
fi
whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/kW.$startDay.$gId.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/kW.$startDay.$gId
		fi
		
		sort ./buf/kW.$startDay.$gId.$whileHour > ./buf/kW.$startDay.$gId.$whileHour.sort
		countNum="$(cat ./buf/kW.$startDay.$gId.$whileHour.sort | wc -l)"
		data="$(cat ./buf/kW.$startDay.$gId.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#Energy Consumption(kW)
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/kw.Json.$startDay.$gId
	fi
	whileHour=$(($whileHour+1))
done

kwDataERROR=0
if [ -f "./buf/kw.Json.$startDay.$gId" ]; then
	kwData="$(cat ./buf/kw.Json.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/kw.Json.$startDay.$gId
else
	kwDataERROR=1
fi

if [ -f "./buf/coolingCapacity.Json.$startDay.$gId" ]; then
	rm ./buf/coolingCapacity.Json.$startDay.$gId
fi

whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/coolingCapacity.$startDay.$gId.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingCapacity.$startDay.$gId
		fi
		
		sort ./buf/coolingCapacity.$startDay.$gId.$whileHour > ./buf/coolingCapacity.$startDay.$gId.$whileHour.sort
		countNum="$(cat ./buf/coolingCapacity.$startDay.$gId.$whileHour.sort | wc -l)"
		data="$(cat ./buf/coolingCapacity.$startDay.$gId.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#coolingCapacity
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/coolingCapacity.Json.$startDay.$gId
	fi
	whileHour=$(($whileHour+1))
done

coolingCapacityDataERROR=0
if [ -f "./buf/coolingCapacity.Json.$startDay.$gId" ]; then
	coolingCapacityData="$(cat ./buf/coolingCapacity.Json.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/efficiency.Json.$startDay.$gId
else
	coolingCapacityDataERROR=1
fi
if [ -f "./buf/efficiency.Json.$startDay.$gId" ]; then
	rm ./buf/efficiency.Json.$startDay.$gId
fi

whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/efficiency.$startDay.$gId.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/efficiency.$startDay.$gId
		fi
		
		sort ./buf/efficiency.$startDay.$gId.$whileHour > ./buf/efficiency.$startDay.$gId.$whileHour.sort
		countNum="$(cat ./buf/efficiency.$startDay.$gId.$whileHour.sort | wc -l)"
		data="$(cat ./buf/efficiency.$startDay.$gId.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#efficiency
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/efficiency.Json.$startDay.$gId
	fi
	whileHour=$(($whileHour+1))
done

efficiencyDataERROR=0
if [ -f "./buf/efficiency.Json.$startDay.$gId" ]; then
	efficiencyData="$(cat ./buf/efficiency.Json.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/efficiency.Json.$startDay.$gId
else
	efficiencyDataERROR=1
fi

echo "REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,
	energyConsumptionData,
	utilization,
	energyDistribution,
	efficiencyMin,
	efficiencyMedian,
	efficiencyMax,
	efficiencyData,
	coolingCapacityMin,
	) 
VALUES('$startDay','$siteId','$gId',
	'$totalEnergyConsumption',
	if($energyConsumptionERROR=1,NULL,'{$energyConsumptionData}'),
	'$utilization',
	'{$energyDistributionData}',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($efficiencyDataERROR=1,NULL,'{$efficiencyData}'),
	if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	if($coolingCapacityDataERROR=1,NULL,'{$coolingCapacityData}',
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax'),
	if($kWattDataERROR=1,NULL,'{$kWattData}'))
);
"


exit 0
