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

dbProcess="processETLold"
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
	gatewayId=128 and 
	deviceDesc != 'CoolingTower#HDR' and
	deviceDesc like 'CoolingTower#%'
order by deviceNum asc
;
"))

# coolingTowerNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
# FROM iotmgmtChiller.vDeviceInfo 
# where 
	# gatewayId=128 and 
	# deviceDesc != 'CoolingTower#HDR' and
	# deviceDesc like 'CoolingTower#%'
# ;
# "))
coolingTowerNum=3

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
	gatewayId=128 and 
	deviceDesc = 'CoolingTower#HDR'
order by deviceNum asc
;
"))

coolingTowerHDRNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=128 and 
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

powerData=($(mysql -h ${host} -D$dbdata -ss -e"
		SELECT round((sum(ch1Watt)+sum(ch2Watt)+sum(ch3Watt))/1000,2) as kw 
   FROM $pmTable 
   where 
       ieee in ('${chillerIEEE[0]}','${chillerIEEE[1]}','${chillerIEEE[2]}',
				'${pumpIEEE[0]}','${pumpIEEE[1]}','${pumpIEEE[2]}',
	            '${coolingIEEE[0]}','${coolingIEEE[1]}',
				'${coolingWaterPumpIEEE[0]}','${coolingWaterPumpIEEE[1]}','${coolingWaterPumpIEEE[2]}') and 
       receivedSync>='$startDay $startTime' and 
       receivedSync<'$endDay $endTime' 
       group by receivedSync;
;"))

echo "${powerData[0]}" > ./buf/powerData.$startDay.$gId
powerDataConut=1
while :
do
	if [ "${powerData[$powerDataConut]}" == "" ]; then
	  break
	fi
	
	echo "${powerData[$powerDataConut]}" >> ./buf/powerData.$startDay.$gId
	
	powerDataConut=$(($powerDataConut+1))
done

echo "[DEBUG]powerDataConut $powerDataConut"
echo "  Run Power Kw Min Median Max"	
if [ -f "./buf/powerData.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/powerData.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		powerKwMin=NULL
		powerKwMedian=NULL
		powerKwMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/powerData.$startDay.$gId > ./buf/powerData.$startDay.$gId.Sort
		rm ./buf/powerData.$startDay.$gId
		
		powerKwMin="$(cat ./buf/powerData.$startDay.$gId.Sort | head -n  1 | tail -n 1)" 
		powerKwMedian="$(cat ./buf/powerData.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		powerKwMax="$(cat ./buf/powerData.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/powerData.$startDay.$gId.Sort
	else

		sort -n ./buf/powerData.$startDay.$gId > ./buf/powerData.$startDay.$gId.Sort
		rm ./buf/powerData.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi		
		echo "[DEBUG] supply Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] supply Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		
		powerKwMin="$(cat ./buf/powerData.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		powerKwMedian="$(cat ./buf/powerData.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		powerKwMax="$(cat ./buf/powerData.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/powerData.$startDay.$gId.Sort
	fi
else
	powerKwMin=NULL
	powerKwMedian=NULL
	powerKwMax=NULL
fi

echo "powerKw $powerKwMin $powerKwMedian $powerKwMax"

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
FirstQuatileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			round((count(*)*$tempFirstQuatile)/100,0)
		FROM 
			processETLold.chiller
		WHERE 
			gatewayId=$gId and  
			ts >= '$startDay $startTime' and 
			ts < '$endDay $endTime' and
			opFlag=1
	;"))
	
MedianDataCount=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			round(count(*)/2,0)
		FROM 
			processETLold.chiller
		WHERE 
			gatewayId=$gId and 
			ts >= '$startDay $startTime' and 
			ts < '$endDay $endTime' and
			opFlag=1
	;"))
	
ThirdQuatileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			round((count(*)*$tempThirdQuatile)/100,0)
		FROM 
			processETLold.chiller
		WHERE 
			gatewayId=$gId and 
			ts >= '$startDay $startTime' and 
			ts < '$endDay $endTime' and
			opFlag=1
	;"))
	
echo "  [DEBUG] Median Data Count $FirstQuatileCount $MedianDataCount $ThirdQuatileCount"
efficiencyMax=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			efficiency
		FROM 
		(
			SELECT 
				efficiency
			FROM 
			(
				SELECT 
					efficiency
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by efficiency asc
			) as a
			limit $ThirdQuatileCount
		) as a 
		order by efficiency desc
		limit 1
	;"))
	
efficiencyMin=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			efficiency
		FROM 
		(
			SELECT 
				efficiency
			FROM 
			(
				SELECT 
					efficiency
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by efficiency asc
			) as a
			limit $FirstQuatileCount
		) as a 
		order by efficiency desc
		limit 1
	;"))

efficiencyMedian=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			efficiency
		FROM 
		(
			SELECT 
				efficiency
			FROM 
			(
				SELECT 
					efficiency
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by efficiency asc
			) as a
			limit $MedianDataCount
		) as a 
		order by efficiency desc
		limit 1
	;"))

echo "  [DEBUG] Efficiency  $efficiencyMin $efficiencyMedian $efficiencyMax "

if [ -f "./buf/efficiencyDataJson.$startDay.$gId" ]; then
	rm ./buf/efficiencyDataJson.$startDay.$gId
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$stHour" == 24 ]; then
		break
	fi
	
	if [ "$stHour" == 23 ]; then
	
		
		MedianDataWhileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
				SELECT 
					round(count(*)/2,0) 
				FROM 
					processETLold.chiller 
				where 
				 gatewayId=$gId and 
				 ts >='$startDay $stHour:00' and
				 ts < '$endDay $endTime' and 
				 opFlag=1
			;"))
			
		MedianData=($(mysql -h ${host} -D$dbProcess -ss -e"
				SELECT 
					efficiency
				FROM 
				(
					SELECT 
						efficiency
					FROM 
					(
						SELECT 
							efficiency
						FROM 
							processETLold.chiller
						where 
							gatewayId=$gId and 
							ts >= '$startDay $stHour:00' and 
							ts < '$endDay $endTime' and
							opFlag=1 
							order by efficiency asc
					) as a
					limit $MedianDataWhileCount
				) as a 
				order by efficiency desc
				limit 1
			;"))
			
		jsonNum=$(($jsonNum+1))	
		
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/efficiencyDataJson.$startDay.$gId
		fi
	
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 24 0 $MedianData >> ./buf/efficiencyDataJson.$startDay.$gId

	else
		
		endHour=$(($stHour+1))
		
		MedianDataWhileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
			SELECT 
				round(count(*)/2,0) 
			FROM 
				processETLold.chiller 
			where 
			 gatewayId=$gId and 
			 ts >='$startDay $stHour:00' and
			 ts < '$startDay $endHour:00' and 
			 opFlag=1
		;"))
		
		MedianData=($(mysql -h ${host} -D$dbProcess -ss -e"
			SELECT 
				efficiency
			FROM 
			(
				SELECT 
					efficiency
				FROM 
				(
					SELECT 
						efficiency
					FROM 
						processETLold.chiller
					where 
						gatewayId=$gId and 
						ts >= '$startDay $stHour:00' and 
						ts < '$startDay $endHour:00' and
						opFlag=1 
						order by efficiency asc
				) as a
				limit $MedianDataWhileCount
			) as a 
			order by efficiency desc
			limit 1
		;"))
		
		jsonNum=$(($jsonNum+1))
		
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/efficiencyDataJson.$startDay.$gId
		fi
	
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $MedianData >> ./buf/efficiencyDataJson.$startDay.$gId

	fi

	
	stHour=$(($stHour+1))
done

efficiencyDataERROR=0
if [ -f "./buf/efficiencyDataJson.$startDay.$gId" ]; then
	efficiencyData="$(cat ./buf/efficiencyDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/efficiencyDataJson.$startDay.$gId
else
	efficiencyDataERROR=1
fi

coolingCapacityMax=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			coolingCapacity
		FROM 
		(
			SELECT 
				coolingCapacity
			FROM 
			(
				SELECT 
					coolingCapacity
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by coolingCapacity asc
			) as a
			limit $ThirdQuatileCount
		) as a 
		order by coolingCapacity desc
		limit 1
	;"))
	
coolingCapacityMin=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			coolingCapacity
		FROM 
		(
			SELECT 
				coolingCapacity
			FROM 
			(
				SELECT 
					coolingCapacity
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by coolingCapacity asc
			) as a
			limit $FirstQuatileCount
		) as a 
		order by coolingCapacity desc
		limit 1
	;"))


coolingCapacityMedian=($(mysql -h ${host} -D$dbProcess -ss -e"
		SELECT 
			coolingCapacity
		FROM 
		(
			SELECT 
				coolingCapacity
			FROM 
			(
				SELECT 
					coolingCapacity
				FROM 
					processETLold.chiller
				where 
					gatewayId=$gId and 
					ts >= '$startDay $startTime' and 
					ts < '$endDay $endTime' and
					opFlag=1 
					order by coolingCapacity asc
			) as a
			limit $MedianDataCount
		) as a 
		order by coolingCapacity desc
		limit 1
	;"))
  
echo "  [DEBUG] Cooling Capacity  $coolingCapacityMin $coolingCapacityMedian $coolingCapacityMax "

if [ -f "./buf/coolingCapacityDataJson.$startDay.$gId" ]; then
	rm ./buf/coolingCapacityDataJson.$startDay.$gId
fi

whileHour=0
jsonNum=0
stHour=0
endHour=0
while :
do
	if [ "$stHour" == 24 ]; then
		break
	fi
	
	if [ "$stHour" == 23 ]; then
	
		
		MedianDataWhileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
				SELECT 
					round(count(*)/2,0) 
				FROM 
					processETLold.chiller 
				where 
				 gatewayId=$gId and 
				 ts >='$startDay $stHour:00' and
				 ts < '$endDay $endTime' and 
				 opFlag=1
			;"))
		echo "MedianDataWhileCount:$MedianDataWhileCount"
		MedianData=($(mysql -h ${host} -D$dbProcess -ss -e"
				SELECT 
					coolingCapacity
				FROM 
				(
					SELECT 
						coolingCapacity
					FROM 
					(
						SELECT 
							coolingCapacity
						FROM 
							processETLold.chiller
						where 
							gatewayId=$gId and 
							ts >= '$startDay $stHour:00' and 
							ts < '$endDay $endTime' and
							opFlag=1 
							order by coolingCapacity asc
					) as a
					limit $MedianDataWhileCount
				) as a 
				order by coolingCapacity desc
				limit 1
			;"))
			
		jsonNum=$(($jsonNum+1))	
		
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingCapacityDataJson.$startDay.$gId
		fi
	
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 24 0 $MedianData >> ./buf/coolingCapacityDataJson.$startDay.$gId

	else
		
		endHour=$(($stHour+1))
		
		MedianDataWhileCount=($(mysql -h ${host} -D$dbProcess -ss -e"
			SELECT 
				round(count(*)/2,0) 
			FROM 
				processETLold.chiller 
			where 
			 gatewayId=$gId and 
			 ts >='$startDay $stHour:00' and
			 ts < '$startDay $endHour:00' and 
			 opFlag=1
		;"))
		echo "MedianDataWhileCount:$MedianDataWhileCount"
		MedianData=($(mysql -h ${host} -D$dbProcess -ss -e"
			SELECT 
				coolingCapacity
			FROM 
			(
				SELECT 
					coolingCapacity
				FROM 
				(
					SELECT 
						coolingCapacity
					FROM 
						processETLold.chiller
					where 
						gatewayId=$gId and 
						ts >= '$startDay $stHour:00' and 
						ts < '$startDay $endHour:00' and
						opFlag=1 
						order by coolingCapacity asc
				) as a
				limit $MedianDataWhileCount
			) as a 
			order by coolingCapacity desc
			limit 1
		;"))
		
		jsonNum=$(($jsonNum+1))
		
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingCapacityDataJson.$startDay.$gId
		fi
	
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $MedianData >> ./buf/coolingCapacityDataJson.$startDay.$gId

	fi
	
	echo "[DEBUG]$startDay $jsonNum $stHour 0 $endHour 0 $MedianData"
	stHour=$(($stHour+1))
done

coolingCapacityDataERROR=0
if [ -f "./buf/coolingCapacityDataJson.$startDay.$gId" ]; then
	coolingCapacityData="$(cat ./buf/coolingCapacityDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/coolingCapacityDataJson.$startDay.$gId
else
	coolingCapacityDataERROR=1
fi


echo "REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	coolingCapacityData,
	powerMin,powerMedian,powerMax)	
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
	if($coolingCapacityDataERROR=1,NULL,'{$coolingCapacityData}'),
	if($powerKwMin is NULL,NULL,'$powerKwMin'),
	if($powerKwMedian is NULL,NULL,'$powerKwMedian'),
	if($powerKwMax is NULL,NULL,'$powerKwMax')
);
"
mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	coolingCapacityData,
	powerMin,powerMedian,powerMax) 
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
	if($coolingCapacityDataERROR=1,NULL,'{$coolingCapacityData}'),
	if($powerKwMin is NULL,NULL,'$powerKwMin'),
	if($powerKwMedian is NULL,NULL,'$powerKwMedian'),
	if($powerKwMax is NULL,NULL,'$powerKwMax')
);
"

exit 0
