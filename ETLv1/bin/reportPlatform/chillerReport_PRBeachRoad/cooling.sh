#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入  需要的"
		echo "		Cooling IEEE"
		echo "		起始日期 2019-12-15"
		echo "		00:00"
		echo "		結束日期 2019-12-16"
		echo "		00:00"
		echo " 		Cooling Capacity(W)"
		echo "		Cooling Kwh"
        exit 1
fi

IEEE=${1}
startDay=${2}
startTime=${3}
endDay=${4}
endTime=${5}

capacityW=${6}
runKwh=${7}

host=127.0.0.1

today=$(date "+%Y-%m-%d" --date="-1 day")

if [ ${2} == $today ]; then
	db="iotmgmt"
else
	db="iotdata"
fi

data=($(mysql -h ${host} -D$db -ss -e"select date_format(receivedSync, '%Y-%m-%d %H:%i')as time,ieee,IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0) as watt
from
(
	SELECT *
	 FROM pm WHERE ieee='$IEEE' 
	and receivedSync>='$startDay $startTime' and receivedSync<'$endDay 01:00'
) as a WHERE 
receivedSync >='$startDay $startTime' and receivedSync <'$endDay $endTime'
GROUP BY time
"))


dataNum=0

if [ "${data[$dataNum]}" == "" ]; then
	echo "++++$IEEE $startDay $startTime~$endDay $endTime cooling Power Meter no data+++"
	echo "0" > ./data/cooling.$startDay.$IEEE
	exit 0
fi

arrNum=1
flagStartNum=0 #開啟狀態表示
flagEndNum=0 #關閉狀態表示

while :
do
	if [ "${data[$dataNum]}" == "" ]; then
		break
	fi

	pretsDay=$tsDay
	pretsTime=$tsTime
	perIeee=$ieee
	perWatt=$watt


	tsDay=${data[$dataNum]}
	dataNum=$(($dataNum+1))
	
	tsTime=${data[$dataNum]}
	dataNum=$(($dataNum+1))
	
	ieee=${data[$dataNum]}
	dataNum=$(($dataNum+1))
	
	watt=${data[$dataNum]}
	dataNum=$(($dataNum+1))
	
	#echo "[DEBUG]$tsDay $tsTime $ieee $wattHourData $watt"
	
	# 紀錄運行時間(每分鐘) 
	# $watt < $runKwh KW && flagEndNum=0 flagStartNum=0 表示設備這一分鐘 '開始關閉(初)'
	if [ $watt -lt $runKwh ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then

		#echo "Level 1"
		
		#記錄狀態 關閉
		flag[$arrNum]=0
		#初始0 開始計算
		count[$arrNum]=0
		
		startDayArr[$arrNum]=$tsDay
		startTimeArr[$arrNum]=$tsTime

		flagEndNum=1 #開始關閉
		
	# $watt > $runKwh KW && flagEndNum=0 flagStartNum=0 表示設備這一分鐘 '開始運作(初)'
	elif [ $watt -gt $runKwh ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 0 ]; then
		
		#echo "Level 2"
		
		#記錄狀態 開啟
		flag[$arrNum]=1
		#初始0 開始計算
		count[$arrNum]=0

		startDayArr[$arrNum]=$tsDay
		startTimeArr[$arrNum]=$tsTime
		
		flagStartNum=1 #開始運作
		
		echo "${startDayArr[$arrNum]} ${startTimeArr[$arrNum]}"	


	# $watt > $runKwh KW && flagEndNum=1 flagStartNum=0 表示設備這一分鐘 '開始運作(狀態轉換)'
	elif [ $watt -gt $runKwh ] && [ $flagEndNum == 1 ] && [ $flagStartNum == 0 ]; then
	
		#echo "Level 3"
		endDayArr[$arrNum]=$pretsDay
		endTimeArr[$arrNum]=$pretsTime
		
		#Next array
		arrNum=$(($arrNum+1))

		#轉換狀態 開啟
		flag[$arrNum]=1
		#初始0 重新計算count
		count[$arrNum]=0

		startDayArr[$arrNum]=$tsDay
		startTimeArr[$arrNum]=$tsTime
		
		flagStartNum=1 #開始運作 
		flagEndNum=0 #開啟 由1轉0

	# $watt < $runKwh KW && flagEndNum=0 flagStartNum=1 表示設備這一分鐘 '開始關閉(狀態轉換)'	
	# < 1KW	pumpFlag=0 end pump
	elif [ $watt -lt $runKwh ] && [ $flagEndNum == 0 ] && [ $flagStartNum == 1 ]; then
	
		#echo "Level 4"
		
		endDayArr[$arrNum]=$pretsDay
		endTimeArr[$arrNum]=$pretsTime
		
		#Next array
		arrNum=$(($arrNum+1))

		#轉換狀態 關閉
		flag[$arrNum]=0
		#初始0 重新計算count
		count[$arrNum]=0

		startDayArr[$arrNum]=$tsDay
		startTimeArr[$arrNum]=$tsTime

		flagStartNum=0 #開始關閉 
		flagEndNum=1 #關閉運作
	fi
	
	count[$arrNum]=$((${count[$arrNum]}+1))
	
	#totalNegativeWattHour
done

#end
endDayArr[$arrNum]=$tsDay
endTimeArr[$arrNum]=$tsTime

echo "$arrNum" > ./data/cooling.$startDay.$IEEE

while :
do
	if [ $arrNum == 0 ]; then
		break
	fi

	#start time
	echo "${startDayArr[$arrNum]}" >> ./data/cooling.$startDay.$IEEE
	echo "${startTimeArr[$arrNum]}" >> ./data/cooling.$startDay.$IEEE
	
	#end time
	echo "${endDayArr[$arrNum]}" >> ./data/cooling.$startDay.$IEEE
	echo "${endTimeArr[$arrNum]}" >> ./data/cooling.$startDay.$IEEE
	
	#operationFlag
	#echo "operationFlag:${flag[$arrNum]}"
	echo "${flag[$arrNum]}" >> ./data/cooling.$startDay.$IEEE
	
	#total kw
	# totalkwh=($(mysql -h ${host} -D$db -ss -e"select sum(totalWattHour)/1000
	# from
	# (
		# SELECT round(sum(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/60,0) as totalWattHour
		 # FROM pm WHERE ieee='$IEEE' and 
		 # receivedSync >= '${startDayArr[$arrNum]} ${startTimeArr[$arrNum]}' and 
		 # receivedSync < '${endDayArr[$arrNum]} ${endTimeArr[$arrNum]}:59' 
		# group by date_format(receivedSync, '%H')
	# ) as a
	# "))
	#echo "total kwh=$totalkwh"
	totalWh=($(mysql -h ${host} -D$db -ss -e"select sum(totalWattHour)
	from
	(
		SELECT round(sum(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/60,0) as totalWattHour
		 FROM pm WHERE ieee='$IEEE' and 
		 receivedSync >= '${startDayArr[$arrNum]} ${startTimeArr[$arrNum]}' and 
		 receivedSync < '${endDayArr[$arrNum]} ${endTimeArr[$arrNum]}:59' 
		group by date_format(receivedSync, '%H')
	) as a
	"))
	if [ "$totalWh" == "NULL" ]; then
		echo "0" >> ./data/cooling.$startDay.$IEEE
	else
		echo "$totalWh" >> ./data/cooling.$startDay.$IEEE
	fi

	#operationMinutes
	runMinutesStart=$(date -d "${startDayArr[$arrNum]} ${startTimeArr[$arrNum]}" +%s)
	runMinutesEnd=$(date -d "${endDayArr[$arrNum]} ${endTimeArr[$arrNum]}" +%s)

	runMinutes=$(($runMinutesEnd-$runMinutesStart))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	
	#echo "operationMinutes:$runMinutes"
	echo "$runMinutes" >> ./data/cooling.$startDay.$IEEE
	
	#dataCount
	#echo "count=${count[$arrNum]}"
	echo "${count[$arrNum]}" >> ./data/cooling.$startDay.$IEEE

	powerMeterData=($(mysql -h ${host} -D$db -ss -e"select truncate((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000,2) as kw,IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0) as watt
	FROM pm WHERE ieee='$IEEE' and
		receivedSync >='${startDayArr[$arrNum]} ${startTimeArr[$arrNum]}' and 
		receivedSync <= '${endDayArr[$arrNum]} ${endTimeArr[$arrNum]}:59'
	  GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i')
	"))
	
	powerConsumptionLevel_0=0
	powerConsumptionLevel_1=0
	powerConsumptionLevel_2=0
	powerConsumptionLevel_3=0
	powerConsumptionLevel_4=0
	powerConsumptionLevel_5=0

	medianNum=0
	whileNum=0
	
	while :
	do
		if [ "${powerMeterData[$whileNum]}" == "" ]; then
			break
		fi
		
		#Power Consumption
		echo "${powerMeterData[$whileNum]}" >> ./buf/cooling.$startDay.$IEEE
		whileNum=$(($whileNum+1))
		
		#Power Consumption level
		watt=${powerMeterData[$whileNum]}

		if [ $watt == 0 ]; then
		#0
			powerConsumptionLevel_0=$(($powerConsumptionLevel_0+1)) 

		elif [ $watt -gt 1 ] && [ $watt -le 4999 ]; then
		#0.01~4.99	
			powerConsumptionLevel_1=$(($powerConsumptionLevel_1+1)) 
		
		elif [ $watt -ge 5000 ] && [ $watt -le 9999 ]; then
		#5~9.99	
			powerConsumptionLevel_2=$(($powerConsumptionLevel_2+1)) 

		elif [ $watt -ge 10000 ] && [ $watt -le 14999 ]; then
		#10~14.99	
			powerConsumptionLevel_3=$(($powerConsumptionLevel_3+1)) 

		elif [ $watt -ge 15000 ] && [ $watt -lt 19999 ]; then
		#15~19.99	
			powerConsumptionLevel_4=$(($powerConsumptionLevel_4+1)) 

		elif [ $watt -ge 20000 ] && [ $watt -lt 24999 ]; then
		#20~24.99	
			powerConsumptionLevel_5=$(($powerConsumptionLevel_5+1)) 

		else
			echo "[ERROR]pump power consumption per counts data:$watt"
		fi
		
		whileNum=$(($whileNum+1))
		medianNum=$(($medianNum+1))
	done
	
	medianNum=$(($medianNum/2))
	if [ $medianNum == 0 ]; then
		medianNum=1
	fi
	#echo "Median Num:$medianNum"
	if [ ! -f "./buf/cooling.$startDay.$IEEE" ]; then
		#檔案不存在
		echo "[ERROR]Directory ./buf/cooling.$startDay.$IEEE does not exists."
		
		#Power Consumption(Median)
		echo "$powerConsumption" >> ./data/cooling.$startDay.$IEEE
		
		#Power Consumption Level
		echo "$powerConsumptionLevel_0" >> ./data/cooling.$startDay.$IEEE
		echo "$powerConsumptionLevel_1" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_2" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_3" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_4" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_5" >> ./data/cooling.$startDay.$IEEE
		
	else
		#Power Consumption
		sort -n ./buf/cooling.$startDay.$IEEE >> ./buf/cooling.$startDay.$IEEE.sort
		powerConsumption="$(cat ./buf/cooling.$startDay.$IEEE.sort | head -n $medianNum | tail -n 1)"

		rm ./buf/cooling.$startDay.$IEEE
		rm ./buf/cooling.$startDay.$IEEE.sort

		#Power Consumption(Median)
		echo "$powerConsumption" >> ./data/cooling.$startDay.$IEEE

		#Power Consumption Level
		echo "$powerConsumptionLevel_0" >> ./data/cooling.$startDay.$IEEE
		echo "$powerConsumptionLevel_1" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_2" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_3" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_4" >> ./data/cooling.$startDay.$IEEE 
		echo "$powerConsumptionLevel_5" >> ./data/cooling.$startDay.$IEEE
	fi
	
	arrNum=$(($arrNum-1))
done

exit 0
