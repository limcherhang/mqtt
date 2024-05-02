#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH


if [ "${1}" == "" ]; then
        echo "請輸入chiller.sh 136"
		echo "		Gateway Id"
        exit 1
fi

host="127.0.0.1"

dbProcess="processETLold"
dbRPF="reportplatform"
dbMgmt="iotmgmt"

gId=${1}

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-1 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

sleep 10

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

	
	
	echo "  ${chillerDesc[$arrNum]} ${chillerTable[$arrNum]} ${chillerIEEE[$arrNum]} ${chillerId[$arrNum]} ${chillerTon[$arrNum]} ${chillerW[$arrNum]} "

	arrNum=$(($arrNum+1))
done

echo " "
echo "  -----------------Temp Info-------------------- "

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
			deviceDesc like 'ChilledWaterTemp#${chillerId[$arrNum]}'
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
				TempCoolingWaterReturn)
					returnCoolingValue[$arrNum]=$tempValue
					returnCoolingIEEE[$arrNum]=$deviceIEEE
					returnCoolingTable[$arrNum]=$deviceTable
					deviceDesc="TempCoolingWaterReturn#${chillerId[$arrNum]}"
					echo "  $deviceDesc ${returnCoolingIEEE[$arrNum]} ${returnCoolingTable[$arrNum]} ${returnCoolingValue[$arrNum]}"
				 ;; 
				TempCoolingWaterSupply)
					supplyCoolingValue[$arrNum]=$tempValue
					supplyCoolingIEEE[$arrNum]=$deviceIEEE
					supplyCoolingTable[$arrNum]=$deviceTable
					deviceDesc="TempCoolingWaterSupply#${chillerId[$arrNum]}"
					echo "  $deviceDesc ${supplyCoolingIEEE[$arrNum]} ${supplyCoolingTable[$arrNum]} ${supplyCoolingValue[$arrNum]}"
				 ;;
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
echo "  -----------------Main & PAHU-------------------- "
echo "  -----------------chiller Water Flow-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc = 'ChilledWaterFlowCombined#1'
		#deviceDesc != 'ChilledWaterFlow#HDR' and
		#deviceDesc like 'ChilledWaterFlow#%'
	order by deviceDesc asc
	;
"))

whileNum=0
flowMainIEEE=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

flowMainTable=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

deviceDesc=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

echo "  $deviceDesc Main $flowMainIEEE $flowMainTable "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc = 'ChilledWaterFlowCombined#2'
		#deviceDesc != 'ChilledWaterFlow#HDR' and
		#deviceDesc like 'ChilledWaterFlow#%'
	order by deviceDesc asc
	;
"))

whileNum=0
flowPAHUIEEE=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

flowPAHUTable=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

deviceDesc=${DeviceInfoBuf[$whileNum]}
whileNum=$(($whileNum+1))

echo "  $deviceDesc PAHU $flowPAHUIEEE $flowPAHUTable "


echo " "
echo "  -----------------chiller Temp-------------------- "

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,value1,value2,value3,value4
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc like 'ChilledWaterTempHDR#1' 
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
				returnMainValue=$tempValue
				returnMainIEEE=$deviceIEEE
				returnMainTable=$deviceTable
				deviceDesc="TempChilledWaterReturnMain"
				echo "  $deviceDesc $returnMainIEEE $returnMainTable $returnMainValue"
			 ;;
			TempChilledWaterSupply)
				supplyMainValue=$tempValue
				supplyMainIEEE=$deviceIEEE
				supplyMainTable=$deviceTable
				deviceDesc="TempChilledWaterSupplyMain"
				echo "  $deviceDesc $supplyMainIEEE $supplyMainTable $supplyMainValue"
			 ;;
			*)
			 ;;
			esac

		fi
	done
done

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,value1,value2,value3,value4
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc like 'ChilledWaterTempHDR#2' 
	;
	"))

echo " "
	
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
				returnPAHUValue=$tempValue
				returnPAHUIEEE=$deviceIEEE
				returnPAHUTable=$deviceTable
				deviceDesc="TempChilledWaterReturnPAHU"
				echo "  $deviceDesc $returnPAHUIEEE $returnPAHUTable $returnPAHUValue"
			 ;;
			TempChilledWaterSupply)
				supplyPAHUValue=$tempValue
				supplyPAHUIEEE=$deviceIEEE
				supplyPAHUTable=$deviceTable
				deviceDesc="TempChilledWaterSupplyPAHU"
				echo "  $deviceDesc $supplyPAHUIEEE $supplyPAHUTable $supplyPAHUValue"
			 ;;
			*)
			 ;;
			esac

		fi
	done
done
	
echo " "
echo "------Data List is done------"

echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Chiller                  #"
echo "#                            #"
echo "#****************************#"

arrNum=0
while :
do
	if [ $arrNum == $chillerNum ]; then
		break
	fi
	
	echo "  -----------------Chiller Id:${chillerId[$arrNum]}--------------------"
	
	chillerMainIEEE=${chillerIEEE[$arrNum]}
	
	capacityValue=${chillerW[$arrNum]}
	capacityTon=${chillerTon[$arrNum]}
	
	returnMainIEEE=${returnIEEE[$arrNum]}
	supplyMainIEEE=${supplyIEEE[$arrNum]}

	returnMainValue=${returnValue[$arrNum]}
	supplyMainValue=${supplyValue[$arrNum]}

	returnMainTable=${returnTable[$arrNum]}
	supplyMainTable=${supplyTable[$arrNum]}

	echo "  Gateway ID : $gId"
	echo "  Chiller Power : $chillerMainIEEE"
	echo "  Chiller Main Flow : $flowMainIEEE "
	echo "  Chiller PAHU Flow : $flowPAHUIEEE "

	echo "  Chiller Return : $returnMainIEEE $returnMainValue $returnMainTable"
	echo "  Chiller Supply : $supplyMainIEEE $supplyMainValue $supplyMainTable"
	
	echo " capacityValue : $capacityValue"
	echo " capacityTon : $capacityTon"
	
	chillerFlagNum=1
	flagNum=0
	while :
	do
		if [ $flagNum == $chillerNum ]; then
			break
		fi
		
		if [ $flagNum == $arrNum ]; then
			echo " ${chillerIEEE[$flagNum]} is myself"
		else
		
			chillerFlagNum=($(mysql -h ${host} -D$dbMgmt -ss -e"
			SELECT 
				$chillerFlagNum+if((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) > 10000,1,0) as opFlag
			FROM 
				iotmgmt.pm 
			where 
				ieee='${chillerIEEE[$flagNum]}' and 
				receivedSync >='$startRunTime' and 
				receivedSync < '$endRunTime'
			;"))
			
			echo " ${chillerIEEE[$flagNum]} chillerFlagNum:$chillerFlagNum"
		fi
		
		flagNum=$(($flagNum+1))
	done
	
	if [ "$chillerFlagNum" == "" ]; then
		echo "chillerFlagNum is NULL $chillerFlagNum"
	
	else
	
	#coolingCapacity
	coolingCapacityData=($(mysql -h ${host} -D$dbMgmt -ss -e"select 
							  Round((977*4.2*(truncate(tempReturn-tempSupply,2))*truncate(flowRate,2))/12660.66,3),#3600*3.51685 =12660.66
							  Round(tempReturn-tempSupply,2) as delta,
							  tempReturn,
							  tempSupply,
							  flowRate
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($supplyMainValue,2) as tempSupply
								 FROM 
									$supplyMainTable
								  WHERE 
									ieee='$supplyMainIEEE' and 
									$supplyMainValue >= 0 and
									$supplyMainValue is not NULL and
									receivedSync >='$startRunTime' and 
									receivedSync < '$endRunTime'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($returnMainValue,2) as tempReturn
								FROM 
									$returnMainTable
								WHERE 
									ieee='$returnMainIEEE' and  
									$returnMainValue >= 0 and
									$returnMainValue is not NULL and
									receivedSync >='$startRunTime' and 
									receivedSync < '$endRunTime'
									group by time
							) as b
							on a.time=b.time

							INNER join
							(
							 SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,truncate(sum(flowRate)/$chillerFlagNum,2) as flowRate
							  FROM 
								$flowMainTable
							  WHERE 
								(ieee='$flowMainIEEE' or ieee='$flowPAHUIEEE') and
								flowRate >= 0 and
								flowRate is not NULL and
								receivedSync >='$startRunTime' and 
								receivedSync < '$endRunTime'
								group by time
							) as c
							on a.time=c.time;
		"))
		
		coolingCapacityDataNum=0
		coolingCapacity=${coolingCapacityData[$coolingCapacityDataNum]}
		echo "Cooling Capacity ${coolingCapacityData[$coolingCapacityDataNum]}"
		
		coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
		echo "Cooling Delta Temp ${coolingCapacityData[$coolingCapacityDataNum]}"
		
		coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
		echo "Cooling Return Temp ${coolingCapacityData[$coolingCapacityDataNum]}"
		
		coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
		echo "Cooling Supply Temp ${coolingCapacityData[$coolingCapacityDataNum]}"
		
		coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
		echo "Cooling Flow Temp ${coolingCapacityData[$coolingCapacityDataNum]}"

	    if [ "$coolingCapacity" == "" ]; then
		  echo "coolingCapacity is NULL $coolingCapacity"
	    else
			efficiencyData=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT 
				round(((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000)/$coolingCapacity,2),
				if((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) > 10000,1,0) as opFlag
			  FROM 
				iotmgmt.pm 
			  where 
				ieee='$chillerMainIEEE' and 
				receivedSync >='$startRunTime' and 
				receivedSync < '$endRunTime'
				;"))
				
			dataNum=0
			#efficiency
			efficiency=${efficiencyData[$dataNum]}
			echo "Efficiency Data ${efficiencyData[$dataNum]}"
			
			#opFlag
			dataNum=$(($dataNum+1))
			opFlag=${efficiencyData[$dataNum]}
			echo "opFlag ${efficiencyData[$dataNum]}"
			
			if [ "$efficiency" == "" ]; then
				echo "efficiency=$efficiency opFlag=$opFlag"
			else
				echo "replace INTO chiller(ts,gatewayId,name,
					opFlag,
					coolingCapacity,
					efficiency)VALUES
					('$startRunTime','$gId','chiller#${chillerId[$arrNum]}','$opFlag','$coolingCapacity',if($efficiency is NULL,NULL,'$efficiency'));
				"
				
				if [ "$coolingCapacity" != "NULL" ]; then
					mysql -h ${host} -D$dbProcess -ss -e"replace INTO chiller(ts,gatewayId,name,
						opFlag,
						coolingCapacity,
						efficiency)VALUES
						('$startRunTime','$gId','chiller#${chillerId[$arrNum]}','$opFlag','$coolingCapacity',if($efficiency is NULL,NULL,'$efficiency'));
					"
				else
					echo " coolingCapacity $coolingCapacity == NULL"
				fi
				
			fi
		fi
	fi
	arrNum=$(($arrNum+1))
done

		
exit 0
