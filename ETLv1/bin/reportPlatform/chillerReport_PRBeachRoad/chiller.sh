#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 ./chiller.sh ppssbms0001 2020-09-17 00:00 2020-09-18 00:00 230400"
		echo "		IEEE "
		echo "		start Day"
		echo "		start Time"
		echo "		end Day"
		echo "		end Time"
		echo " 		Capacity(W)"
		echo "      chiller運作W"
        exit 1
fi

chillerIEEE=${1}

startDay=${2}
startTime=${3}

endDay=${4}
endTime=${5}

capacityW=${6}
chillerW=${7}

# Array List
# chillerStartDay
# chillerStartTime
# chillerStartWatt

# chillerEndDay
# chillerEndTime
# chillerEndWatt

# chillerFlag
# chillerCount

if [ -f "./data/chiller.$startDay.$chillerIEEE" ]; then
	rm ./data/chiller.$startDay.$chillerIEEE
fi

host="127.0.0.1"
today=$(date "+%Y-%m-%d" --date="-1 day")

if [ ${2} == $today ]; then
	db="iotmgmt"
else
	db="iotdata"
fi

chillerData=($(mysql -h ${host} -D$db -ss -e"select 
	date_format(receivedSync, '%Y-%m-%d %H:%i')as time,
	round((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/60,0) as wattHour,
	round(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as watt
  FROM pm 
	  WHERE ieee='$chillerIEEE' and 
	  receivedSync >='$startDay $startTime' and 
	  receivedSync <'$endDay $endTime' and
	  (IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
  GROUP BY time
"))

dataNum=0
if [ "${chillerData[$dataNum]}" == "" ]; then
	echo "++++$chillerIEEE $startDay $startTime~$endDay $endTime Chiller Power Meter no data+++"
	echo "0" > ./data/chiller.$startDay.$chillerIEEE
	exit 0
fi

flagStartNum=0
flagEndNum=0
arrNum=1

powerLoadingMedianNum=0
totalWatt=0

while :
do
	if [ "${chillerData[$dataNum]}" == "" ]; then
		break
	fi

	tsDay=${chillerData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	tsTime=${chillerData[$dataNum]}
	dataNum=$(($dataNum+1))

	wattHour=${chillerData[$dataNum]}
	dataNum=$(($dataNum+1))

	watt=${chillerData[$dataNum]}
	dataNum=$(($dataNum+1))
	
	#echo "[DEBUG]$tsDay $tsTime $wattHour $watt"
	# < 10KW chillerFlag=0 end chiller
	if [ $watt -lt $chillerW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then

		chillerFlag[$arrNum]=0
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime
        #chillerStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   chillerWattHour[$arrNum] = $wattHour"
		chillerWattHour[$arrNum]=$wattHour
		
		flagStartNum=0
		flagEndNum=1
	# > 10KW chillerFlag=1 start chiller
	elif [ $watt -gt $chillerW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then
		
		flagStartNum=1

		chillerFlag[$arrNum]=1
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime

		#chillerStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   chillerWattHour[$arrNum] = $wattHour"
		chillerWattHour[$arrNum]=$wattHour
	# > 10KW chillerFlag=1 start chiller
	elif [ $watt -gt $chillerW ] && [ $flagEndNum == 1 ] && [ $flagStartNum == 0 ]; then
	
		flagStartNum=1
		flagEndNum=0
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "chillerEndWatt:${chillerData[$num]}"
		#chillerEndWatt[$arrNum]=${chillerData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "chillerEndTime:${chillerData[$num]}"
		chillerEndTime[$arrNum]=${chillerData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "chillerEndDay:${chillerData[$num]}"
		chillerEndDay[$arrNum]=${chillerData[$num]}
		
		#Next array
		arrNum=$(($arrNum+1))

		chillerFlag[$arrNum]=1
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime

		#chillerStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   chillerWattHour[$arrNum] = $wattHour"
		chillerWattHour[$arrNum]=$wattHour
	# < 10KW	chillerFlag=0 end chiller
	elif [ $watt -lt $chillerW ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 1 ]; then
	
		flagStartNum=0
		flagEndNum=1
		
		# -4    -3     -2             -1
		#tsDay tsTime totalNegativeWattHour watt(previous data)
		num=$(($dataNum-4))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "chillerEndWatt:${chillerData[$num]}"
		#chillerEndWatt[$arrNum]=${chillerData[$num]}
		
		#tsTime
		num=$(($num-1))
		#echo "chillerEndTime:${chillerData[$num]}"
		chillerEndTime[$arrNum]=${chillerData[$num]}
		
		#tsDay
		num=$(($num-1))
		#echo "chillerEndDay:${chillerData[$num]}"
		chillerEndDay[$arrNum]=${chillerData[$num]}

		#Next array
		arrNum=$(($arrNum+1))

		chillerFlag[$arrNum]=0
		chillerCount[$arrNum]=0
		
		chillerStartDay[$arrNum]=$tsDay
		chillerStartTime[$arrNum]=$tsTime
		
		
		#chillerStartWatt[$arrNum]=$totalNegativeWattHour
		#echo "   chillerWattHour[$arrNum] = $wattHour"
		chillerWattHour[$arrNum]=$wattHour
	fi
	
	#echo "      ${chillerWattHour[$arrNum]}+$wattHour"
	chillerWattHour[$arrNum]=$((${chillerWattHour[$arrNum]}+$wattHour))
	
	chillerCount[$arrNum]=$((${chillerCount[$arrNum]}+1))
	
	#echo "[DEBUG]$tsDay $tsTime arr:$arrNum watt:$watt--$chillerW end:$flagEndNum start:$flagStartNum"
done

chillerEndDay[$arrNum]=$tsDay
chillerEndTime[$arrNum]=$tsTime
#chillerEndWatt[$arrNum]=$totalNegativeWattHour

echo "$arrNum" > ./data/chiller.$startDay.$chillerIEEE

while :
do
	if [ $arrNum == 0 ]; then
		break
	fi
	
	#echo "  [DEBUG]${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]} ~ ${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}"

	stTime=$(date +%s -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}")
	edTime=$(date +%s -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}")
	
	runTime=$(($edTime-$stTime))
	
	#echo "  [DEBUG]$edTime-$stTime=$runTime"
	runTimeMinute=$(($runTime/60))
	
	#echo "Chiller_kwh=(${chillerWattHour[$arrNum]}/${chillerCount[$arrNum]})x$runTimeMinute"
	echo "scale=0;(${chillerWattHour[$arrNum]}/${chillerCount[$arrNum]})*$runTimeMinute"|bc > ./buf/chillerW.$chillerIEEE
	Chiller_kwh="$(cat ./buf/chillerW.$chillerIEEE | head -n 1 | tail -n 1)"
	#echo "$Chiller_kwh"
	rm ./buf/chillerW.$chillerIEEE

	
	#start time
	echo "${chillerStartDay[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	echo "${chillerStartTime[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	
	#end time
	echo "${chillerEndDay[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	echo "${chillerEndTime[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	
	#operationFlag
	echo "${chillerFlag[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	
	#total kw
	echo "$Chiller_kwh" >> ./data/chiller.$startDay.$chillerIEEE
	
	#runMinutes
	runMinutes_start=$(date -d "${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}" +%s)
	runMinutes_end=$(date -d "${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	echo "$runMinutes" >> ./data/chiller.$startDay.$chillerIEEE
	
	#Count
	echo "${chillerCount[$arrNum]}" >> ./data/chiller.$startDay.$chillerIEEE
	
	if [ $startDay == $today ]; then
		db="iotmgmt"
	else
		db="iotdata"
	fi

	powerMeterData=($(mysql -h ${host} -D$db -ss -e"select truncate((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000,2) as kw,truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as watt
	from
	(
		SELECT *
		 FROM pm WHERE ieee='$chillerIEEE' 
		and receivedSync>='$startDay $startTime' and receivedSync<'$endDay 01:00'
	) as a WHERE 
	receivedSync >='${chillerStartDay[$arrNum]} ${chillerStartTime[$arrNum]}' and 
	receivedSync <= '${chillerEndDay[$arrNum]} ${chillerEndTime[$arrNum]}:59' and
	(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
	GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
	"))
	
	powerLoadingLevel_0=0
	powerLoadingLevel_1=0
	powerLoadingLevel_2=0
	powerLoadingLevel_3=0
	powerLoadingLevel_4=0
	powerLoadingLevel_5=0
	powerLoadingLevel_6=0
	powerLoadingLevel_7=0
	powerLoadingLevel_8=0
	powerLoadingLevel_9=0
	powerLoadingLevel_10=0
	
	medianNum=0
	whileNum=0
	
	
	while :
	do
		if [ "${powerMeterData[$whileNum]}" == "" ]; then
			break
		fi
		
		#Power Consumption
		echo "${powerMeterData[$whileNum]}" >> ./buf/powerConsumption.$chillerIEEE
		whileNum=$(($whileNum+1))
		
		#Power loading level
		watt=$((${powerMeterData[$whileNum]}*1000))
		powerLoadingPerCounts=$(($watt/$capacityW))
		
		echo "$powerLoadingPerCounts" >> ./buf/powerLoadingPerCounts.$chillerIEEE
	
		if [ $powerLoadingPerCounts == 0 ]; then
		#0%
			powerLoadingLevel_0=$(($powerLoadingLevel_0+1)) 

		elif [ $powerLoadingPerCounts -gt 0 ] && [ $powerLoadingPerCounts -lt 100 ]; then
		#0.01~9.99%	
			powerLoadingLevel_1=$(($powerLoadingLevel_1+1)) 

		elif [ $powerLoadingPerCounts -ge 100 ] && [ $powerLoadingPerCounts -lt 200 ]; then
		#10~19.99%	
			powerLoadingLevel_2=$(($powerLoadingLevel_2+1)) 

		elif [ $powerLoadingPerCounts -ge 200 ] && [ $powerLoadingPerCounts -lt 300 ]; then
		#20~29.99%	
			powerLoadingLevel_3=$(($powerLoadingLevel_3+1)) 

		elif [ $powerLoadingPerCounts -ge 300 ] && [ $powerLoadingPerCounts -lt 400 ]; then
		#30~39.99%	
			powerLoadingLevel_4=$(($powerLoadingLevel_4+1)) 

		elif [ $powerLoadingPerCounts -ge 400 ] && [ $powerLoadingPerCounts -lt 500 ]; then
		#40~49.99%	
			powerLoadingLevel_5=$(($powerLoadingLevel_5+1)) 

		elif [ $powerLoadingPerCounts -ge 500 ] && [ $powerLoadingPerCounts -lt 600 ]; then
		#50~59.99%	
			powerLoadingLevel_6=$(($powerLoadingLevel_6+1)) 

		elif [ $powerLoadingPerCounts -ge 600 ] && [ $powerLoadingPerCounts -lt 700 ]; then
		#60~69.99%	
			powerLoadingLevel_7=$(($powerLoadingLevel_7+1)) 

		elif [ $powerLoadingPerCounts -ge 700 ] && [ $powerLoadingPerCounts -lt 800 ]; then
		#70~79.99%	
			powerLoadingLevel_8=$(($powerLoadingLevel_8+1)) 

		elif [ $powerLoadingPerCounts -ge 800 ] && [ $powerLoadingPerCounts -lt 900 ]; then
		#80~89.99%	
			powerLoadingLevel_9=$(($powerLoadingLevel_9+1)) 

		elif [ $powerLoadingPerCounts -ge 900 ] && [ $powerLoadingPerCounts -lt 1000 ]; then
		#90~100%	
			powerLoadingLevel_10=$(($powerLoadingLevel_10+1)) 

		else
			echo "[ERROR]power loading per counts data:$powerLoadingPerCounts"
		fi
		
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
	sort -n ./buf/powerConsumption.$chillerIEEE >> ./buf/powerConsumption.$chillerIEEE.sort
	powerConsumption="$(cat ./buf/powerConsumption.$chillerIEEE.sort | head -n $medianNum | tail -n 1)"
	#echo " Power Consumption:$powerConsumption"
	
	#Power Loading
	sort -n ./buf/powerLoadingPerCounts.$chillerIEEE >> ./buf/powerLoadingPerCounts.$chillerIEEE.sort
	powerLoadingMedian="$(cat ./buf/powerLoadingPerCounts.$chillerIEEE.sort | head -n $medianNum | tail -n 1)"
	#echo " Power Loading:$powerLoadingMedian"
	
	rm ./buf/powerConsumption.$chillerIEEE
	rm ./buf/powerConsumption.$chillerIEEE.sort
	rm ./buf/powerLoadingPerCounts.$chillerIEEE
	rm ./buf/powerLoadingPerCounts.$chillerIEEE.sort
	
	#Power Consumption(Median)
	echo "$powerConsumption" >> ./data/chiller.$startDay.$chillerIEEE

	#Power Loading Validation Median
	echo "scale=2;$powerLoadingMedian/10"|bc >> ./data/chiller.$startDay.$chillerIEEE
	
	#Power Loading Validation
	echo "$powerLoadingLevel_0" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_1" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_2" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_3" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_4" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_5" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_6" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_7" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_8" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_9" >> ./data/chiller.$startDay.$chillerIEEE
	echo "$powerLoadingLevel_10" >> ./data/chiller.$startDay.$chillerIEEE
	
	arrNum=$(($arrNum-1))
done

exit 0
