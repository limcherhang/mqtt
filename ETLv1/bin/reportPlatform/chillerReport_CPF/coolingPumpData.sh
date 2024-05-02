#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ]; then
        echo "請輸入bash chillerPumpData.sh 24 power#27 3 ChilledWaterPump#3 2021-10-09 00:00 2021-10-10 00:00 152"
        exit 1
fi

if [ -f "./buf/*" ]; then
	rm ./buf/*
fi

host=127.0.0.1

reportPlatform="reportplatform"

siteId=${1}
Name=${2}
pumpNum=${3}
pumpName=${4}

startDay=${5}
startTime=${6}

endDay=${7}
endTime=${8}

gatewayId=${9}

today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	
	dbProcess="processETL"
	tbChiller="chiller"
	
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"

fi
pumpW=100

echo "$siteId $Name $pumpNum $pumpName $startDay $startTime $endDay $endTime $dbPlatform $tbPower $dbProcess $tbchiller"
echo "*************************************************************************************************"

pumpData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
	date_format(ts, '%Y-%m-%d %H:%i')as time,
	round(powerConsumed/60*1000,0) as wattHour,
	round(powerConsumed*1000,0) as Watt
  FROM $tbPower
	  WHERE 
	  siteId='$siteId' and
	  name='$Name' and 
	  ts >='$startDay $startTime' and 
	  ts <'$endDay $endTime'
"))

flagStartNum=0
flagEndNum=0
arrNum=1

powerLoadingMedianNum=0
totalWatt=0

while :
do
	if [ "${pumpData[$dataNum]}" == "" ]; then
		break
	fi

	tsDay=${pumpData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	tsTime=${pumpData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	wattHour=${chillerData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	watt=${pumpData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	#echo "[DEBUG]$tsDay $tsTime  $watt"
	# < 10KW chillerFlag=0 end chiller
	if [ $watt -lt $pumpW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then

		chillerFlag[$arrNum]=0
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime

		
		flagStartNum=0
		flagEndNum=1
	# > 10W chillerFlag=1 start pump
	elif [ $watt -gt $pumpW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then
		
		flagStartNum=1

		chillerFlag[$arrNum]=1
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime


	# > 10W chillerFlag=1 start pump
	elif [ $watt -gt $pumpW ] && [ $flagEndNum == 1 ] && [ $flagStartNum == 0 ]; then
	
		flagStartNum=1
		flagEndNum=0
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "chillerEndWatt:${pumpData[$num]}"
		#chillerEndWatt[$arrNum]=${pumpData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "chillerEndTime:${pumpData[$num]}"
		chillerEndTime[$arrNum]=${pumpData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "chillerEndDay:${pumpData[$num]}"
		chillerEndDay[$arrNum]=${pumpData[$num]}
		
		#Next array
		arrNum=$(($arrNum+1))

		chillerFlag[$arrNum]=1
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime


	# < 10W	chillerFlag=0 end pump
	elif [ $watt -lt $pumpW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 1 ]; then
	
		flagStartNum=0
		flagEndNum=1
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "chillerEndWatt:${pumpData[$num]}"
		#chillerEndWatt[$arrNum]=${pumpData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "chillerEndTime:${pumpData[$num]}"
		chillerEndTime[$arrNum]=${pumpData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "chillerEndDay:${pumpData[$num]}"
		chillerEndDay[$arrNum]=${pumpData[$num]}

		#Next array
		arrNum=$(($arrNum+1))

		chillerFlag[$arrNum]=0
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime
	fi
	

	
	chillerCount[$arrNum]=$((${chillerCount[$arrNum]}+1))
	
	#echo "[DEBUG]$tsDay $tsTime arr:$arrNum watt:$watt--$pumpW end:$flagEndNum start:$flagStartNum"
done

chillerEndDay[$arrNum]=$tsDay
chillerEndTime[$arrNum]=$tsTime

#echo "$arrNum"

while :
do
	if [ $arrNum == 0 ]; then
		break
	fi
	
	echo "  [DEBUG]${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]} ~ ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"
	
	stTime=$(date +%s -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}")
	edTime=$(date +%s -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}")
	
	runTime=$(($edTime-$stTime))
	
	#echo "  [DEBUG]$edTime-$stTime=$runTime"
	runTimeMinute=$(($runTime/60))
	
	#echo "Chiller_kwh=(${chillerWattHour[$arrNum]}/${chillerCount[$arrNum]})x$runTimeMinute"
	#echo "scale=0;(${chillerWattHour[$arrNum]}/${chillerCount[$arrNum]})*$runTimeMinute"|bc > ./buf/chillerW
	#Chiller_kwh="$(cat ./buf/chillerW | head -n 1 | tail -n 1)"
	#echo "$Chiller_kwh"
	#rm ./buf/chillerW

	
	#start time
	#echo "${chillerStartDay[$arrNum]}" 
	#echo "${chillerStartTime[$arrNum]}" 
	
	#end time
	#echo "${chillerEndDay[$arrNum]}"
	#echo "${chillerEndTime[$arrNum]}" 
	
	#operationFlag
	#echo "${chillerFlag[$arrNum]}"
	
	#total kw
	#echo "$Chiller_kwh"
	
	#runMinutes
	runMinutes_start=$(date -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" +%s)
	runMinutes_end=$(date -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	#echo "$runMinutes"
	
	#Count
	#echo "${chillerCount[$arrNum]}" 
	
	
	echo "[DEBUG]total :round((avg(powerConsumed))/(${chillerCount[$arrNum]}/60)*1000,3)"
	
	totalKwh=($(mysql -h ${host} -D$dbPlatform -ss -e"select
		round((avg(powerConsumed)*1000)*($runMinutes)/60,3) as TotalWatt
	  FROM $tbPower
		  WHERE 
		  siteId='$siteId' and
		  name='$Name' and 
		  ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
		  ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
	"))
	
	
	powerMeterData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
		powerConsumed
    FROM $tbPower
	  WHERE 
	  siteId='$siteId' and
	  name='$Name' and 
	  ts >= '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
	  ts <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59'
	"))
	
	medianNum=0
	whileNum=0
	
	while :
	do
		if [ "${powerMeterData[$whileNum]}" == "" ]; then
			break
		fi
		
		#Power Consumption
		echo "${powerMeterData[$whileNum]}" >> ./buf/powerConsumption
		
		whileNum=$(($whileNum+1))
		medianNum=$(($medianNum+1))
	done

	if [ $medianNum == 0 ]; then
		medianNum=1
	elif [ $medianNum == 1 ]; then
		medianNum=1
	else
		medianNum=$(($medianNum/2))
	fi
	#echo "Median Num:$medianNum"	
	
	#Power Consumption
	sort -n ./buf/powerConsumption >> ./buf/powerConsumption.sort
	powerConsumption="$(cat ./buf/powerConsumption.sort | head -n $medianNum | tail -n 1)"
	#echo "Power Consumption:$powerConsumption"
	
	rm ./buf/powerConsumption
	rm ./buf/powerConsumption.sort

	echo "Operation Date : $startDay"
	echo "Site Id : $siteId"
	echo "Gateway Id : $gatewayId"
	echo "pumpId : $pumpNum"
    echo "pumpDescription : $pumpName"
	echo "startTime ${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" 
	echo "endTime ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"
	echo "opMinutes : $runMinutes"
	echo "dataCount : ${chillerCount[$arrNum]}" 
	echo "total : $totalKwh"
	echo "operationFlag ${chillerFlag[$arrNum]}"
	echo "powerConsumption $powerConsumption"


	echo "replace INTO dailyCoolingPumpData(
		operationDate,siteId,gatewayId,pumpId,pumpDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$pumpNum', '$pumpName', '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}', '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}', 
		'$runMinutes','${chillerCount[$arrNum]}', '$totalKwh', '${chillerFlag[$arrNum]}','$powerConsumption'
		);
	"
	
	mysql -h ${host} -D$reportPlatform -ss -e"replace INTO dailyCoolingPumpData(
		operationDate,siteId,gatewayId,pumpId,pumpDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$pumpNum', '$pumpName', '${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}', '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}', 
		'$runMinutes','${chillerCount[$arrNum]}', '$totalKwh', '${chillerFlag[$arrNum]}','$powerConsumption'
		);
	"
	
	arrNum=$(($arrNum-1))
done
exit 0

