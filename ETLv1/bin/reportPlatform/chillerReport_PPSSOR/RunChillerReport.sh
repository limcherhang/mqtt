#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH


if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
        echo "請輸入RunChillerReport.sh 113 2020-09-17 00:00 2020-09-18 00:00"
		echo "		gatewayId"
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
        exit 1
fi

gId=${1}

startDay=${2} 
startTime=${3}
endDay=${4} 
endTime=${5}

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run $gId Chiller Report"

dataCount=1440

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

today=$(date "+%Y-%m-%d" --date="-1 day")
if [ $startDay == $today ]; then
	db="iotmgmt"
else
	db="iotdata"
fi

historyTable=0
if [ $startDay == $today ]; then

	dbdata="iotmgmt"
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbdata="iotdata$dbdataYear"
	historyTable=1
fi

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata Table_$dbdataMonth"

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

	deviceIEEE=${chillerIEEE[$arrNum]}
	deviceDesc=${chillerDesc[$arrNum]}
	deviceTable=${chillerTable[$arrNum]}
	
	if [ $historyTable == 1 ]; then
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						 FROM ${deviceTable}_$dbdataMonth
						WHERE 
							ieee='$deviceIEEE' and
							gatewayId=$gId and 
							receivedSync >='$startDay $startTime' and 
							receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM $deviceTable WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	fi
	
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	echo "  ${chillerDesc[$arrNum]} ${chillerTable[$arrNum]} ${chillerIEEE[$arrNum]} ${chillerId[$arrNum]} ${chillerTon[$arrNum]} ${chillerW[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"
						
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
	
	pumpW[$arrNum]=$(mysql -h ${host} -D$dbRPF -ss -e"SELECT capacityKw*1000
		FROM 
			vPumpInfo
		where 
			gatewayId=$gId and pumpId=${pumpId[$arrNum]} and pumpCategory='Evaporator'
	;
	")

	deviceTable=${pumpTable[$arrNum]}
	deviceIEEE=${pumpIEEE[$arrNum]}
	deviceDesc=${pumpDesc[$arrNum]}
	
	if [ $historyTable == 1 ]; then
				qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM $deviceTable WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	fi
	
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "  ${pumpDesc[$arrNum]} ${pumpTable[$arrNum]} ${pumpIEEE[$arrNum]} ${pumpId[$arrNum]} ${pumpW[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"


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
	flowHDRTable=${DeviceInfoBuf[1]}
	flowHDRDeviceDesc=${DeviceInfoBuf[2]}

	deviceIEEE=$flowHDRIEEE
	deviceTable=$flowHDRTable
	deviceDesc=$flowHDRDeviceDesc
	
	if [ $historyTable == 1 ]; then
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
						from(
						select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
						from
							(
							SELECT *
							FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
							gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
							) as a 
						WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
						GROUP BY time
						)as a
					"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
						from(
						select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
						from
							(
							SELECT *
							FROM $deviceTable WHERE ieee='$deviceIEEE' and
							gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
							) as a 
						WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
						GROUP BY time
						)as a
					"))
	fi
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "  $flowHDRDeviceDesc $flowHDRTable $flowHDRIEEE '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"

	
elif [ $chilledWaterFlowHDRNum -gt 1 ]; then
	echo "[ERROR] Chilled Water Flow HDR Num :$chilledWaterFlowHDRNum"
	exit 0
fi

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
	
	deviceIEEE=${flowIEEE[$arrNum]}
	deviceTable=${flowTable[$arrNum]}
		
		
	if [ $historyTable == 1 ]; then	
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
			from(
			select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
			from
			(
				SELECT *
				 FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
				gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
			) as a 
			WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
			GROUP BY time
		)as a
		"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
			from(
			select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
			from
			(
				SELECT *
				 FROM $deviceTable WHERE ieee='$deviceIEEE' and
				gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
			) as a 
			WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
			GROUP BY time
		)as a
		"))
	fi
	dataRate=0
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	
	echo "  ${DeviceInfoBuf[2]} ${flowTable[$arrNum]} ${flowIEEE[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
								  actualDataCount,reportRate
								 ) 
								VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
								"
		

	
	arrNum=$(($arrNum+1))
done


echo " "
echo "  ----------------Chiller Cooling Water Flow Info-------------------- "

coolingWaterFlowHDRNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc = 'CoolingWaterFlow#HDR'
;
")
echo "  Chiller Water Flow HDR Num:$coolingWaterFlowHDRNum"

if [ $coolingWaterFlowHDRNum == 1 ]; then


	DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
			FROM iotmgmtChiller.vDeviceInfo 
			where 
				gatewayId=$gId and deviceDesc = 'CoolingWaterFlow#HDR'
			;
	"))
	
	coolingFlowHDRIEEE=${DeviceInfoBuf[0]}
	coolingFlowHDRTable=${DeviceInfoBuf[1]}
	coolingFlowHDRDeviceDesc=${DeviceInfoBuf[2]}

	deviceIEEE=$coolingFlowHDRIEEE
	deviceTable=$coolingFlowHDRTable
	deviceDesc=$coolingFlowHDRDeviceDesc
	
	if [ $historyTable == 1 ]; then	
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
				from(
				select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
				from
					(
					SELECT *
					FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
					gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
					) as a 
				WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
				GROUP BY time
				)as a
			"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM $deviceTable WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	fi
	
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "  $coolingFlowHDRDeviceDesc $coolingFlowHDRTable $coolingFlowHDRIEEE '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"

	
elif [ $coolingWaterFlowHDRNum -gt 1 ]; then
	echo "[ERROR] Cooling Water Flow HDR Num :$coolingWaterFlowHDRNum"
	exit 0
fi

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,deviceDesc
	FROM iotmgmtChiller.vDeviceInfo 
	where 
		gatewayId=$gId and 
		deviceDesc != 'CoolingWaterFlow#HDR' and
		deviceDesc like 'CoolingWaterFlow#%'
	order by deviceDesc asc
	;
"))
	
coolingWaterFlowNum=$(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc != 'CoolingWaterFlow#HDR' and
	deviceDesc like 'CoolingWaterFlow#%'
;
")
echo ""
echo "  Cooling Water Flow Num:$coolingWaterFlowNum"

arrNum=0
whileNum=0
while :
do
	if [ $arrNum == $coolingWaterFlowNum ]; then
		break
	fi
	
	coolingFlowIEEE[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	coolingFlowTable[$arrNum]=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	deviceDesc=${DeviceInfoBuf[$whileNum]}
	whileNum=$(($whileNum+1))
	
	deviceIEEE=${coolingFlowIEEE[$arrNum]}
	deviceTable=${coolingFlowTable[$arrNum]}
		
		
	if [ $historyTable == 1 ]; then
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
			from(
			select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
			from
			(
				SELECT *
				 FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
				gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
			) as a 
			WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
			GROUP BY time
		)as a
		"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
			from(
			select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
			from
			(
				SELECT *
				 FROM $deviceTable WHERE ieee='$deviceIEEE' and
				gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
			) as a 
			WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
			GROUP BY time
		)as a
		"))
	fi
	dataRate=0
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	
	echo "  ${DeviceInfoBuf[2]} ${coolingFlowTable[$arrNum]} ${coolingFlowIEEE[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
								  actualDataCount,reportRate
								 ) 
								VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
								"
		

	
	arrNum=$(($arrNum+1))
done
echo ""
echo "  ----------------Cooling Tower Info--------------------- "

#Cooling Info
DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc,substring_index(deviceDesc,'#',-1) as deviceNum ,ieee ,tableDesc 
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'CoolingTower#%'
order by deviceNum asc
;
"))

coolingTowerNum=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT count(*)
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and deviceDesc like 'CoolingTower#%'
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

	deviceTable=${coolingTable[$arrNum]}
	deviceIEEE=${coolingIEEE[$arrNum]}
	deviceDesc=${coolingDesc[$arrNum]}
	
	if [ $historyTable == 1 ]; then
		qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
						from(
						select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
						from
							(
							SELECT *
							FROM $deviceTable WHERE ieee='$deviceIEEE' and
							gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
							) as a 
						WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
						GROUP BY time
						)as a
					"))
	fi
	
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	
	echo "  ${coolingDesc[$arrNum]} ${coolingTable[$arrNum]} ${coolingIEEE[$arrNum]} ${coolingId[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"

	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"

	arrNum=$(($arrNum+1))
done

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
	
	deviceTable=${coolingWaterPumpTable[$arrNum]}
	deviceIEEE=${coolingWaterPumpIEEE[$arrNum]}
	deviceDesc=${coolingWaterPumpDesc[$arrNum]}
	if [ $historyTable == 1 ]; then
	qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	else
		qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM $deviceTable WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
	fi
	echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

	echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
	dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
	
	
	echo "  ${coolingWaterPumpDesc[$arrNum]} ${coolingWaterPumpTable[$arrNum]} ${coolingWaterPumpIEEE[$arrNum]} '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
						  actualDataCount,reportRate
						 ) 
						VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
						"

	arrNum=$(($arrNum+1))
done


echo " "
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
		
		echo "  $deviceIEEE $deviceTable ${deviceTempName[0]} ${deviceTempName[1]} ${deviceTempName[2]} ${deviceTempName[3]}"
		echo "  "
		
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
					echo -n "  $deviceDesc ${returnIEEE[$arrNum]} ${returnTable[$arrNum]} ${returnValue[$arrNum]}"
				 ;;
				TempChilledWaterSupply)
					supplyValue[$arrNum]=$tempValue
					supplyIEEE[$arrNum]=$deviceIEEE
					supplyTable[$arrNum]=$deviceTable
					deviceDesc="TempChilledWaterSupply#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc ${supplyIEEE[$arrNum]} ${supplyTable[$arrNum]} ${supplyValue[$arrNum]}"
				 ;;
				TempCoolingWaterSupply)

					coolingSupplyValue[$arrNum]=$tempValue
					coolingSupplyIEEE[$arrNum]=$deviceIEEE
					coolingSupplyTable[$arrNum]=$deviceTable

					deviceDesc="TempCoolingWaterSupply#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc ${coolingSupplyIEEE[$arrNum]} ${coolingSupplyTable[$arrNum]} ${coolingSupplyValue[$arrNum]}"
					coolingSupplyNum=1
				 ;;
				TempCoolingWaterReturn)

					coolingReturnValue[$arrNum]=$tempValue
					coolingReturnIEEE[$arrNum]=$deviceIEEE
					coolingReturnTable[$arrNum]=$deviceTable

					deviceDesc="TempCoolingWaterReturn#${chillerId[$arrNum]}"
					echo -n "  $deviceDesc ${coolingReturnIEEE[$arrNum]} ${coolingReturnTable[$arrNum]} ${coolingReturnValue[$arrNum]}"
					coolingReturnNum=1
				 ;;
				*)
				 ;;
				esac
				
				if [ $historyTable == 1 ]; then
					qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
				else
					qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
						from(
						select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
						from
							(
							SELECT *
							FROM $deviceTable WHERE ieee='$deviceIEEE' and
							gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
							) as a 
						WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
						GROUP BY time
						)as a
					"))
				fi
				
				dataRate=0	
				echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
				dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

				echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
				dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
				
				echo " '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
				
				mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
									  actualDataCount,reportRate
									 ) 
									VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
									"
			fi
		done
	done
	echo " "
	arrNum=$(($arrNum+1))
done

DeviceInfoBuf=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT ieee,tableDesc,value1,value2,value3,value4
FROM iotmgmtChiller.vDeviceInfo 
where 
	gatewayId=$gId and 
	deviceDesc = 'ChilledWaterTemp#HDR'
;
"))

coolingReturnHDRNum=0
coolingSupplyHDRNum=0

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
	
	echo "  $deviceIEEE $deviceTable ${deviceTempName[0]} ${deviceTempName[1]} ${deviceTempName[2]} ${deviceTempName[3]}"
	echo "  "
	
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
				returnTableHDR=$deviceTable
				deviceDesc="TempChilledWaterReturn#HDR"
				echo -n "  $deviceDesc $returnIEEEHDR $returnTableHDR $returnValueHDR"
			 ;;
			TempChilledWaterSupply)
				supplyValueHDR=$tempValue
				supplyIEEEHDR=$deviceIEEE
				supplyTableHDR=$deviceTable
				deviceDesc="TempChilledWaterSupply#HDR"
				echo -n "  $deviceDesc $supplyIEEEHDR $supplyTableHDR $supplyValueHDR"
			 ;;
			TempCoolingWaterSupply)

				coolingSupplyValueHDR=$tempValue
				coolingSupplyIEEEHDR=$deviceIEEE
				coolingSupplyTableHDR=$deviceTable

				deviceDesc="TempCoolingWaterSupply#HDR"
				echo -n "  $deviceDesc $coolingSupplyIEEEHDR $coolingSupplyTableHDR $coolingSupplyValueHDR"
				coolingSupplyHDRNum=1
			 ;;
			TempCoolingWaterReturn)

				coolingReturnValueHDR=$tempValue
				coolingReturnIEEEHDR=$deviceIEEE
				coolingReturnTableHDR=$deviceTable

				deviceDesc="TempCoolingWaterReturn#HDR"
				echo -n "  $deviceDesc $coolingReturnIEEEHDR $coolingReturnTableHDR $coolingReturnValueHDR"
				coolingReturnHDRNum=1
			 ;;
			*)
			 ;;
			esac
			if [ $historyTable == 1 ]; then
				qualityData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM ${deviceTable}_$dbdataMonth WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
			else
				qualityData=($(mysql -h ${host} -D$db -ss -e"SELECT count(*) as tol,count(*)/1440 as per
					from(
					select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,count(*)
					from
						(
						SELECT *
						FROM $deviceTable WHERE ieee='$deviceIEEE' and
						gatewayId=$gId and receivedSync >='$startDay $startTime' and receivedSync <'$endDay 01:00'
						) as a 
					WHERE receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
					GROUP BY time
					)as a
				"))
			fi
			dataRate=0	
			echo "scale=2;${qualityData[1]}*10000"|bc > ./buf/$gId.calculate
			dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"

			echo "scale=2;$dataRate/100"|bc > ./buf/$gId.calculate
			dataRate="$(cat ./buf/$gId.calculate | head -n 1 | tail -n 1)"
			
			echo " '$startDay' '$gId' '$deviceDesc' '$dataCount' '${qualityData[0]}' '$dataRate'"
			
			mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyDataQuality (operationDate,gatewayId,deviceDescription,idealDataCount,
								  actualDataCount,reportRate
								 ) 
								VALUES ('$startDay', '$gId', '$deviceDesc','$dataCount', '${qualityData[0]}', '$dataRate');
								"
		fi
	done
done

echo " "
echo "------Data Quality is done------"
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
	
	
	# echo "[DEBUG]$chillerMainIEEE $capacityValue $capacityTon"
	# echo "[DEBUG]$returnMainIEEE $returnMainValue $returnMainTable"
	# echo "[DEBUG]$supplyMainIEEE $supplyMainValue $supplyMainTable"
	
	# echo "[DEBUG]chiller HDR $chilledWaterFlowHDRNum "
	# echo "[DEBUG]chiller $chilledWaterFlowNum"
	# echo "[DEBUG]chiller Combined $chilledWaterFlowCombinedNum"


	if [ $chilledWaterFlowNum -ge 1 ]; then
	
		flowMainIEEE=${flowIEEE[$arrNum]}
		flowMainTable=${flowTable[$arrNum]}
		
		echo "  Chiller Flow:$flowMainIEEE"
	else
	
		flowMainIEEE=0
		flowMainTable=0
		
		echo "  Chiller Flow:$flowMainIEEE"
	fi

	
	echo "  bash ./dailyChillerMain.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $capacityValue $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable $flowMainIEEE $flowMainTable"
	bash ./dailyChillerMain.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $capacityValue $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable $flowMainIEEE $flowMainTable
	
	# echo "[DEBUG]cooling HDR $coolingWaterFlowHDRNum "
	# echo "[DEBUG]cooling $coolingFlowNum"
	
	echo " "
	arrNum=$(($arrNum+1))
done

echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Chilled Water Pump       #"
echo "#                            #"
echo "#****************************#"
echo " "

arrNum=0
while :
do
	if [ $arrNum == $chilledWaterPumpNum ]; then
		break
	fi
	
	IEEE=${pumpIEEE[$arrNum]}
	capacityValue=${pumpW[$arrNum]}
	
	echo "  -----------------Chilled Water Pump Num:${pumpNum[$arrNum]}--------------------"
	echo "  bash ./mainPump.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue"
	bash ./mainPump.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue 

	echo " "
	arrNum=$(($arrNum+1))
done


echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Cooling Tower            #"
echo "#                            #"
echo "#****************************#"
echo " "

arrNum=0
while :
do
	if [ $arrNum == $coolingTowerNum ]; then
		break
	fi
	
	IEEE=${coolingIEEE[$arrNum]}
	capacityValue=0

	echo "  -----------------Cooling Id: ${coolingId[$arrNum]}--------------------"
	echo "  bash ./mainCooling.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue"
	bash ./mainCooling.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue	
	
	echo "  -----------------Cooling Performance--------------------"
	echo "  bash ./coolingPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE"
	bash ./coolingPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE
	
	echo "  "
	arrNum=$(($arrNum+1))
done

echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Cooling Water Pump       #"
echo "#                            #"
echo "#****************************#"
echo " "

arrNum=0
while :
do
	if [ $arrNum == $coolingWaterPumpNum ]; then
		break
	fi
	
	IEEE=${coolingWaterPumpIEEE[$arrNum]}
	capacityValue=0

	echo "  -----------------Cooling Water Pump#${coolingWaterPumpId[$arrNum]}--------------------"
	
	echo "  bash ./mainCoolingPump.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue"
	bash ./mainCoolingPump.sh $startDay $startTime $endDay $endTime $gId $IEEE $capacityValue
	
	echo "  -----------------Cooling Water Pump Performance--------------------"
	echo "  bash ./coolingPumpPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE"
	bash ./coolingPumpPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE

	echo "  "
	arrNum=$(($arrNum+1))
done


echo " "
echo "#****************************#"
echo "#                            #"
echo "#   Chiller Performance      #"
echo "#                            #"
echo "#****************************#"
echo " "


# arrNum=0
# while :
# do
	# if [ $arrNum == $chillerNum ]; then
		# break
	# fi
	# chillerMainIEEE=${chillerIEEE[$arrNum]}
	
	# capacityValue=${chillerW[$arrNum]}
	# capacityTon=${chillerTon[$arrNum]}
	
	# returnMainIEEE=${returnIEEE[$arrNum]}
	# supplyMainIEEE=${supplyIEEE[$arrNum]}

	# returnMainValue=${returnValue[$arrNum]}
	# supplyMainValue=${supplyValue[$arrNum]}

	# returnMainTable=${returnTable[$arrNum]}
	# supplyMainTable=${supplyTable[$arrNum]}
	
	

	# if [ $chilledWaterFlowNum -ge 1 ]; then
	
		# flowMainIEEE=${flowIEEE[$arrNum]}
		# flowMainTable=${flowTable[$arrNum]}
		
		# echo "  Chiller Flow:$flowMainIEEE"
	# else
	
		# flowMainIEEE=0
		# flowMainTable=0
		
		# echo "  Chiller Flow:$flowMainIEEE"
	# fi
	
	# echo "  -----------------Chiller Performance Num:${chillerId[$arrNum]}--------------------"
	# echo "  bash ./chillerPerformance.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $capacityValue $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable $flowMainIEEE $flowMainTable $capacityTon"
	# bash ./chillerPerformance.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $capacityValue $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable $flowMainIEEE $flowMainTable $capacityTon

	# echo " "
	# arrNum=$(($arrNum+1))
# done
echo "  bash chillerSitePerformance.sh $startDay $startTime $endDay $endTime $gId"
bash ./chillerSitePerformance.sh $startDay $startTime $endDay $endTime $gId

echo " "
echo "#**********************************************#"
echo "#                                              #"
echo "#   Chilled Water Pump Performance             #"
echo "#                                              #"
echo "#**********************************************#"
echo " "

arrNum=0
while :
do
	if [ $arrNum == $chilledWaterPumpNum ]; then
		break
	fi
	
	IEEE=${pumpIEEE[$arrNum]}
	capacityValue=${pumpW[$arrNum]}
	
	echo "  -----------------Chilled Water Pump Performance Num:${pumpId[$arrNum]}--------------------"
	
	echo "  bash ./pumpPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE"
	bash ./pumpPerformance.sh $startDay $startTime $endDay $endTime $gId $IEEE 

	echo " "
	arrNum=$(($arrNum+1))
done

echo " "
echo "#**********************************************#"
echo "#                                              #"
echo "#   Chilled Water Flow & Cooling Water Flow    #"
echo "#                                              #"
echo "#**********************************************#"
echo " "

arrNum=0
while :
do
	if [ $arrNum == $chillerNum ]; then
		break
	fi
	
	echo "  -----------------Chilled Flow Water Id:${chillerId[$arrNum]}--------------------"
	
	if [ $chilledWaterFlowNum -ge 1 ]; then
		
		flowMainIEEE=${flowIEEE[$arrNum]}
		flowMainTable=${flowTable[$arrNum]}
		
		echo "  Chiller Flow:$flowMainIEEE"
		echo "   bash ./flowDetails.sh $startDay $gId ${chillerId[$arrNum]} $flowMainIEEE $flowMainTable"
		bash ./flowDetails.sh $startDay $gId ${chillerId[$arrNum]} $flowMainIEEE $flowMainTable
	else
		
		flowMainIEEE=0
		flowMainTable=0
		
		echo "  Chiller Flow:$flowMainIEEE"
	fi

	if [ $coolingWaterFlowNum -ge 1 ]; then
		
		echo "  Chiller Cooling Water Flow"
		echo "   bash ./flowCoolingWaterDetails.sh $startDay $gId ${chillerId[$arrNum]} ${coolingFlowIEEE[$arrNum]} ${coolingFlowTable[$arrNum]}"
		bash ./flowCoolingWaterDetails.sh $startDay $gId ${chillerId[$arrNum]} ${coolingFlowIEEE[$arrNum]} ${coolingFlowTable[$arrNum]}
	else
		
		flowMainIEEE=0
		flowMainTable=0
		
		echo "  Chiller Cooling Water Flow:$flowMainIEEE"
		
	fi
	arrNum=$(($arrNum+1))
done

if [ $chilledWaterFlowCombinedNum -ge 1 ]; then

	echo "  bash ./plantCombinedFlow.sh $startDay $startTime $endDay $endTime $gId ${flowCombinedIEEE[0]} ${flowCombinedTable[0]} ${flowCombinedIEEE[1]} ${flowCombinedTable[1]}"
	bash ./plantCombinedFlow.sh $startDay $startTime $endDay $endTime $gId ${flowCombinedIEEE[0]} ${flowCombinedTable[0]} ${flowCombinedIEEE[1]} ${flowCombinedTable[1]}	
else

	if [ $chilledWaterFlowHDRNum == 1 ] && [ $coolingWaterFlowHDRNum == 0 ]; then
		echo " "
		echo "  -----------------Chiller Water Flow HDR-------------------- "

		echo "  bash ./plantChillerFlow.sh $startDay $startTime $endDay $endTime $gId $flowHDRIEEE $flowHDRTable"
		bash ./plantChillerFlow.sh $startDay $startTime $endDay $endTime $gId $flowHDRIEEE $flowHDRTable 
	
	elif [ $chilledWaterFlowHDRNum == 1 ] && [ $coolingWaterFlowHDRNum == 1 ]; then
		echo " "
		echo "  -----------------Chiller Water Flow  & Cooling Water Flow HDR-------------------- "

		echo "  bash ./plantFlow.sh $startDay $startTime $endDay $endTime $gId $flowHDRIEEE $flowHDRTable $coolingFlowHDRIEEE $coolingFlowHDRTable"
		bash ./plantFlow.sh $startDay $startTime $endDay $endTime $gId $flowHDRIEEE $flowHDRTable $coolingFlowHDRIEEE $coolingFlowHDRTable
	fi
fi

echo " "
echo "#**********************************************#"
echo "#                                              #"
echo "#   Chiller Cooling Temp                       #"
echo "#                                              #"
echo "#**********************************************#"
echo " "

if [ $coolingReturnNum == 1 ] && [ $coolingSupplyNum == 1 ]; then
	arrNum=0

	while :
	do
		if [ $arrNum == $chillerNum ]; then
			break
		fi
		
		echo "  -----------------Chiller Cooling Temp Id:${chillerId[$arrNum]}--------------------"
		
		chillerMainIEEE=${chillerIEEE[$arrNum]}
		
		returnMainIEEE=${coolingReturnIEEE[$arrNum]}
		supplyMainIEEE=${coolingSupplyIEEE[$arrNum]}

		returnMainValue=${coolingReturnValue[$arrNum]}
		supplyMainValue=${coolingSupplyValue[$arrNum]}

		returnMainTable=${coolingReturnTable[$arrNum]}
		supplyMainTable=${coolingSupplyTable[$arrNum]}
		
		echo "  bash ./chillerCoolingTempData.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable"
		bash ./chillerCoolingTempData.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable
		
		arrNum=$(($arrNum+1))
	done
else
	echo "  -----------------Chiller Cooling Temp no Device--------------------"
fi

echo " "
echo "#**********************************************#"
echo "#                                              #"
echo "#   Chiller Cooling Performance                #"
echo "#                                              #"
echo "#**********************************************#"
echo " "

if [ $coolingReturnNum == 1 ] && [ $coolingSupplyNum == 1 ]; then

	
	arrNum=0
	
	while :
	do
		if [ $arrNum == $chillerNum ]; then
			break
		fi
		
		echo "  -----------------Chiller Cooling Performance Id:${chillerId[$arrNum]}--------------------"
		
		chillerMainIEEE=${chillerIEEE[$arrNum]}
		
		returnMainIEEE=${coolingReturnIEEE[$arrNum]}
		supplyMainIEEE=${coolingSupplyIEEE[$arrNum]}

		returnMainValue=${coolingReturnValue[$arrNum]}
		supplyMainValue=${coolingSupplyValue[$arrNum]}

		returnMainTable=${coolingReturnTable[$arrNum]}
		supplyMainTable=${coolingSupplyTable[$arrNum]}
		
		echo "  bash ./chillerCoolingPerformance.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable"
		bash ./chillerCoolingPerformance.sh $startDay $startTime $endDay $endTime $gId $chillerMainIEEE $supplyMainIEEE $supplyMainValue $returnMainTable $returnMainIEEE $returnMainValue $returnMainTable
		arrNum=$(($arrNum+1))
	done
	
else	
	echo "  -----------------Chiller Cooling Performance no Device--------------------"
fi

echo " "
echo "#*****************#"
echo "#Plant Performance#"
echo "#*****************#"
echo " "

echo "  bash ./plantPerformance.sh $startDay $startTime $endDay $endTime $gId"
bash ./plantPerformance.sh $startDay $startTime $endDay $endTime $gId


echo " "
echo "#**********************#"
echo "#Plant Temp Performance#"
echo "#**********************#"
echo " "

echo "  bash ./plantTempPerformance.sh $startDay $startTime $endDay $endTime $gId"
bash ./plantTempPerformance.sh $startDay $startTime $endDay $endTime $gId

programEndTime=$(date "+%Y-%m-%d %H:%M:%S")

st="$(date +%s -d "$programStTime")"
end="$(date +%s -d "$programEndTime")"

sec=$(($end-$st)) 

echo "End Program Run Time $programStTime ~ $programEndTime  花費:$sec"
exit 0
