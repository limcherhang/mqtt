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
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

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
echo "  -----------------Chiller Water Pump-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'ChilledWaterPump#%'
order by deviceNum asc
;
"))

chilledWaterPumpNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'ChilledWaterPump#%'
;
"))

echo "  Chiller Water Pump Num:$chilledWaterPumpNum"

whileNum=0
arrNum=0
while :
do

	if [ $arrNum == $chilledWaterPumpNum ]; then
		break
	fi

	pumpDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpId[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	pumpTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	echo "  ${pumpDesc[$arrNum]} ${pumpId[$arrNum]} ${pumpIEEE[$arrNum]} ${pumpTable[$arrNum]}"
		
	arrNum=$(($arrNum+1))
done

echo " "
echo "  -----------------Temp Info-------------------- "
arrNum=0
chilledWaterReturnHDRNum=0
chilledWaterSupplyHDRNum=0
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
		deviceDesc = 'ChilledWaterTemp#HDR'
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
		#echo "  "
		
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
					returnValueHDR=$tempValue
					returnIEEEHDR=$deviceIEEE
					#returnTableHDR=$deviceTable
					
					if [ $historyTable == 1 ]; then
						returnTableHDR=${deviceTable}_$dbdataMonth
					else
						returnTableHDR=$deviceTable
					fi
					
					deviceDesc="TempChilledWaterReturn#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc $returnIEEEHDR $returnTableHDR $returnValueHDR"
					chilledWaterReturnHDRNum=1
				 ;;
				TempChilledWaterSupply)
					supplyValueHDR=$tempValue
					supplyIEEEHDR=$deviceIEEE
					#supplyTableHDR=$deviceTable
					
					if [ $historyTable == 1 ]; then
						supplyTableHDR=${deviceTable}_$dbdataMonth
					else
						supplyTableHDR=$deviceTable
					fi
					
					deviceDesc="TempChilledWaterSupply#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc $supplyIEEEHDR $supplyTableHDR $supplyValueHDR"
					chilledWaterSupplyHDRNum=1
				 ;;
				TempCoolingWaterSupply)

					coolingSupplyValueHDR=$tempValue
					coolingSupplyIEEEHDR=$deviceIEEE
					#coolingSupplyTableHDR=$deviceTable
					
					if [ $historyTable == 1 ]; then
						coolingSupplyTableHDR=${deviceTable}_$dbdataMonth
					else
						coolingSupplyTableHDR=$deviceTable
					fi
					deviceDesc="TempCoolingWaterSupply#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc $coolingSupplyIEEEHDR $coolingSupplyTableHDR $coolingSupplyValueHDR"
				 ;;
				TempCoolingWaterReturn)

					coolingReturnValueHDR=$tempValue
					coolingReturnIEEEHDR=$deviceIEEE
					#coolingReturnTableHDR=$deviceTable
					
					if [ $historyTable == 1 ]; then
						coolingReturnTableHDR=${deviceTable}_$dbdataMonth
					else
						coolingReturnTableHDR=$deviceTable
					fi
					
					deviceDesc="TempCoolingWaterReturn#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc $coolingReturnIEEEHDR $coolingReturnTableHDR $coolingReturnValueHDR"
				 ;;
				*)
				 ;;
				esac
				
				echo " "
			fi
		done
	done
	echo " "
	arrNum=$(($arrNum+1))
done


echo ""
echo "  ----------------Cooling Tower Info--------------------- "

#Cooling Info
DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc != 'CoolingTower#HDR' and
	deviceDesc like 'CoolingTower#%'
order by deviceNum asc
;
"))

coolingTowerNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc != 'CoolingTower#HDR' and
	deviceDesc like 'CoolingTower#%'
;
"))

echo "  Cooling Tower Num:$coolingTowerNum"

whileNum=0
arrNum=0
while :
do
	if [ $arrNum == $coolingTowerNum ]; then
	 break
	fi
	
	coolingDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingId[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))

	echo "  ${coolingDesc[$arrNum]} ${coolingId[$arrNum]} ${coolingIEEE[$arrNum]} ${coolingTable[$arrNum]}"
	arrNum=$(($arrNum+1))
done

echo ""
echo "  ----------------Cooling Tower HDR Info--------------------- "

#Cooling Tower HDR Info
DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc = 'CoolingTower#HDR'
order by deviceNum asc
;
"))

coolingTowerHDRNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc = 'CoolingTower#HDR' 
;
"))

echo "  Cooling Tower HDR Num:$coolingTowerHDRNum"
if [ $coolingTowerHDRNum -ge 1 ]; then

	whileNum=0
	coolingTowerHDRDesc=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingTowerHDRId=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingTowerHDRIEEE=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingTowerHDRTable=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))

	echo "  $coolingTowerHDRDesc $coolingTowerHDRId $coolingTowerHDRIEEE $coolingTowerHDRTable"
	 
fi
	

echo ""
echo "  ----------------Cooling Water Pump Info-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'CoolingWaterPump#%'
order by deviceNum asc
;
"))

coolingWaterPumpNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'CoolingWaterPump#%'
;
"))

whileNum=0
arrNum=0

while :
do
	if [ $arrNum == $coolingWaterPumpNum ]; then
	 break
	fi

	coolingWaterPumpDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingWaterPumpId[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingWaterPumpIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	coolingWaterPumpTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	echo "  ${coolingWaterPumpDesc[$arrNum]} ${coolingWaterPumpId[$arrNum]} ${coolingWaterPumpIEEE[$arrNum]} ${coolingWaterPumpTable[$arrNum]}"
	arrNum=$(($arrNum+1))
done
echo " "
echo "  -----------------Chiller Water Flow-------------------- "

chilledWaterFlowHDRNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc = 'ChilledWaterFlow#HDR'
;
")

echo "  Chiller Water Flow HDR Num:$chilledWaterFlowHDRNum"

if [ $chilledWaterFlowHDRNum == 1 ]; then

	DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
			FROM iotmgmtChiller.vDeviceInfo 
			where 
				gatewayId=$gId and deviceDesc = 'ChilledWaterFlow#HDR'
			;
	"))
	
	flowHDRIEEE=${DeviceInfoBuf[0]}
	
	if [ $historyTable == 1 ]; then
		flowHDRTable=${DeviceInfoBuf[1]}_$dbdataMonth
	else
		flowHDRTable=${DeviceInfoBuf[1]}
	fi
	
	flowHDRDeviceDesc=${DeviceInfoBuf[2]}
fi

echo ""
DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
			FROM iotmgmtChiller.vDeviceInfo 
			where 
				gatewayId=$gId and deviceDesc like 'ChilledWaterFlowCombined#%'
			order by deviceDesc asc
			;
			"))
			
chilledWaterFlowCombinedNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
		FROM iotmgmtChiller.vDeviceInfo 
			where 
				gatewayId=$gId and deviceDesc like 'ChilledWaterFlowCombined#%';
")

echo "  Chiller Water Flow Combined Num:$chilledWaterFlowCombinedNum"	

arrNum=0
whileNum=0
while :
do
	if [ $arrNum == $chilledWaterFlowCombinedNum ]; then
	 break
	fi
	
	flowCombinedIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	if [ $historyTable == 1 ]; then
		flowCombinedTable[$arrNum]=${DeviceInfoBuf[$whileNum]}_$dbdataMonth
	else
		flowCombinedTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	fi
	whileNum=$(($whileNum+1))
	
	flowCombinedDeviceDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	arrNum=$(($arrNum+1))
done

echo " "
echo "#***********************#"
echo "#Daily Plant Performance#"
echo "#***********************#"
echo " "

#totalEnergyConsumption
totalEnergyConsumption=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT sum(kWh) FROM(
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyCoolingPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
) as a
"))

if [ "$totalEnergyConsumption" == "NULL" ]; then
	totalEnergyConsumption=0
	echo "  totalEnergyConsumption is NULL"
fi

#utilization
TotalPossible=$(($chillerNum+$chilledWaterPumpNum+$coolingTowerNum+$coolingWaterPumpNum))

utilization=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round((sum(operationMinutes)/60)/($TotalPossible*24)*100,2)  FROM(
    SELECT chillerDescription,operationMinutes FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT pumpDescription,operationMinutes FROM reportplatform.dailyPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT coolingDescription,operationMinutes FROM reportplatform.dailyCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT pumpDescription,operationMinutes FROM reportplatform.dailyCoolingPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
) as a
"))
if [ "$utilization" == "NULL" ]; then
	utilization=0
	echo "  utilization is NULL"
	echo "  [DEBUG]TotalPossible $TotalPossible=$chillerNum+$chilledWaterPumpNum+$coolingTowerNum+$coolingWaterPumpNum"
	echo "  [DEBUG]TotalEnergyConsumption $totalEnergyConsumption"
	echo "  [DEBUG]Utilization $utilization"
fi

# echo "[DEBUG]TotalPossible $TotalPossible=$chillerNum+$chilledWaterPumpNum+$coolingTowerNum+$coolingWaterPumpNum"
# echo "[DEBUG]TotalEnergyConsumption $totalEnergyConsumption"
# echo "[DEBUG]Utilization $utilization"

#Energy Distribution

totalEnergyConsumptionNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT sum(kWh) FROM(
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyCoolingPumpData
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

#pumps
chillerPumpdata=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM reportplatform.dailyPumpData  
			WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	"))
	
#cooling Pumps
coolingPumpdata=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumption)*100,2) as kWh 
		FROM reportplatform.dailyCoolingPumpData  
			WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	"))

jsonNum=$(($jsonNum+1))

			  #>=
if [ $jsonNum -ge 2 ]; then
	printf ",">> ./buf/energyDistributionJson.$startDay.$gId
fi

echo "chillerPumpdata:$chillerPumpdata coolingPumpdata:$coolingPumpdata"
	
if [ "$chillerPumpdata" == "NULL" ] && [ "$coolingPumpdata" == "NULL" ] ; then
	printf "\"Pumps\": {\"data\": 0}" >> ./buf/energyDistributionJson.$startDay.$gId
	
elif [ "$chillerPumpdata" != "NULL" ] && [ "$coolingPumpdata" == "NULL" ] ; then

	printf "\"Pumps\": {\"data\": %.2f}" $chillerPumpdata >> ./buf/energyDistributionJson.$startDay.$gId
	
	echo "scale=3;$energyDistributionNum+$chillerPumpdata"|bc > ./buf/energyDistributionNum.$startDay.$gId	
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
	
elif [ "$chillerPumpdata" == "NULL" ] && [ "$coolingPumpdata" != "NULL" ] ; then

	printf "\"Pumps\": {\"data\": %.2f}" $coolingPumpdata >> ./buf/energyDistributionJson.$startDay.$gId
	
	echo "scale=3;$energyDistributionNum+$coolingPumpdata"|bc > ./buf/energyDistributionNum.$startDay.$gId	
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
	
else

	echo "scale=2;$chillerPumpdata+$coolingPumpdata"|bc > ./buf/pumps.$startDay.$gId
	data="$(cat ./buf/pumps.$startDay.$gId | head -n 1 | tail -n 1)"
	rm ./buf/pumps.$startDay.$gId

	printf "\"Pumps\": {\"data\": %.2f}" $data >> ./buf/energyDistributionJson.$startDay.$gId
	
	echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum.$startDay.$gId	
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
	
fi

#cooling tower
data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM reportplatform.dailyCoolingData  
			WHERE operationDate='$startDay' and operationFlag=1 and gatewayId=$gId
	"))
jsonNum=$(($jsonNum+1))

			  #>=
if [ $jsonNum -ge 2 ]; then
	printf ",">> ./buf/energyDistributionJson.$startDay.$gId
fi

if [ "$data" != "NULL" ]; then
	printf "\"CoolingTowers\": {\"data\": %.2f}" $data >> ./buf/energyDistributionJson.$startDay.$gId
	
	echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum.$startDay.$gId	
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
else
	printf "\"CoolingTowers\": {\"data\": 0}" >> ./buf/energyDistributionJson.$startDay.$gId
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

chillerPlantTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT chillerId,date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
FROM reportplatform.dailyChillerData
WHERE gatewayId=$gId
and operationDate='$startDay'
and operationFlag=1
;
"))

if [ -f "./buf/energyConsumptionDataJson.$startDay.$gId" ]; then
	rm ./buf/energyConsumptionDataJson.$startDay.$gId
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/energyConsumptionData.$startDay.$gId.$whileHour" ]; then
		rm ./buf/energyConsumptionData.$startDay.$gId.$whileHour
		echo "rm ./buf/energyConsumptionData.$startDay.$gId.$whileHour"
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/plantCooling.$startDay.$gId" ]; then
	rm ./buf/plantCooling.$startDay.$gId
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/plantCoolingData.$startDay.$gId.$whileHour" ]; then
		rm ./buf/plantCoolingData.$startDay.$gId.$whileHour
		echo "rm ./buf/plantCoolingData.$startDay.$gId.$whileHour"
	fi

	whileHour=$(($whileHour+1))
done


if [ -f "./buf/plantCoolingJson.$startDay.$gId" ]; then
	rm ./buf/plantCoolingJson.$startDay.$gId
fi

whileNum=0
jsonNum=0
while :
do
	if [ "${chillerPlantTime[$whileNum]}" == "" ]; then
		break
	fi

	chillerIdNum=${chillerPlantTime[$whileNum]}
	whileNum=$(($whileNum+1))
	
	runStartHour=${chillerPlantTime[$whileNum]}
	runStartHour=$((10#$runStartHour))
	whileNum=$(($whileNum+1))
	
	runStartMin=${chillerPlantTime[$whileNum]}
	runStartMin=$((10#$runStartMin))
	whileNum=$(($whileNum+1))
	
	runEndHour=${chillerPlantTime[$whileNum]}
	runEndHour=$((10#$runEndHour))
	whileNum=$(($whileNum+1))
	
	runEndMin=${chillerPlantTime[$whileNum]}
	runEndMin=$((10#$runEndMin))
	whileNum=$(($whileNum+1))

	stHour=0
	stMin=0
	
	endHour=0
	endMin=0

	arrNum=0
	while :
	do

		if [ $arrNum == $chillerNum ]; then
			break
		fi
		
		if [ ${chillerId[$arrNum]} == $chillerIdNum ]; then
			break
		fi
		
		arrNum=$(($arrNum+1))
	done
	
	echo "  ${chillerDesc[$arrNum]} ${chillerId[$arrNum]} ${chillerIEEE[$arrNum]} ${chillerTable[$arrNum]} $runStartHour:$runStartMin ~ $runEndHour:$runEndMin"

	while :
	do
		if [ $stHour == 25 ]; then
		 break
		fi
		
		#stHour >= runStartHour and  stHour <= runStartHour
		if [ $stHour -ge $runStartHour ] && [ $stHour -le $runEndHour ]; then
			
			if [ $stHour == $runEndHour ]; then
			
				if [ $runEndMin == 0 ]; then
					echo "  $runEndHour:$runEndMin is 0"
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
				
				printf ",">> ./buf/efficiencyJson.$startDay.$gId
			fi
			
			# Median Value taken over that hour interval.
			# Example : At least 1 chiller ON from 23:00 –
			# 23:30
			# Median Plant Power Consumption Value
			# taken over the period 23:00 – 23:30
			
			startDateTime=$(date "+%Y-%m-%d %H:%M" -d "$startDay $stHour:$stMin")
			endDateTime=$(date "+%Y-%m-%d %H:%M" -d "$startDay $endHour:$endMin")
			
			dataWatt=($(mysql -h ${host} -D$dbdata -ss -e"SELECT (IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as watt
				FROM $pmTable 
				 WHERE ieee='${chillerIEEE[$arrNum]}' and 
				 receivedSync >= '$startDateTime' and 
				 receivedSync <= '$endDateTime:59'
				GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
			"))

			
			dataNum=0
			
			while :
			do
				if [ "${dataWatt[$dataNum]}" == "" ]; then
					break
				fi

				#echo "[DEBUG]data Watt:${dataWatt[$dataNum]}"
				echo "${dataWatt[$dataNum]}" >> ./buf/energyConsumptionData.$startDay.$gId.$stHour
				
				dataNum=$(($dataNum+1))
			done
		fi

		stHour=$(($stHour+1))
	done
	#next time
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

	if [ -f "./buf/energyConsumptionData.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/energyConsumptionData.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/energyConsumptionData.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		wattDataTotal=0
		wattData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			wattData="$(cat ./buf/energyConsumptionData.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#Plant Power Consumption (kW) = Every data
			#point (minute) will just be the sum of power
			#of all equipment that are on
			
			#echo "$wattDataTotal+$wattData"
			echo "scale=3;$wattDataTotal+$wattData"|bc > ./buf/wattDataTotal.$startDay.$gId
			
			wattDataTotal="$(cat ./buf/wattDataTotal.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		#echo " $wattDataTotal"

		rm ./buf/energyConsumptionData.$startDay.$gId.$whileHour
	
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/energyConsumptionDataJson.$startDay.$gId
		fi
		
		echo "scale=2;$wattDataTotal/$countNum"|bc > ./buf/wattDataTotal.$startDay.$gId
		wattDataTotal="$(cat ./buf/wattDataTotal.$startDay.$gId | head -n 1 | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#Energy Consumption(kW)
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $wattDataTotal >> ./buf/energyConsumptionDataJson.$startDay.$gId
	fi
	whileHour=$(($whileHour+1))
done

energyConsumptionERROR=0
if [ -f "./buf/energyConsumptionDataJson.$startDay.$gId" ]; then
	energyConsumptionData="$(cat ./buf/energyConsumptionDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/energyConsumptionDataJson.$startDay.$gId
else
	energyConsumptionERROR=1
fi

echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Plant  Efficiency        #"
echo "#                            #"
echo "#****************************#"
echo " "

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/plantEfficiency.$startDay.$gId.$whileHour" ]; then
		rm ./buf/plantEfficiency.$startDay.$gId.$whileHour
		echo "rm ./buf/plantEfficiency.$startDay.$gId.$whileHour"
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/plantEfficiency.$startDay.$gId" ]; then
	rm ./buf/plantEfficiency.$startDay.$gId
fi



stHour=0
while :
do
	
	if [ $stHour == 24 ]; then
	 break
	fi
	
	echo "  Run Plant Efficiency  by $stHour" 
	
	stMin=0
	while :
	do
		if [ $stMin == 60 ]; then
			break
		elif [ $stMin == 59 ]; then
			endHour=$(($stHour+1))
			endMin=00
		else
			endHour=$stHour
			endMin=$(($stMin+1))
		fi
			
			
		#echo "$stHour:$stMin ~ $endHour:$endMin"
		dataWatt=0
		totalWatt=0
		efficiencyTotalWattTrue=0
		arrNum=0
		while :
		do
			if [ $arrNum == $chillerNum ]; then
			 break
			fi
			
			#echo "[DEBUG]cId:${chillerId[$arrNum]}"
			
			efficiencyPlantTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
				FROM 
				  reportplatform.dailyChillerData
				WHERE 
				 gatewayId=$gId and 
				 operationDate='$startDay'and 
				 operationFlag=1 and 
				 chillerId=${chillerId[$arrNum]};
			"))
			
			efficiencyTrue=0
			whileNum=0
			while :
			do
				if [ "${efficiencyPlantTime[$whileNum]}" == "" ]; then
				 break
				fi
				
				runStartHour=${efficiencyPlantTime[$whileNum]}
				runStartHour=$((10#$runStartHour))
				whileNum=$(($whileNum+1))
				
				runStartMin=${efficiencyPlantTime[$whileNum]}
				runStartMin=$((10#$runStartMin))
				whileNum=$(($whileNum+1))
				
				runEndHour=${efficiencyPlantTime[$whileNum]}
				runEndHour=$((10#$runEndHour))
				whileNum=$(($whileNum+1))
				
				runEndMin=${efficiencyPlantTime[$whileNum]}
				runEndMin=$((10#$runEndMin))
				whileNum=$(($whileNum+1))
				
				if [ $stHour -gt $runStartHour ]; then
				
					if [ $endHour -lt $runEndHour ]; then
						efficiencyTrue=1
					elif [ $endHour == $runEndHour ]; then
						if [ $endMin -le $runEndMin ]; then
							efficiencyTrue=1
						fi
					fi
				elif [ $stHour == $runStartHour ]; then
				
					if [ $stMin -ge $runStartMin ]; then
						if [ $endHour -lt $runEndHour ]; then
							efficiencyTrue=1
						elif [ $endHour == $runEndHour ]; then
							if [ $endMin -le $runEndMin ]; then
								efficiencyTrue=1
							fi
						fi
					fi
				fi
				
				if [ $efficiencyTrue == 1 ]; then
				

					
					dataWatt=($(mysql -h ${host} -D$dbdata -ss -e"select 
						round(IFNULL(sum(ch1Watt),0)+IFNULL(sum(ch2Watt),0)+IFNULL(sum(ch3Watt),0),0) as watt
					 FROM $pmTable 
						WHERE 
						  (
						  ieee='${chillerIEEE[$arrNum]}' or 
						  ieee='${pumpIEEE[$arrNum]}' or 
						  ieee='${coolingWaterPumpIEEE[$arrNum]}' or
						  ieee='${coolingIEEE[$arrNum]}'
						  ) 
						  and 
						  receivedSync >='$startDay $stHour:$stMin' and 
						  receivedSync <'$endDay $endHour:$endMin'
					  GROUP BY receivedSync
					"))

				
					# echo "[DEBUG]chillerIEEE='${chillerIEEE[$arrNum]}'  "
					# echo "	     pumpIEEE='${pumpIEEE[$arrNum]}'"
					# echo "	     coolingWaterPumpIEEE='${coolingWaterPumpIEEE[$arrNum]}' "
					# echo "	     coolingIEEE='${coolingIEEE[$arrNum]}'"
					
					#echo "[DEBUG]cId:${chillerId[$arrNum]} $stHour:$stMin ~ $endHour:$endMin || $runStartHour $runStartMin $runEndHour $runEndMin $totalWatt+$dataWatt"
					
					echo "scale=3;$totalWatt+$dataWatt"|bc > ./buf/totalWatt.$startDay.$gId
					totalWatt="$(cat ./buf/totalWatt.$startDay.$gId | head -n 1 | tail -n 1)"
					
					efficiencyTotalWattTrue=1
					break
				fi
			done
			arrNum=$(($arrNum+1))
		done
		
		if [ $efficiencyTotalWattTrue == 1 ]; then
		
			if [ $coolingTowerHDRNum -ge 1 ]; then
			
				coolingTowerHDRWatt=($(mysql -h ${host} -D$dbdata -ss -e"select 
						round(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as watt
					  FROM $pmTable 
						  WHERE ieee='$coolingTowerHDRIEEE' and 
						  receivedSync >='$startDay $stHour:$stMin' and 
						  receivedSync <'$startDay $endHour:$endMin'
					  GROUP BY receivedSync
					"))

				#echo "[DEBUG]$coolingTowerHDRDesc : $totalWatt+$coolingTowerHDRWatt"
				echo "scale=3;$totalWatt+$coolingTowerHDRWatt"|bc > ./buf/totalWatt.$startDay.$gId
				totalWatt="$(cat ./buf/totalWatt.$startDay.$gId | head -n 1 | tail -n 1)"
			fi
		fi
		
		if [ $chilledWaterFlowCombinedNum -ge 1 ]; then
			if [ $efficiencyTotalWattTrue == 1 ] && [ $chilledWaterReturnHDRNum == 1 ] && [ $chilledWaterSupplyHDRNum == 1 ]; then
							
				deltaDetailData=($(mysql -h ${host} -D$dbdata -ss -e"select Round(tempReturn-tempSupply,2) as delta,flowRate
				from
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($supplyValueHDR,2) as tempSupply
				  FROM 
				   $supplyTableHDR
					WHERE 
					 ieee='$supplyIEEEHDR' and 
					 receivedSync >='$startDay $stHour:$stMin' and 
					 receivedSync <'$startDay $endHour:$endMin' and 
					 $supplyValueHDR is not NULL and
					 $supplyValueHDR >= 0
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				) as a

				INNER join
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($returnValueHDR,2) as tempReturn
					FROM 
					 $returnTableHDR
					WHERE 
					 ieee='$returnIEEEHDR' and 
					 receivedSync >='$startDay $stHour:$stMin' and 
					 receivedSync <'$startDay $endHour:$endMin' and 
					 $returnValueHDR is not NULL and
					 $returnValueHDR >= 0
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				) as b
				on a.time=b.time
				
				INNER join
				(
				SELECT ts1 as time,Round(flowRate,2) as flowRate
						 FROM (
							Select a.syncTime as ts1,b.syncTime as ts2,a.flowRate+b.flowRate as flowRate
							from
							(
							 SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,Round(flowRate,2) as flowRate FROM ${flowCombinedTable[0]}
								WHERE 
								  ieee='${flowCombinedIEEE[0]}' and 
								  receivedSync>='$startDay $stHour:$stMin' and 
								  receivedSync<='$startDay $endHour:$endMin' and 
								  flowRate >= 0
							)
							as a
							 left join
							(
							 SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,Round(flowRate,2) as flowRate FROM ${flowCombinedTable[1]} 
								WHERE 
								  ieee = '${flowCombinedIEEE[1]}' and 
								  receivedSync >= '$startDay $stHour:$stMin' and 
								  receivedSync <= '$startDay $endHour:$endMin' and
								  flowRate >= 0
							)
							as b
							on a.syncTime=b.syncTime
					  ) as a
					where flowRate is not null 
				 GROUP BY date_format(time, '%Y-%m-%d %H:%i')
				) as c
				on a.time=c.time;"))
			
				if [ "${deltaDetailData[0]}" == "" ]; then
					echo "[ERROR]$startDay $stHour:$stMin Delta Detail Data is no data "
				else
					
					deltaData=${deltaDetailData[0]}
					dataNum=$(($dataNum+1))
					
					flowData=${deltaDetailData[1]}
					dataNum=$(($dataNum+1))
					
					if [ $deltaData == 0 ] || [ $flowData == 0 ]; then
						echo "[ERROR]$stHour:$stMin deltaData:$deltaData flowData:$flowData" 
					else
						#echo "deltaData=$deltaData flowData=$flowData"
						echo "scale=3;$deltaData*4.2*997*$flowData/(3600*3.5168525)"|bc > ./buf/plantCoolingLoadBuf.$startDay.$gId
						plantCoolingLoad="$(cat ./buf/plantCoolingLoadBuf.$startDay.$gId | head -n 1 | tail -n 1)"
						
						if [ "$totalWatt" == "" ] || [ "$totalWatt" == " " ] || [ "$totalWatt" == "0" ]; then
							echo "[ERROR]$stHour:$stMin  ($totalWatt/1000)/$plantCoolingLoad deltaData=$deltaData flowData=$flowData" 
						else
							#echo "($totalWatt/1000)/$plantCoolingLoad"
							echo "scale=3;($totalWatt/1000)/$plantCoolingLoad"|bc > ./buf/plantEfficiencyBuf.$startDay.$gId
							plantEfficiency="$(cat ./buf/plantEfficiencyBuf.$startDay.$gId | head -n 1 | tail -n 1)"
							
							echo "$stHour:$stMin plantEfficiency:$plantEfficiency" 
							
							echo "$plantEfficiency" >> ./buf/plantEfficiency.$startDay.$gId.$stHour
							echo "$plantEfficiency" >> ./buf/plantEfficiency.$startDay.$gId
						fi
					fi
				fi
				
			fi #if [ $efficiencyTotalWattTrue == 1 ] && [ $chilledWaterReturnHDRNum == 1 ] && [ $chilledWaterSupplyHDRNum == 1 ]; then
		else
			if [ $chilledWaterFlowHDRNum == 1 ] && [ $efficiencyTotalWattTrue == 1 ] && [ $chilledWaterReturnHDRNum == 1 ] && [ $chilledWaterSupplyHDRNum == 1 ]; then

				deltaDetailData=($(mysql -h ${host} -D$dbdata -ss -e"select Round(tempReturn-tempSupply,2) as delta,flowRate
				from
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($supplyValueHDR,2) as tempSupply
				  FROM 
				   $supplyTableHDR
					WHERE 
					 ieee='$supplyIEEEHDR' and 
					 receivedSync >='$startDay $stHour:$stMin' and 
					 receivedSync <'$startDay $endHour:$endMin' and 
					 $supplyValueHDR is not NULL and
					 $supplyValueHDR >= 0
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				) as a

				INNER join
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($returnValueHDR,2) as tempReturn
					FROM 
					 $returnTableHDR
					WHERE 
					 ieee='$returnIEEEHDR' and 
					 receivedSync >='$startDay $stHour:$stMin' and 
					 receivedSync <'$startDay $endHour:$endMin' and 
					 $returnValueHDR is not NULL and
					 $returnValueHDR >= 0
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				) as b
				on a.time=b.time
				
				INNER join
				(
				SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(flowRate,2) as flowRate
					FROM 
					 $flowHDRTable
					WHERE 
					 ieee='$flowHDRIEEE' and 
					 receivedSync >='$startDay $stHour:$stMin' and 
					 receivedSync <'$startDay $endHour:$endMin' and
					 flowRate >=0 and
					 flowRate is not NULL
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				) as c
				on a.time=c.time;"))

				if [ "${deltaDetailData[0]}" == "" ] || [ "${deltaDetailData[1]}" == "" ]; then
					echo "[ERROR]$startDay $stHour:$stMin Delta Detail Data is no data "
				else
					deltaData=${deltaDetailData[0]}
					dataNum=$(($dataNum+1))
					
					flowData=${deltaDetailData[1]}
					dataNum=$(($dataNum+1))
					
					if [ "$deltaData" == "0.00" ] || [ "$flowData" == "0.00" ]; then
						echo "[ERROR]$stHour:$stMin deltaData:$deltaData flowData:$flowData" 
					else
						#echo "deltaData=$deltaData flowData=$flowData"
						echo "scale=3;$deltaData*4.2*997*$flowData/(3600*3.5168525)"|bc > ./buf/plantCoolingLoadBuf.$startDay.$gId
						plantCoolingLoad="$(cat ./buf/plantCoolingLoadBuf.$startDay.$gId | head -n 1 | tail -n 1)"
						
						if [ "$totalWatt" == "" ] || [ "$totalWatt" == " " ] || [ "$totalWatt" == "0" ]; then
							echo "[ERROR]$stHour:$stMin  ($totalWatt/1000)/$plantCoolingLoad deltaData=$deltaData flowData=$flowData" 
						else
							#echo "($totalWatt/1000)/$plantCoolingLoad"
							echo "scale=3;($totalWatt/1000)/$plantCoolingLoad"|bc > ./buf/plantEfficiencyBuf.$startDay.$gId
							plantEfficiency="$(cat ./buf/plantEfficiencyBuf.$startDay.$gId | head -n 1 | tail -n 1)"
							
							echo "$stHour:$stMin plantEfficiency:$plantEfficiency ($totalWatt/1000)/$plantCoolingLoad deltaData=$deltaData flowData=$flowData" 
							
							echo "$plantEfficiency" >> ./buf/plantEfficiency.$startDay.$gId.$stHour
							echo "$plantEfficiency" >> ./buf/plantEfficiency.$startDay.$gId
						fi
					fi
				fi
				
			fi #if [ $chilledWaterFlowHDRNum == 1 ] && [ $efficiencyTotalWattTrue == 1 ] && [ $chilledWaterReturnHDRNum == 1 ] && [ $chilledWaterSupplyHDRNum == 1 ]; then
		fi #if [ $chilledWaterFlowCombinedNum -ge 1 ]; then
		
		stMin=$(($stMin+1))
	done
	
	stHour=$(($stHour+1))
done

if [ -f "./buf/plantEfficiency.$startDay.$gId" ]; then

	plantEfficiencyCountNum="$(cat ./buf/plantEfficiency.$startDay.$gId |wc -l)"

	if [ $plantEfficiencyCountNum == 0 ]; then

		efficiencyMin=NULL
		efficiencyMedian=NULL
		efficiencyMax=NULL
		
	elif [ $plantEfficiencyCountNum == 1 ]; then

		sort -n ./buf/plantEfficiency.$startDay.$gId > ./buf/plantEfficiency.$startDay.$gId.Sort
		rm ./buf/plantEfficiency.$startDay.$gId
		
		efficiencyMin="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		efficiencyMedian="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		efficiencyMax="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/plantEfficiency.$startDay.$gId.Sort
	else

		sort -n ./buf/plantEfficiency.$startDay.$gId > ./buf/plantEfficiency.$startDay.$gId.Sort
		rm ./buf/plantEfficiency.$startDay.$gId
		
		echo "scale=0;$(($plantEfficiencyCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] supply Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($plantEfficiencyCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] supply Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($plantEfficiencyCountNum/2))
		
		efficiencyMin="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		efficiencyMedian="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		efficiencyMax="$(cat ./buf/plantEfficiency.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/plantEfficiency.$startDay.$gId.Sort
	fi
else
	efficiencyMin=NULL
	efficiencyMedian=NULL
	efficiencyMax=NULL
fi

if [ $chilledWaterFlowHDRNum == 1 ]; then
whileHour=0
jsonNum=0
stHour=0
endHour=0

	while :
	do
		if [ "$whileHour" == 24 ]; then
			break
		fi

		if [ -f "./buf/plantEfficiency.$startDay.$gId.$whileHour" ]; then
		
			#echo "./buf/plantEfficiency.$startDay.$gId.$whileHour"
			
			countNum="$(cat ./buf/plantEfficiency.$startDay.$gId.$whileHour |wc -l)"
			
			calNum=1
			dataTotal=0
			wffData=0

			while :
			do
				if [ $calNum == $countNum ]; then
					break
				fi
				
				wffData="$(cat ./buf/plantEfficiency.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
				
				#echo "$dataTotal+$wffData"
				echo "scale=3;$dataTotal+$wffData"|bc > ./buf/dataTotal.$startDay.$gId
				
				dataTotal="$(cat ./buf/dataTotal.$startDay.$gId | head -n 1 | tail -n 1)"
				
				calNum=$(($calNum+1))
			done
			
			echo "scale=3;$dataTotal/$countNum"|bc > ./buf/dataTotal.$startDay.$gId
				
			dataTotal="$(cat ./buf/dataTotal.$startDay.$gId | head -n 1 | tail -n 1)"
			#echo " $dataTotal"

			rm ./buf/plantEfficiency.$startDay.$gId.$whileHour
		
			jsonNum=$(($jsonNum+1))
						  #>=
			if [ $jsonNum -ge 2 ]; then
				printf ",">> ./buf/efficiencyDataJson.$startDay.$gId
			fi
			
			stHour=$whileHour
			endHour=$(($whileHour+1))

			#Efficiency Data
			printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotal >> ./buf/efficiencyDataJson.$startDay.$gId
		fi
		
		whileHour=$(($whileHour+1))
	done
fi
efficiencyDataERROR=0
if [ -f "./buf/efficiencyDataJson.$startDay.$gId" ]; then
	efficiencyData="$(cat ./buf/efficiencyDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/efficiencyDataJson.$startDay.$gId
else
	efficiencyDataERROR=1
fi


echo "REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData) 
VALUES('$startDay','$siteId','$gId',
	'$totalEnergyConsumption',
	if($energyConsumptionERROR=1,NULL,'{$energyConsumptionData}'),
	'$utilization',
	'{$energyDistributionData}',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($efficiencyDataERROR=1,NULL,'{$efficiencyData}')
);
"

mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData) 
VALUES('$startDay','$siteId','$gId',
	'$totalEnergyConsumption',
	if($energyConsumptionERROR=1,NULL,'{$energyConsumptionData}'),
	'$utilization',
	'{$energyDistributionData}',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($efficiencyDataERROR=1,NULL,'{$efficiencyData}')
);
"
exit 0
