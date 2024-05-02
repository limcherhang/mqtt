#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]|| [ "${8}" == "" ] || [ "${9}" == "" ]; then
        echo "請輸入SiteId Name CoolingNum CoolingName 2021-10-08 00:00 2021-10-09 00:00 gatewayId"
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"

siteId=${1}
Name=${2}
coolingNum=${3}
coolingName=${4}

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

else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"

fi

echo "$siteId $Name $coolingNum $coolingName $startDay $startTime $endDay $endTime $dbPlatform $tbPower"
echo "*************************************************************************************************"

coolingW=100
coolingData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
	date_format(ts, '%Y-%m-%d %H:%i')as time,
	round(sum(powerConsumed)/60*1000,0) as wattHour,
	round(sum(powerConsumed)*1000,0) as Watt
  FROM $tbPower
	  WHERE 
	  siteId = '$siteId' and
	  name = '$Name' and 
	  ts >='$startDay $startTime' and 
	  ts <'$endDay $endTime'
	  group by ts 
"))

flagStartNum=0
flagEndNum=0
arrNum=1

powerLoadingMedianNum=0
totalWatt=0

while :
do
	if [ "${coolingData[$dataNum]}" == "" ]; then
		break
	fi

	tsDay=${coolingData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	tsTime=${coolingData[$dataNum]}
	dataNum=$(($dataNum+1))

	wattHour=${coolingData[$dataNum]}
	dataNum=$(($dataNum+1))

	watt=${coolingData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	#echo "[DEBUG]$tsDay $tsTime $wattHour $watt"
	# < 10KW coolingFlag=0 end cooling
	if [ $watt -lt $coolingW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then

		coolingFlag[$arrNum]=0
		coolingCount[$arrNum]=0
		
		coolingStartDay[$arrNum]=$tsDay
		coolingStartTime[$arrNum]=$tsTime
        #coolingStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   coolingWattHour[$arrNum] = $wattHour"
		coolingWattHour[$arrNum]=$wattHour
		
		flagStartNum=0
		flagEndNum=1
	# > 10KW coolingFlag=1 start cooling
	elif [ $watt -gt $coolingW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then
		
		flagStartNum=1

		coolingFlag[$arrNum]=1
		coolingCount[$arrNum]=0
		
		coolingStartDay[$arrNum]=$tsDay
		coolingStartTime[$arrNum]=$tsTime

		#coolingStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   coolingWattHour[$arrNum] = $wattHour"
		coolingWattHour[$arrNum]=$wattHour
	# > 10KW coolingFlag=1 start cooling
	elif [ $watt -gt $coolingW ] && [ $flagEndNum == 1 ] && [ $flagStartNum == 0 ]; then
	
		flagStartNum=1
		flagEndNum=0
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "coolingEndWatt:${coolingData[$num]}"
		#coolingEndWatt[$arrNum]=${coolingData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "coolingEndTime:${coolingData[$num]}"
		coolingEndTime[$arrNum]=${coolingData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "coolingEndDay:${coolingData[$num]}"
		coolingEndDay[$arrNum]=${coolingData[$num]}
		
		#Next array
		arrNum=$(($arrNum+1))

		coolingFlag[$arrNum]=1
		coolingCount[$arrNum]=0
		
		coolingStartDay[$arrNum]=$tsDay
		coolingStartTime[$arrNum]=$tsTime

		#coolingStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   coolingWattHour[$arrNum] = $wattHour"
		coolingWattHour[$arrNum]=$wattHour
	# < 10KW	coolingFlag=0 end cooling
	elif [ $watt -lt $coolingW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 1 ]; then
	
		flagStartNum=0
		flagEndNum=1
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "coolingEndWatt:${coolingData[$num]}"
		#coolingEndWatt[$arrNum]=${coolingData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "coolingEndTime:${coolingData[$num]}"
		coolingEndTime[$arrNum]=${coolingData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "coolingEndDay:${coolingData[$num]}"
		coolingEndDay[$arrNum]=${coolingData[$num]}

		#Next array
		arrNum=$(($arrNum+1))

		coolingFlag[$arrNum]=0
		coolingCount[$arrNum]=0
		
		coolingStartDay[$arrNum]=$tsDay
		coolingStartTime[$arrNum]=$tsTime
		
		
		#coolingStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   coolingWattHour[$arrNum] = $wattHour"
		coolingWattHour[$arrNum]=$wattHour
	fi
	
	#echo "      ${coolingWattHour[$arrNum]}+$wattHour"
	coolingWattHour[$arrNum]=$((${coolingWattHour[$arrNum]}+$wattHour))
	
	coolingCount[$arrNum]=$((${coolingCount[$arrNum]}+1))
	
	#echo "[DEBUG]$tsDay $tsTime arr:$arrNum watt:$watt--$coolingW end:$flagEndNum start:$flagStartNum"
done

coolingEndDay[$arrNum]=$tsDay
coolingEndTime[$arrNum]=$tsTime
#coolingEndWatt[$arrNum]=$totalNegativeWattHour

#echo "$arrNum"

while :
do
	if [ $arrNum == 0 ]; then
		break
	fi
	
	#echo "  [DEBUG]${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]} ~ ${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}"
	
	stTime=$(date +%s -d "${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}")
	edTime=$(date +%s -d "${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}")
	
	runTime=$(($edTime-$stTime))
	
	#echo "  [DEBUG]$edTime-$stTime=$runTime"
	runTimeMinute=$(($runTime/60))
	
	
	#runMinutes
	runMinutes_start=$(date -d "${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}" +%s)
	runMinutes_end=$(date -d "${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	#echo "$runMinutes"
	
	#Count
	#echo "${coolingCount[$arrNum]}" 
	
	
	echo "[DEBUG]total :round((avg(powerConsumed))/(${coolingCount[$arrNum]}/60)*1000,3)"
	
	totalKwh=($(mysql -h ${host} -D$dbPlatform -ss -e"select
		round((avg(powerConsumed)*1000)*($runMinutes)/60,3) as TotalWatt
	  FROM $tbPower
		  WHERE 
		  siteId='$siteId' and
		  name = '$Name' and 
		  ts >= '${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}' and 
		  ts <= '${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}:59'
	"))
	
	
	powerMeterData=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
		powerConsumed
    FROM $tbPower
	  WHERE 
	  siteId='$siteId' and
	  name = '$Name' and  
	  ts >= '${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}' and 
	  ts <= '${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}:59'
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
	echo "coolingId : $coolingNum"
    echo "coolingDescription : $coolingName"
	echo "startTime ${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}" 
	echo "endTime ${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}"
	echo "opMinutes : $runMinutes"
	echo "dataCount : ${coolingCount[$arrNum]}" 
	echo "total : $totalKwh"
	echo "operationFlag ${coolingFlag[$arrNum]}"
	echo "powerConsumption $powerConsumption"


	echo "replace INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$coolingNum', '$coolingName', '${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}', '${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}', 
		'$runMinutes','${coolingCount[$arrNum]}', '$totalKwh', '${coolingFlag[$arrNum]}','$powerConsumption'
		);
	"
	
	mysql -h ${host} -D$reportPlatform -ss -e"replace INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption
		) 
		VALUES(
		'$startDay','$siteId','$gatewayId', '$coolingNum', '$coolingName', '${coolingStartDay[$arrNum]} ${coolingStartTime[$arrNum]}', '${coolingEndDay[$arrNum]} ${coolingEndTime[$arrNum]}', 
		'$runMinutes','${coolingCount[$arrNum]}', '$totalKwh', '${coolingFlag[$arrNum]}','$powerConsumption'
		);
	"
	
	arrNum=$(($arrNum-1))
done
exit 0
