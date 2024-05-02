#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
	satrtDate=$(date "+%Y-%m-%d" --date='-1 day')
	endDate=$(date "+%Y-%m-%d")
	echo "請輸入bash chillerSitePerformance.sh $satrtDate 00:00 $endDate 00:00 106"
	echo "   satrt date"
	echo "   satrt time"
	echo "   end date"
	echo "   end time"
	echo "   Gateway ID"
	exit 1
fi

#defined value
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

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

echo "  ----------------Gateway ID--------------------- "
echo "  $gId"
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
	
	echo "  ${chillerId[$arrNum]} ${chillerDesc[$arrNum]} ${chillerIEEE[$arrNum]} ${chillerTon[$arrNum]} ${chillerW[$arrNum]}"
	
	arrNum=$(($arrNum+1))
done
echo " "
echo "  -----------------Chiller Water Flow-------------------- "

chilledWaterFlowNum=0
chilledWaterFlowNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc != 'ChilledWaterFlow#HDR' and
	deviceDesc like 'ChilledWaterFlow#%'
;
")

if [ $chilledWaterFlowNum -ge 1 ]; then

	DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
		FROM iotmgmtChiller.vDeviceInfo 
		where 
			gatewayId=$gId and 
			deviceDesc != 'ChilledWaterFlow#HDR' and
			deviceDesc like 'ChilledWaterFlow#%'
		order by deviceDesc asc
		;
	"))

	echo ""
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
		
		deviceDesc=${DeviceInfoBuf[$whileNum]}
		whileNum=$(($whileNum+1))
		
		echo "  ${deviceDesc[$arrNum]} ${flowIEEE[$arrNum]} ${flowTable[$arrNum]}"
		arrNum=$(($arrNum+1))
	done
	
else

	chilledWaterFlowHDRNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and deviceDesc = 'ChilledWaterFlow#HDR'
	;
	")
	
	chilledWaterFlowCombinedNum=0
	if [ $chilledWaterFlowHDRNum -ge 1 ]; then
		echo "  Chiller Water Flow HDR Num:$chilledWaterFlowHDRNum"
		
		DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
				FROM iotmgmtChiller.vDeviceInfo 
				where 
					gatewayId=$gId and deviceDesc = 'ChilledWaterFlow#HDR'
				;
		"))
		
		flowHDRIEEE=${DeviceInfoBuf[0]}
		flowHDRTable=${DeviceInfoBuf[1]}
		flowHDRDeviceDesc=${DeviceInfoBuf[2]}
		
		echo "  $flowHDRDeviceDesc $flowHDRIEEE $flowHDRTable"
		
	else
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
			
			flowCombinedTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
			whileNum=$(($whileNum+1))
			
			flowCombinedDeviceDesc[$arrNum]=${DeviceInfoBuf[$whileNum]}
			whileNum=$(($whileNum+1))
			
			echo "  ${flowCombinedDeviceDesc[$arrNum]} ${flowCombinedIEEE[$arrNum]} ${flowCombinedTable[$arrNum]}"
			arrNum=$(($arrNum+1))
		done
	fi
fi
echo " "
echo "  -----------------Temp Info-------------------- "
coolingSupplyNum=0
coolingReturnNum=0
TempChilledWaterReturnTrue=0
TempChilledWaterSupplyTrue=0

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
		
		# echo "  $deviceIEEE $deviceTable ${deviceTempName[0]} ${deviceTempName[1]} ${deviceTempName[2]} ${deviceTempName[3]}"
		# echo "  "
		
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
					echo "  TempChilledWaterReturn ${returnIEEE[$arrNum]} ${returnTable[$arrNum]} ${returnValue[$arrNum]}"
					TempChilledWaterReturnTrue=1
				 ;;
				TempChilledWaterSupply)
					supplyValue[$arrNum]=$tempValue
					supplyIEEE[$arrNum]=$deviceIEEE
					supplyTable[$arrNum]=$deviceTable
					echo "  TempChilledWaterSupply ${supplyIEEE[$arrNum]} ${supplyTable[$arrNum]} ${supplyValue[$arrNum]}"
					TempChilledWaterSupplyTrue=1
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

echo "#************************************************#"
echo "#Daily Activity Overview & Performance Overview  #"
echo "#************************************************#"



arrNum=0
while :
do
	
	if [ $arrNum == $chillerNum ]; then
		break
	fi

	chiName=${chillerDesc[$arrNum]}
	chiId=${chillerId[$arrNum]}
	
	#echo "[DEBUG]$startDay $gId $chiName $chiId"
	
	echo "$startDay" 
	echo "$gId"
	echo "$chiName"
	echo "$chiId"
	
	echo "  Chiller Id:${chillerId[$arrNum]}"
	
	chillerTime=($(mysql -h ${host} -D$dbRPF -ss -e"
	SELECT 
	   date_format(startTime, '%H:%i') as startTime,
	   date_format(endTime, '%H:%i') as endTime,
	   totalPowerWh 
	FROM 
	  reportplatform.dailyChillerData
	WHERE 
	  gatewayId=$gId and 
	  operationDate='$startDay' and 
	  chillerId='$chiId' and 
	  operationFlag=1
	;
	"))
	
	if [ -f "./data/efficiency.$startDay.$gId.$chiId" ]; then
		rm ./data/efficiency.$startDay.$gId.$chiId
	fi
	
	if [ -f "./data/coolingCapacity.$startDay.$gId.$chiId" ]; then
		rm ./data/coolingCapacity.$startDay.$gId.$chiId
	fi
	
	whileHour=0
	while :
	do
		if [ "$whileHour" == 24 ]; then
			break
		fi

		if [ -f "./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour
		fi
		if [ -f "./data/efficiency.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/efficiency.$startDay.$gId.$chiId.$whileHour
		fi

		if [ -f "./data/watt.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/watt.$startDay.$gId.$chiId.$whileHour
		fi
		
		if [ -f "./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour
		fi
		
		if [ -f "./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour
		fi
		
		if [ -f "./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour" ]; then
			rm ./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour
		fi

		whileHour=$(($whileHour+1))
	done
	
	if [ "${chillerTime[0]}" == "" ]; then
		echo "   Operation OFF"
	else
		echo "  --Daily Activity Overview--"
		#Activity
		activityNum=($(mysql -h ${host} -D$dbRPF -ss -e"
		  SELECT count(*) as ActivityCount 
		  FROM 
			reportplatform.dailyChillerData
		  WHERE 
			 gatewayId=$gId and 
			 operationDate='$startDay' and 
			 chillerDescription='$chiName';
		"))
		
		
		if [ "$activityNum" == "" ]; then
			echo "[ERROR]activity no data gatewayId=$gId operationDate='$startDay' chillerDescription='$chiName'"
		else
		
			if [ $activityNum == 1 ] || [ $activityNum == 0 ]; then
				activityNum=0
			else
				activityNum=$(($activityNum-1))
			fi
			
			echo "    Activity $activityNum"

			#Activity State
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
					reportplatform.dailyChillerData
				WHERE 
					gatewayId=$gId and 
					operationDate='$startDay' and 
					chillerDescription='$chiName' and 
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
					
								  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/activityState.$startDay.$gId.$chiId
					fi
					
					#"state1": {"hours": 8,"minutes": 52,"previous": 0,"new": 1}
					if [ $state == 1 ]; then
						printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 0,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/activityState.$startDay.$gId.$chiId
					elif [ $state == 0 ]; then
						printf "\"state%d\": {\"hours\": %d,\"minutes\": %d,\"previous\": 1,\"new\": %d}"  $jsonNum $hours $minutes $state >> ./data/activityState.$startDay.$gId.$chiId
					fi
					jsonNum=$(($jsonNum+1))
				done

				printf "\n">> ./data/activityState.$startDay.$gId.$chiId
			fi
			
			echo " "
			echo "  --Daily Performance Overview--"
			
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

				wattData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT 
						date_format(receivedSync, '%H') as hoursNum,
						date_format(receivedSync, '%i') as minuteNum,
						(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as watt
					FROM 
						$pmTable 
					WHERE 
						ieee='${chillerIEEE[$arrNum]}' and 
						receivedSync>='$startDay $startRunTime' and 
						receivedSync<='$startDay $endRunTime:59'
					GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
				;
				"))
				if [ $chilledWaterFlowNum -ge 1 ]; then
					echo "  chilledWaterFlowNum:$chilledWaterFlowNum >= 1"
					if [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ]; then
						
						if [ $historyTable == 1 ]; then
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}_$dbdataMonth
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}_$dbdataMonth
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as b
							on a.time=b.time

							INNER join
							(
								SELECT 
									date_format(receivedSync, '%Y-%m-%d %H:%i') as time,
									Round(flowRate,2) as flowRate 
								FROM 
									${flowTable[$arrNum]}_$dbdataMonth
								WHERE 
									ieee='${flowIEEE[$arrNum]}' and  
									flowRate >= 0 and
									flowRate is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
								group by time
							) as c
							on a.time=c.time;
							"))
						else
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
								group by time
							) as b
							on a.time=b.time

							INNER join
							(
								SELECT 
									date_format(receivedSync, '%Y-%m-%d %H:%i') as time,
									Round(flowRate,2) as flowRate 
								FROM 
									${flowTable[$arrNum]}
								WHERE 
									ieee='${flowIEEE[$arrNum]}' and  
									flowRate >= 0 and
									flowRate is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
								group by time
							) as c
							on a.time=c.time;
							"))
						fi
					else
						echo "[ERROR] [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ]"
					fi				
				elif [ $chilledWaterFlowCombinedNum -ge 1 ]; then
					echo "  chilledWaterFlowCombinedNum:$chilledWaterFlowCombinedNum >= 1"
					if [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ]; then
						
						if [ $historyTable == 1 ]; then
						
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}_$dbdataMonth
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}_$dbdataMonth
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as b
							on a.time=b.time

								INNER join
								(
								 SELECT ts1 as time,Round(flowRate,2) as flowRate
								  FROM 
									(Select a.syncTime as ts1,b.syncTime as ts2,a.flowRate+b.flowRate as flowRate
										from
										(
										 SELECT 
											date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,
											Round(flowRate,2) as flowRate 
										FROM 
											${flowCombinedTable[0]}_$dbdataMonth
										WHERE 
											ieee='${flowCombinedIEEE[0]}' and  
											flowRate >= 0 and
											flowRate is not NULL and
											receivedSync>='$startDay $startRunTime' and 
											receivedSync<='$startDay $endRunTime:59'
											group by syncTime
										)
										as a
										 left join
										(
										 SELECT 
											date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,
											Round(flowRate,2) as flowRate 
										 FROM 
										   ${flowCombinedTable[1]}_$dbdataMonth
										  WHERE 
											ieee='${flowCombinedIEEE[1]}' and  
											flowRate >= 0 and
											flowRate is not NULL and
											receivedSync>='$startDay $startRunTime' and 
											receivedSync<='$startDay $endRunTime:59'
											group by syncTime
										)
										as b
										on a.syncTime=b.syncTime
									) as d
								) as c
								on a.time=c.time;
							"))
						else
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as b
							on a.time=b.time

								INNER join
								(
								 SELECT ts1 as time,Round(flowRate,2) as flowRate
								  FROM 
									(Select a.syncTime as ts1,b.syncTime as ts2,a.flowRate+b.flowRate as flowRate
										from
										(
										 SELECT 
											date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,
											Round(flowRate,2) as flowRate 
										FROM 
											${flowCombinedTable[0]}
										WHERE 
											ieee='${flowCombinedIEEE[0]}' and  
											flowRate >= 0 and
											flowRate is not NULL and
											receivedSync>='$startDay $startRunTime' and 
											receivedSync<='$startDay $endRunTime:59'
											group by syncTime
										)
										as a
										 left join
										(
										 SELECT 
											date_format(receivedSync, '%Y-%m-%d %H:%i') syncTime,
											Round(flowRate,2) as flowRate 
										 FROM 
										   ${flowCombinedTable[1]}
										  WHERE 
											ieee='${flowCombinedIEEE[1]}' and  
											flowRate >= 0 and
											flowRate is not NULL and
											receivedSync>='$startDay $startRunTime' and 
											receivedSync<='$startDay $endRunTime:59'
											group by syncTime
										)
										as b
										on a.syncTime=b.syncTime
									) as d
								) as c
								on a.time=c.time;
							"))
						fi
					else
						echo "[ERROR] [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ]"
					fi
				else
					if [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ] && [ $chilledWaterFlowHDRNum -ge 1 ]; then
						echo "  chilledWaterFlowHDRNum:$chilledWaterFlowHDRNum >= 1"
						if [ $historyTable == 1 ]; then
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}_$dbdataMonth
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}_$dbdataMonth
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as b
							on a.time=b.time

							INNER join
							(
							 SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(avg(flowRate),2) as flowRate
							  FROM 
								${flowHDRTable}_$dbdataMonth
							  WHERE 
								ieee='$flowHDRIEEE' and 
								flowRate >= 0 and
								flowRate is not NULL and
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59'
								group by time
							) as c
							on a.time=c.time;
						"))
						else
						coolingCapacityData=($(mysql -h ${host} -D$dbdata -ss -e"select 
							  date_format(a.time, '%H') as hoursNum,
							  date_format(a.time, '%i') as minuteNum,
							  Round(tempReturn-tempSupply,2) as delta,
							  Round(tempReturn,2),
							  Round(tempSupply,2),
							  truncate(flowRate,2)
							FROM
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${supplyValue[$arrNum]}),2) as tempSupply
								 FROM 
									${supplyTable[$arrNum]}
								  WHERE 
									ieee='${supplyIEEE[$arrNum]}' and 
									${supplyValue[$arrNum]} >= 0 and
									${supplyValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as a

							INNER join
							(
							SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate(avg(${returnValue[$arrNum]}),2) as tempReturn
								FROM 
									${returnTable[$arrNum]}
								WHERE 
									ieee='${returnIEEE[$arrNum]}' and  
									${returnValue[$arrNum]} >= 0 and
									${returnValue[$arrNum]} is not NULL and
									receivedSync>='$startDay $startRunTime' and 
									receivedSync<='$startDay $endRunTime:59'
									group by time
							) as b
							on a.time=b.time

							INNER join
							(
							 SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(avg(flowRate),2) as flowRate
							  FROM 
								$flowHDRTable 
							  WHERE 
								ieee='$flowHDRIEEE' and 
								flowRate >= 0 and
								flowRate is not NULL and
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59'
								group by time
							) as c
							on a.time=c.time;
						"))
						fi
					else
						echo "[ERROR] [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ] && [ $chilledWaterFlowHDRNum -ge 1 ]"
					fi
				fi
				
				wattDataNum=0
				while :
				do
					if [ "${wattData[$wattDataNum]}" == "" ]; then
						break
					fi
					
					wattHoursNum=${wattData[$wattDataNum]}
					hoursNum=$((10#$wattHoursNum))
					#echo "watt Hours $wattHoursNum"
					wattDataNum=$(($wattDataNum+1))
					
					wattMinuteNum=${wattData[$wattDataNum]}
					#echo "watt Minute $wattMinuteNum"
					wattDataNum=$(($wattDataNum+1))
					
					watt=${wattData[$wattDataNum]}
					#echo "watt $watt"
					wattDataNum=$(($wattDataNum+1))
					
					#echo "[DEBUG]$startDay $wattHoursNum:$wattMinuteNum"
					coolingCapacityDataNum=0
					while :
					do
						if [ "${coolingCapacityData[$coolingCapacityDataNum]}" == "" ]; then
							coolingCapacityDataNum=0
							break
						fi
						
						coolingHoursNum=${coolingCapacityData[$coolingCapacityDataNum]}
						#echo "Cooling Hours $coolingHoursNum"
						coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
						
						coolingMinuteNum=${coolingCapacityData[$coolingCapacityDataNum]}
						#echo "Cooling Minute  $coolingMinuteNum"
						coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
						
						if [ "$coolingHoursNum" == "$wattHoursNum" ] && [ "$coolingMinuteNum" == "$wattMinuteNum" ]; then
							#echo "[DEBUG]$coolingHoursNum==$wattHoursNum $coolingMinuteNum==$wattMinuteNum"
							
							#echo "Cooling Delta Temp $coolingDeltaTemp"
							deltaData=${coolingCapacityData[$coolingCapacityDataNum]}
							echo "$deltaData" >> ./data/tempDeltaHours.$startDay.$gId.$chiId.$hoursNum
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							
							echo "Cooling Return Temp ${coolingCapacityData[$coolingCapacityDataNum]}"
							echo "${coolingCapacityData[$coolingCapacityDataNum]}" >> ./data/tempReturnHours.$startDay.$gId.$chiId.$hoursNum
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							
							echo "Cooling Supply Temp ${coolingCapacityData[$coolingCapacityDataNum]}"
							echo "${coolingCapacityData[$coolingCapacityDataNum]}" >> ./data/tempSupplyHours.$startDay.$gId.$chiId.$hoursNum			
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							
							flowData=${coolingCapacityData[$coolingCapacityDataNum]}
							#echo "Cooling Flow $coolingFlow"
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							
							break
						else
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
							coolingCapacityDataNum=$(($coolingCapacityDataNum+1))
						fi
					done
					
					if [ $coolingCapacityDataNum == 0 ]; then
						echo "[ERROR]$startDay $wattHoursNum:$wattMinuteNum is no Cooling Capacity Data"
					else
						
						chilledWaterFlowArrNum=0
						chilledFlowRunNum=1
						if [ $chilledWaterFlowNum -ge 1 ]; then
							echo "  chilledWaterFlowNum:$chilledWaterFlowNum"
						else
							echo "  cheack chiller Data"
							while :
							do
								if [ $chilledWaterFlowArrNum == $chillerNum ]; then
									break
								fi
							
								if [ $chilledWaterFlowArrNum != $arrNum ]; then
									cheackDataW=($(mysql -h ${host} -D$dbdata -ss -e"SELECT 
											(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) as watt
										FROM  
											(SELECT * FROM 
													$pmTable
												WHERE 
													ieee='${chillerIEEE[$chilledWaterFlowArrNum]}' and 
													receivedSync>='$startDay $wattHoursNum:$wattMinuteNum' limit 5
												) as a 
										WHERE 
											date_format(receivedSync, '%Y-%m-%d %H:%i')='$startDay $wattHoursNum:$wattMinuteNum';
									"))
									if [ "$cheackDataW" == "" ]; then
										echo "${chillerIEEE[$chilledWaterFlowArrNum]} $startDay $wattHoursNum:$wattMinuteNum is NULL"
									else
										
										if [ $cheackDataW -ge 10000 ]; then
											chilledFlowRunNum=$(($chilledFlowRunNum+1))
											#echo "[DEBUG]${chillerIEEE[$chilledWaterFlowArrNum]} $startDay $wattHoursNum:$wattMinuteNum $cheackDataW chilledFlowRunNum:$chilledFlowRunNum"
										fi
									fi
								fi
								
								chilledWaterFlowArrNum=$(($chilledWaterFlowArrNum+1))
							done
						fi
						if [ "$flowData" == "0.00" ]; then
						
							echo "[ERROR] flow Data is $flowData"
							#coolingCapacity
							#echo "coolingCapacity $coolingCapacity"
							echo "0" >> ./data/coolingCapacity.$startDay.$gId.$chiId
							echo "0" >> ./data/coolingCapacity.$startDay.$gId.$chiId.$hoursNum
							
							#efficiency=(watt/coolingCapacity)
							#echo "$watt/$coolingCapacity"
							echo "0" >> ./data/efficiency.$startDay.$gId.$chiId
							echo "0" >> ./data/efficiency.$startDay.$gId.$chiId.$hoursNum
							
						else
							echo "scale=3;$flowData/$chilledFlowRunNum"|bc > ./buf/flowData.$startDay.$gId.$chiId
							flowData="$(cat ./buf/flowData.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
							
							#echo "[DEBUG]$startDay $wattHoursNum:$wattMinuteNum deltaData:$deltaData flowData:$flowData"	
							echo "scale=3;$deltaData*4.2*997*$flowData/(3600*3.5168525)"|bc > ./buf/coolingCapacity.$startDay.$gId.$chiId
							
							coolingCapacity="$(cat ./buf/coolingCapacity.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"

							#coolingCapacity
							#echo "coolingCapacity $coolingCapacity"
							echo "$coolingCapacity" >> ./data/coolingCapacity.$startDay.$gId.$chiId
							echo "$coolingCapacity" >> ./data/coolingCapacity.$startDay.$gId.$chiId.$hoursNum
							
							#efficiency=(watt/coolingCapacity)
							#echo "$watt/$coolingCapacity"
							echo "scale=2;$watt/$coolingCapacity"|bc >> ./data/efficiency.$startDay.$gId.$chiId
							echo "scale=2;$watt/$coolingCapacity"|bc >> ./data/efficiency.$startDay.$gId.$chiId.$hoursNum
						fi
						
						echo "[DEBUG]$startDay $wattHoursNum:$wattMinuteNum deltaData:$deltaData flowData/$chilledFlowRunNum:$flowData coolingCapacity:$coolingCapacity  efficiency:$watt/$coolingCapacity"
					fi
					
					#powerConsumptionData
					echo "$watt" >> ./data/watt.$startDay.$gId.$chiId.$hoursNum
					
					#avgPowerLoading=(watt/capacityW)
					echo "scale=2;$powerLoading+($watt/(${chillerW[$arrNum]}/1000))"|bc > ./buf/avgPowerLoading.$startDay.$gId.$chiId
					powerLoading="$(cat ./buf/avgPowerLoading.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					
					#echo "$watt+$dataKWTotal"
					echo "scale=2;$watt+$dataKWTotal"|bc > ./buf/chillerPowerMeterKW.$startDay.$gId.$chiId
					dataKWTotal="$(cat ./buf/chillerPowerMeterKW.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					
					dataKWCount=$(($dataKWCount+1))
				done
			done
				
			if [ -f "./data/efficiency.$startDay.$gId.$chiId" ]; then

				countNum="$(cat ./data/efficiency.$startDay.$gId.$chiId |wc -l)"

				if [ $countNum == 0 ]; then

					efficiencyMin=NULL
					efficiencyMedian=NULL
					efficiencyMax=NULL
					
				elif [ $countNum == 1 ]; then

					sort -n ./data/efficiency.$startDay.$gId.$chiId > ./data/efficiency.$startDay.$gId.$chiId.sort
					rm ./data/efficiency.$startDay.$gId.$chiId
					
					efficiencyMin="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					efficiencyMedian="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					efficiencyMax="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort  | head -n 1 | tail -n 1)" 
					
					rm ./data/efficiency.$startDay.$gId.$chiId.sort
				else

					sort -n ./data/efficiency.$startDay.$gId.$chiId > ./data/efficiency.$startDay.$gId.$chiId.sort
					rm ./data/efficiency.$startDay.$gId.$chiId
					
					echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId| head -n 1 | tail -n 1)" 
					if [ $tempFirstQuatileNum == 0 ]; then
						tempFirstQuatileNum=1
						echo "[DEBUG] tempFirstQuatile is 0 "	
					fi
					echo "[DEBUG] Efficiency Num:$tempFirstQuatileNum"

					echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					echo "[DEBUG] Efficiency Num:$tempThirdQuatileNum"	

					rm ./buf/data.$startDay.$gId.$chiId
					
					medianNum=$(($countNum/2))
					
					efficiencyMin="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
					efficiencyMedian="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n $medianNum | tail -n 1)" 
					efficiencyMax="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
					
					# efficiencyMin="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					# efficiencyMedian="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n $medianNum | tail -n 1)" 
					# efficiencyMax="$(cat ./data/efficiency.$startDay.$gId.$chiId.sort | head -n $countNum | tail -n 1)" 

					rm ./data/efficiency.$startDay.$gId.$chiId.sort
				fi
			else
				efficiencyMin=NULL
				efficiencyMedian=NULL
				efficiencyMax=NULL
			fi
			
			if [ -f "./data/coolingCapacity.$startDay.$gId.$chiId" ]; then

				countNum="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId |wc -l)"

				if [ $countNum == 0 ]; then

					coolingCapacityMin=NULL
					coolingCapacityMedian=NULL
					coolingCapacityMax=NULL
					
				elif [ $countNum == 1 ]; then

					sort -n ./data/coolingCapacity.$startDay.$gId.$chiId > ./data/coolingCapacity.$startDay.$gId.$chiId.sort
					rm ./data/coolingCapacity.$startDay.$gId.$chiId
					
					coolingCapacityMin="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					coolingCapacityMedian="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					coolingCapacityMax="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort  | head -n 1 | tail -n 1)" 
					
					rm ./data/coolingCapacity.$startDay.$gId.$chiId.sort
				else

					sort -n ./data/coolingCapacity.$startDay.$gId.$chiId > ./data/coolingCapacity.$startDay.$gId.$chiId.sort
					rm ./data/coolingCapacity.$startDay.$gId.$chiId
					
				    echo "scale=0;$(($countNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId| head -n 1 | tail -n 1)" 
					if [ $tempFirstQuatileNum == 0 ]; then
						tempFirstQuatileNum=1
						echo "[DEBUG] tempFirstQuatile is 0 "	
					fi
					echo "[DEBUG] Cooling Capacity Num:$tempFirstQuatileNum"

					echo "scale=0;$(($countNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					echo "[DEBUG] Cooling Capacity Num:$tempThirdQuatileNum"	

					rm ./buf/data.$startDay.$gId.$chiId

					medianNum=$(($countNum/2))
					
					coolingCapacityMin="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n $tempFirstQuatileNum | tail -n 1)" 
					coolingCapacityMedian="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n $medianNum | tail -n 1)" 
					coolingCapacityMax="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n $tempThirdQuatileNum | tail -n 1)" 
					
					# coolingCapacityMin="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n 1 | tail -n 1)" 
					# coolingCapacityMedian="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n $medianNum | tail -n 1)" 
					# coolingCapacityMax="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.sort | head -n $countNum | tail -n 1)" 

					rm ./data/coolingCapacity.$startDay.$gId.$chiId.sort
				fi
			else
				coolingCapacityMin=NULL
				coolingCapacityMedian=NULL
				coolingCapacityMax=NULL
			fi
			#total Operation Minutes
			echo "total Operation Minutes: $totalRunMinutes" 

			#Avg Power Consumption
			echo "Avg Power Consumption: $dataKWTotal/$dataKWCount"

			#Total Energy Consumption(Wh)
			echo "Total Energy Consumption(Wh): $totalEnergyConsumption" 
			
			#Avg Power Loading
			echo "Avg Power Loading: $powerLoading/$dataKWCount"

			#Efficiency
			echo "    efficiencyMin    $efficiencyMin"
			echo "    efficiencyMedian $efficiencyMedian"
			echo "    efficiencyMax    $efficiencyMax"
			
			#Cooling Capacity
			echo "    CoolingCapacity Min    $coolingCapacityMin"
			echo "    CoolingCapacity Median $coolingCapacityMedian"
			echo "    CoolingCapacity Max    $coolingCapacityMax"
			
			if [ -f "./buf/tempSupply.$startDay.$gId.$chiId" ]; then
				rm ./buf/tempSupply.$startDay.$gId.$chiId
			fi
			
			if [ -f "./buf/tempReturn.$startDay.$gId.$chiId" ]; then
				rm ./buf/tempReturn.$startDay.$gId.$chiId
			fi
			
			if [ -f "./buf/tempDelta.$startDay.$gId.$chiId" ]; then
				rm ./buf/tempDelta.$startDay.$gId.$chiId
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
				
				#watt
				whileNum=$(($whileNum+1))
				
				if [ $TempChilledWaterSupplyTrue == 1 ]; then
				
					if [ $historyTable == 1 ]; then
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT Round(${supplyValue[$arrNum]},2) as tempSupply
							 FROM 
								${supplyTable[$arrNum]}_$dbdataMonth
							  WHERE ieee='${supplyIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${supplyValue[$arrNum]} >= 0 and
								${supplyValue[$arrNum]} is not NULL
							GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
						"))
					else
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT Round(${supplyValue[$arrNum]},2) as tempSupply
							 FROM 
								${supplyTable[$arrNum]}
							  WHERE ieee='${supplyIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${supplyValue[$arrNum]} >= 0 and
								${supplyValue[$arrNum]} is not NULL
							GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
						"))
					fi
					dataNum=0
					while :
					do
						if [ "${tempData[$dataNum]}" == "" ]; then
							break
						fi
					
						echo "${tempData[$dataNum]}" >> ./buf/tempSupply.$startDay.$gId.$chiId
						dataNum=$(($dataNum+1))
					done
					
				fi

				if [ $TempChilledWaterReturnTrue == 1 ]; then
				
					if [ $historyTable == 1 ]; then
					
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT Round(${returnValue[$arrNum]},2) as tempReturn
							FROM 
								${returnTable[$arrNum]}_$dbdataMonth
							  WHERE ieee='${returnIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${returnValue[$arrNum]} >= 0 and
								${returnValue[$arrNum]} is not NULL
							GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
						"))
						
					else
					
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT Round(${returnValue[$arrNum]},2) as tempReturn
							FROM 
								${returnTable[$arrNum]}
							  WHERE ieee='${returnIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${returnValue[$arrNum]} >= 0 and
								${returnValue[$arrNum]} is not NULL
							GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i');
						"))
						
					fi
					dataNum=0
					while :
					do
						if [ "${tempData[$dataNum]}" == "" ]; then
							break
						fi

						echo "${tempData[$dataNum]}" >> ./buf/tempReturn.$startDay.$gId.$chiId
						dataNum=$(($dataNum+1))
					done
				fi
				
				if [ $TempChilledWaterReturnTrue == 1 ] && [ $TempChilledWaterSupplyTrue == 1 ]; then
					if [ $historyTable == 1 ]; then
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"select Round(tempReturn-tempSupply,2) as delta
						from
						(
						SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,Round(${supplyValue[$arrNum]},2) as tempSupply
							 FROM 
								${supplyTable[$arrNum]}_$dbdataMonth
							  WHERE ieee='${supplyIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${supplyValue[$arrNum]} >= 0 and
								${supplyValue[$arrNum]} is not NULL
							GROUP BY time
						) as a

						INNER join
						(
						SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,Round(${returnValue[$arrNum]},2) as tempReturn
							FROM 
								${returnTable[$arrNum]}_$dbdataMonth
							WHERE ieee='${returnIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${returnValue[$arrNum]} >= 0 and
								${returnValue[$arrNum]} is not NULL
							GROUP BY time
						) as b
						on a.time=b.time;
						"))
					else
						tempData=($(mysql -h ${host} -D$dbdata -ss -e"select Round(tempReturn-tempSupply,2) as delta
						from
						(
						SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,Round(${supplyValue[$arrNum]},2) as tempSupply
							 FROM 
								${supplyTable[$arrNum]}
							  WHERE ieee='${supplyIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${supplyValue[$arrNum]} >= 0 and
								${supplyValue[$arrNum]} is not NULL
							GROUP BY time
						) as a

						INNER join
						(
						SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,Round(${returnValue[$arrNum]},2) as tempReturn
							FROM 
								${returnTable[$arrNum]}
							WHERE ieee='${returnIEEE[$arrNum]}' and 
								receivedSync>='$startDay $startRunTime' and 
								receivedSync<='$startDay $endRunTime:59' and
								${returnValue[$arrNum]} >= 0 and
								${returnValue[$arrNum]} is not NULL
							GROUP BY time
						) as b
						on a.time=b.time;
						"))
					fi
					dataNum=0
					while :
					do
						if [ "${tempData[$dataNum]}" == "" ]; then
							break
						fi
						
						echo "${tempData[$dataNum]}" >> ./buf/tempDelta.$startDay.$gId.$chiId
						
						dataNum=$(($dataNum+1))
					done
				fi
			done
				
			if [ -f "./buf/tempSupply.$startDay.$gId.$chiId" ]; then

				tempCountNum="$(cat ./buf/tempSupply.$startDay.$gId.$chiId |wc -l)"

				if [ $tempCountNum == 0 ]; then

					tempSupplyMin=NULL
					tempSupplyMedian=NULL
					tempSupplyMax=NULL
					
				elif [ $tempCountNum == 1 ]; then

					sort -n ./buf/tempSupply.$startDay.$gId.$chiId > ./buf/tempSupply.$startDay.$gId.$chiId.Sort
					rm ./buf/tempSupply.$startDay.$gId.$chiId
					
					tempSupplyMin="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort | head -n  1 | tail -n 1)" 
					tempSupplyMedian="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort | head -n 1 | tail -n 1)" 
					tempSupplyMax="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort  | head -n 1 | tail -n 1)" 
					
					rm ./buf/tempSupply.$startDay.$gId.$chiId.Sort
				else

					sort -n ./buf/tempSupply.$startDay.$gId.$chiId > ./buf/tempSupply.$startDay.$gId.$chiId.Sort
					rm ./buf/tempSupply.$startDay.$gId.$chiId
					
					echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId| head -n 1 | tail -n 1)" 
					if [ $tempFirstQuatileNum == 0 ]; then
						tempFirstQuatileNum=1
						echo "[DEBUG] tempFirstQuatile is 0 "	
					fi
					echo "[DEBUG] temp Supply FirstQuatile Num:$tempFirstQuatileNum"

					echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					echo "[DEBUG] temp Supply ThirdQuatile Num:$tempThirdQuatileNum"	

					rm ./buf/data.$startDay.$gId.$chiId
					
					medianNum=$(($tempCountNum/2))
					
					tempSupplyMin="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
					tempSupplyMedian="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort  | head -n $medianNum | tail -n 1)" 
					tempSupplyMax="$(cat ./buf/tempSupply.$startDay.$gId.$chiId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

					rm ./buf/tempSupply.$startDay.$gId.$chiId.Sort
				fi
			else
				tempSupplyMin=NULL
				tempSupplyMedian=NULL
				tempSupplyMax=NULL
			fi
			
			if [ -f "./buf/tempReturn.$startDay.$gId.$chiId" ]; then

				tempCountNum="$(cat ./buf/tempReturn.$startDay.$gId.$chiId |wc -l)"

				if [ $tempCountNum == 0 ]; then

					tempReturnMin=NULL
					tempReturnMedian=NULL
					tempReturnMax=NULL
					
				elif [ $tempCountNum == 1 ]; then

					sort -n ./buf/tempReturn.$startDay.$gId.$chiId > ./buf/tempReturn.$startDay.$gId.$chiId.Sort
					rm ./buf/tempReturn.$startDay.$gId.$chiId
					
					tempReturnMin="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort | head -n  1 | tail -n 1)" 
					tempReturnMedian="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort | head -n 1 | tail -n 1)" 
					tempReturnMax="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort  | head -n 1 | tail -n 1)" 
					
					rm ./buf/tempReturn.$startDay.$gId.$chiId.Sort
				else

					sort -n ./buf/tempReturn.$startDay.$gId.$chiId > ./buf/tempReturn.$startDay.$gId.$chiId.Sort
					rm ./buf/tempReturn.$startDay.$gId.$chiId
					
					echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId| head -n 1 | tail -n 1)" 
					if [ $tempFirstQuatileNum == 0 ]; then
						tempFirstQuatileNum=1
						echo "[DEBUG] tempFirstQuatile is 0 "	
					fi
					echo "[DEBUG] temp Return FirstQuatile Num:$tempFirstQuatileNum"

					echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					echo "[DEBUG] temp Return ThirdQuatile Num:$tempThirdQuatileNum"	

					rm ./buf/data.$startDay.$gId.$chiId
					
					medianNum=$(($tempCountNum/2))
					
					tempReturnMin="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
					tempReturnMedian="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort  | head -n $medianNum | tail -n 1)" 
					tempReturnMax="$(cat ./buf/tempReturn.$startDay.$gId.$chiId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

					rm ./buf/tempReturn.$startDay.$gId.$chiId.Sort
				fi
			else
				tempReturnMin=NULL
				tempReturnMedian=NULL
				tempReturnMax=NULL
			fi

			if [ -f "./buf/tempDelta.$startDay.$gId.$chiId" ]; then

				tempCountNum="$(cat ./buf/tempDelta.$startDay.$gId.$chiId |wc -l)"

				if [ $tempCountNum == 0 ]; then

					tempDeltaMin=NULL
					tempDeltaMedian=NULL
					tempDeltaMax=NULL
					
				elif [ $tempCountNum == 1 ]; then

					sort -n ./buf/tempDelta.$startDay.$gId.$chiId > ./buf/tempDelta.$startDay.$gId.$chiId.Sort
					rm ./buf/tempDelta.$startDay.$gId.$chiId
					
					tempDeltaMin="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort | head -n  1 | tail -n 1)" 
					tempDeltaMedian="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort | head -n 1 | tail -n 1)" 
					tempDeltaMax="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort  | head -n 1 | tail -n 1)" 
					
					rm ./buf/tempDelta.$startDay.$gId.$chiId.Sort
				else

					sort -n ./buf/tempDelta.$startDay.$gId.$chiId > ./buf/tempDelta.$startDay.$gId.$chiId.Sort
					rm ./buf/tempDelta.$startDay.$gId.$chiId
					
					echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId| head -n 1 | tail -n 1)" 
					if [ $tempFirstQuatileNum == 0 ]; then
						tempFirstQuatileNum=1
						echo "[DEBUG] tempFirstQuatile is 0 "	
					fi
					echo "[DEBUG] temp Delta FirstQuatile Num:$tempFirstQuatileNum"

					echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId.$chiId
					tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
					echo "[DEBUG] temp Delta ThirdQuatile Num:$tempThirdQuatileNum"	

					rm ./buf/data.$startDay.$gId.$chiId
					
					medianNum=$(($tempCountNum/2))
					
					tempDeltaMin="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
					tempDeltaMedian="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort  | head -n $medianNum | tail -n 1)" 
					tempDeltaMax="$(cat ./buf/tempDelta.$startDay.$gId.$chiId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

					rm ./buf/tempDelta.$startDay.$gId.$chiId.Sort
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
			
			echo "  Run Power Consumption Data"
			
			if [ -f "./data/watt.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/watt.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/watt.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/watt.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/watt.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/watt.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/watt.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/watt.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/watt.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/watt.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/watt.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/watt.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/watt.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done
			
			echo "  Run Cooling Capacity Data"
			
			if [ -f "./data/coolingCapacity.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/coolingCapacity.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/coolingCapacity.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/coolingCapacity.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/coolingCapacity.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/coolingCapacity.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/coolingCapacity.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/coolingCapacity.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/coolingCapacity.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done
			
			echo "  Run Efficiency Data"
			
			if [ -f "./data/efficiency.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/efficiency.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/efficiency.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/efficiency.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/efficiency.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/efficiency.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/efficiency.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/efficiency.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/efficiency.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/efficiency.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/efficiency.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/efficiency.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/efficiency.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done
			
			#
			# temp Supply Hours
			#
			echo "  Run Temp Supply Hours"
			
			if [ -f "./data/tempSupplyHours.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/tempSupplyHours.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempSupplyHours.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/tempSupplyHours.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempSupplyHours.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/tempSupplyHours.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/tempSupplyHours.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/tempSupplyHours.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempSupplyHours.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done

			#
			# temp Return Hours
			#
			
			echo "  Run Temp Return Hours"
			
			if [ -f "./data/tempReturnHours.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/tempReturnHours.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempReturnHours.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/tempReturnHours.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempReturnHours.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/tempReturnHours.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/tempReturnHours.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/tempReturnHours.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempReturnHours.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done
			

			
			#
			#temp Delta Hours
			#
			
			if [ -f "./data/tempDeltaHours.$startDay.$gId.$chiId.Json" ]; then
				rm ./data/tempDeltaHours.$startDay.$gId.$chiId.Json
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

				if [ -f "./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour" ]; then
				
					#echo "./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour"
					
					countNum="$(cat ./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour |wc -l)"
					
					calNum=1
					dataTotalCal=0
					calData=0

					while :
					do
						if [ $calNum == $countNum ]; then
							break
						fi
						
						calData="$(cat ./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour | head -n $calNum | tail -n 1)"
						
						#echo "$dataTotalCal+$calData"
						echo "scale=3;$dataTotalCal+$calData"|bc > ./buf/tempDeltaHours.$startDay.$gId
						
						dataTotalCal="$(cat ./buf/tempDeltaHours.$startDay.$gId | head -n 1 | tail -n 1)"
						
						calNum=$(($calNum+1))
					done
					
					echo "scale=3;$dataTotalCal/$countNum"|bc > ./buf/tempDeltaHours.$startDay.$gId
						
					dataTotalCal="$(cat ./buf/tempDeltaHours.$startDay.$gId | head -n 1 | tail -n 1)"
					#echo " $dataTotalCal"

					rm ./data/tempDeltaHours.$startDay.$gId.$chiId.$whileHour
					
					jsonNum=$(($jsonNum+1))
							  #>=
					if [ $jsonNum -ge 2 ]; then
						printf ",">> ./data/tempDeltaHours.$startDay.$gId.$chiId.Json
					fi
					
					stHour=$whileHour
					endHour=$(($whileHour+1))

					printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalCal >> ./data/tempDeltaHours.$startDay.$gId.$chiId.Json
				fi
				
				whileHour=$(($whileHour+1))
			done

			#Insert Data List
			
			operationDate=$startDay
			gatewayId=$gId
			#siteId
			chillerDescription=$chiName
			chillerId=$chiId
			activityCount=$activityNum
			
			activityStateNULL=0
			if [ -f "./data/activityState.$startDay.$gId.$chiId" ]; then
				activityState="$(cat ./data/activityState.$startDay.$gId.$chiId | head -n 1 | tail -n 1)"
				rm ./data/activityState.$startDay.$gId.$chiId
			else
				activityStateNULL=1
			fi
			
			totalOperationMinutes=$totalRunMinutes
			
			echo "scale=2;$dataKWTotal/$dataKWCount"|bc > ./buf/avgPowerConsumption.$startDay.$gId
			avgPowerConsumption="$(cat ./buf/avgPowerConsumption.$startDay.$gId | head -n 1 | tail -n 1)"

			#totalEnergyConsumption
			
			echo "scale=2;$powerLoading/$dataKWCount"|bc > ./buf/avgPowerLoading.$startDay.$gId
			avgPowerLoading="$(cat ./buf/avgPowerLoading.$startDay.$gId | head -n 1 | tail -n 1)"

			#efficiencyMin
			#efficiencyMedian
			#efficiencyMax
			#coolingCapacityMin
			#coolingCapacityMedian
			#coolingCapacityMax

			supplyTempMin=$tempSupplyMin
			supplyTempMedian=$tempSupplyMedian
			supplyTempMax=$tempSupplyMax
			
			returnTempMin=$tempReturnMin
			returnTempMedian=$tempReturnMedian
			returnTempMax=$tempReturnMax
			
			deltaTempMin=$tempDeltaMin
			deltaTempMedian=$tempDeltaMedian
			deltaTempMax=$tempDeltaMax

			efficiencyData="$(cat ./data/efficiency.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
			coolingCapacityData="$(cat ./data/coolingCapacity.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
			powerConsumptionData="$(cat ./data/watt.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"

			supplyTempDataNULL=0
			if [ -f "./data/tempSupplyHours.$startDay.$gId.$chiId.Json" ]; then
				supplyTempData="$(cat ./data/tempSupplyHours.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
				rm ./data/tempSupplyHours.$startDay.$gId.$chiId.Json
			else
				supplyTempDataNULL=1
			fi	
			
			returnTempDataNULL=0
			if [ -f "./data/tempReturnHours.$startDay.$gId.$chiId.Json" ]; then
				returnTempData="$(cat ./data/tempReturnHours.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
				rm ./data/tempReturnHours.$startDay.$gId.$chiId.Json
			else
				returnTempDataNULL=1
			fi
			
			deltaTempDataNULL=0
			if [ -f "./data/tempDeltaHours.$startDay.$gId.$chiId.Json" ]; then
				deltaTempData="$(cat ./data/tempDeltaHours.$startDay.$gId.$chiId.Json | head -n 1 | tail -n 1)"
				rm ./data/tempDeltaHours.$startDay.$gId.$chiId.Json
			else
				deltaTempDataNULL=1
			fi
			
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
			VALUES('$operationDate','$siteId','$gatewayId','$chillerId','$chillerDescription',
			'$activityCount','{$activityState}',
			'$totalOperationMinutes',
			'$avgPowerConsumption',
			'$totalEnergyConsumption',
			'$avgPowerLoading',
			'$efficiencyMin','$efficiencyMedian','$efficiencyMax',
			if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
			if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
			if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
			'$returnTempMin','$returnTempMedian','$returnTempMax',
			'$supplyTempMin','$supplyTempMedian','$supplyTempMax',
			'$deltaTempMin','$deltaTempMedian','$deltaTempMax',
			'{$efficiencyData}',
			'{$coolingCapacityData}',
			'{$powerConsumptionData}',
			if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
			if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
			if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
			);
			"

			mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
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
			VALUES('$operationDate','$siteId','$gatewayId','$chillerId','$chillerDescription',
			'$activityCount','{$activityState}',
			'$totalOperationMinutes',
			'$avgPowerConsumption',
			'$totalEnergyConsumption',
			'$avgPowerLoading',
			'$efficiencyMin','$efficiencyMedian','$efficiencyMax',
			if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
			if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
			if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
			'$returnTempMin','$returnTempMedian','$returnTempMax',
			'$supplyTempMin','$supplyTempMedian','$supplyTempMax',
			'$deltaTempMin','$deltaTempMedian','$deltaTempMax',
			'{$efficiencyData}',
			'{$coolingCapacityData}',
			'{$powerConsumptionData}',
			if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
			if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
			if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
			);
			"
			
			
		fi #if [ "$activityNum" == "" ]; then
	fi #if [ "${chillerTime[$whileNum]}" == "" ]; then
	
	echo " "
	arrNum=$(($arrNum+1))
done

programEndTime=$(date "+%Y-%m-%d %H:%M:%S")

st="$(date +%s -d "$programStTime")"
end="$(date +%s -d "$programEndTime")"

sec=$(($end-$st)) 

echo "End Program Run Time $programStTime ~ $programEndTime  花費:$sec"
exit 0
