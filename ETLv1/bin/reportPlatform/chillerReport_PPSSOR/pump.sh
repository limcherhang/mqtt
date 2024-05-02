#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入  需要的"
		echo "		泵浦的IEEE"
		echo "		起始日期 2019-12-15"
		echo "		00:00"
		echo "		結束日期 2019-12-16"
		echo "		00:00"
		echo " 		Capacity(W)"
		echo "      chiller運作W"
        exit 1
fi

pumpIEEE=${1}
startDay=${2}
startTime=${3}
endDay=${4}
endTime=${5}

capacityW=${6}
pump_kwh=${7}

pumpStartDay=(1 2 3 4 5 6 7 8 9 10)
pumpStartTime=(1 2 3 4 5 6 7 8 9 10)
pumpStartWatt=(1 2 3 4 5 6 7 8 9 10)

pumpEndDay=(1 2 3 4 5 6 7 8 9 10)
pumpEndTime=(1 2 3 4 5 6 7 8 9 10)
pumpEndWatt=(1 2 3 4 5 6 7 8 9 10)

pumpFlag=(1 2 3 4 5 6 7 8 9 10)
pumpCount=(1 2 3 4 5 6 7 8 9 10)

host="127.0.0.1"
today=$(date "+%Y-%m-%d" --date="-1 day")

if [ ${2} == $today ]; then
	db="iotmgmt"
else
	db="iotdata"
fi

pump_data=($(mysql -h ${host} -D$db -ss -e"select 
	date_format(receivedSync, '%Y-%m-%d %H:%i')as time,
	ieee,
	round((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/60,0) as wattHour,
	truncate(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0),0) as watt
FROM pm WHERE ieee='$pumpIEEE' and
	receivedSync >='$startDay $startTime' and 
    receivedSync <'$endDay $endTime' and
	(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
GROUP BY time
"))

data_num=0
if [ "${pump_data[$data_num]}" == "" ]; then
	echo "++++$pumpIEEE $startDay $startTime~$endDay $endTime pump Power Meter no data+++"
	exit 0
fi

arr_num=1

Flag_start_num=0
Flag_end_num=0

while :
do
	if [ "${pump_data[$data_num]}" == "" ]; then
		break
	fi

	ts_day=${pump_data[$data_num]}
	data_num=$(($data_num+1))
	
	ts_time=${pump_data[$data_num]}
	data_num=$(($data_num+1))
	
	ieee=${pump_data[$data_num]}
	data_num=$(($data_num+1))

	#totalNegativeWattHour=${pump_data[$data_num]}
	wattHour=${pump_data[$data_num]}
	data_num=$(($data_num+1))

	watt=${pump_data[$data_num]}
	data_num=$(($data_num+1))
	
	#echo "$ts_day $ts_time $ieee $totalNegativeWattHour $watt"
	# < 1KW pumpFlag=0 end pump
	if [ $watt -lt $pump_kwh ] && [ $Flag_end_num == 0 ] && [ $Flag_start_num == 0 ]; then

		pumpFlag[$arr_num]=0
		pumpCount[$arr_num]=0
		
		pumpStartDay[$arr_num]=$ts_day
		pumpStartTime[$arr_num]=$ts_time
        #pumpStartWatt[$arr_num]=$totalNegativeWattHour
		pumpWattHour[$arr_num]=$wattHour
		
		Flag_start_num=0
		Flag_end_num=1
	# > 1KW pumpFlag=1 start pump
	elif [ $watt -gt $pump_kwh ] && [ $Flag_end_num == 0 ] && [ $Flag_start_num == 0 ]; then
		
		Flag_start_num=1

		pumpFlag[$arr_num]=1
		pumpCount[$arr_num]=0
		
		pumpStartDay[$arr_num]=$ts_day
		pumpStartTime[$arr_num]=$ts_time

		#pumpStartWatt[$arr_num]=$totalNegativeWattHour
		pumpWattHour[$arr_num]=$wattHour
	# > 1KW pumpFlag=1 start pump
	elif [ $watt -gt $pump_kwh ] && [ $Flag_end_num == 1 ] && [ $Flag_start_num == 0 ]; then
	
		Flag_start_num=1
		Flag_end_num=0
		
		#ts_day ts_time ieee totalNegativeWattHour watt(previous data)
		num=$(($data_num-5))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "pumpEndWatt:${pump_data[$num]}"
		#pumpEndWatt[$arr_num]=${pump_data[$num]}
		
		#ts_time
		num=$(($num-2))
		#echo "pumpEndTime:${pump_data[$num]}"
		pumpEndTime[$arr_num]=${pump_data[$num]}
		
		#ts_day
		num=$(($num-1))
		#echo "pumpEndDay:${pump_data[$num]}"
		pumpEndDay[$arr_num]=${pump_data[$num]}
		
		#Next array
		arr_num=$(($arr_num+1))

		pumpFlag[$arr_num]=1
		pumpCount[$arr_num]=0
		
		pumpStartDay[$arr_num]=$ts_day
		pumpStartTime[$arr_num]=$ts_time

		#pumpStartWatt[$arr_num]=$totalNegativeWattHour
		pumpWattHour[$arr_num]=$wattHour
	# < 1KW	pumpFlag=0 end pump
	elif [ $watt -lt $pump_kwh ] && [ $Flag_end_num == 0 ] && [ $Flag_start_num == 1 ]; then
	
		Flag_start_num=0
		Flag_end_num=1
		
		#ts_day ts_time ieee totalNegativeWattHour watt(previous data)
		num=$(($data_num-5))
		
		#totalNegativeWattHour
		num=$(($num-2))
		#echo "pumpEndWatt:${pump_data[$num]}"
		pumpEndWatt[$arr_num]=${pump_data[$num]}
		
		#ts_time
		num=$(($num-2))
		#echo "pumpEndTime:${pump_data[$num]}"
		pumpEndTime[$arr_num]=${pump_data[$num]}
		
		#ts_day
		num=$(($num-1))
		#echo "pumpEndDay:${pump_data[$num]}"
		pumpEndDay[$arr_num]=${pump_data[$num]}

		#Next array
		arr_num=$(($arr_num+1))

		pumpFlag[$arr_num]=0
		pumpCount[$arr_num]=0
		
		pumpStartDay[$arr_num]=$ts_day
		pumpStartTime[$arr_num]=$ts_time

		#pumpStartWatt[$arr_num]=$totalNegativeWattHour
		pumpWattHour[$arr_num]=$wattHour
	fi
	
	pumpWattHour[$arr_num]=$((${pumpWattHour[$arr_num]}+$wattHour))
	
	pumpCount[$arr_num]=$((${pumpCount[$arr_num]}+1))
	
	#echo "$ts_day $ts_time arr:$arr_num watt:$watt--$pump_kwh end:$Flag_end_num start:$Flag_start_num" >> ./debug.log
done

pumpEndDay[$arr_num]=$ts_day
pumpEndTime[$arr_num]=$ts_time
#pumpEndWatt[$arr_num]=$totalNegativeWattHour

echo "$arr_num" > ./pump.txt
while :
do
	if [ $arr_num == 0 ]; then
		break
	fi
		
	stTime=$(date +%s -d "${pumpStartDay[$arr_num]} ${pumpStartTime[$arr_num]}")
	edTime=$(date +%s -d "${pumpEndDay[$arr_num]} ${pumpEndTime[$arr_num]}")
	
	runTime=$(($edTime-$stTime))

	runTimeMinute=$(($runTime/60))
	
	#echo "(${pumpWattHour[$arr_num]}/${pumpCount[$arr_num]})*$runTimeMinute"
	echo "scale=0;(${pumpWattHour[$arr_num]}/${pumpCount[$arr_num]})*$runTimeMinute"|bc > ./buf/pumpKwh.$pumpIEEE
	pump_kwh="$(cat ./buf/pumpKwh.$pumpIEEE | head -n 1 | tail -n 1)"
	
	rm ./buf/pumpKwh.$pumpIEEE
	
	#echo " $pump_kwh=${pumpEndWatt[$arr_num]}-${pumpStartWatt[$arr_num]}"
	#pump_kwh=$((${pumpEndWatt[$arr_num]}-${pumpStartWatt[$arr_num]}))
	
	#start time
	echo "${pumpStartDay[$arr_num]}" >> ./pump.txt
	echo "${pumpStartTime[$arr_num]}" >> ./pump.txt
	
	#end time
	echo "${pumpEndDay[$arr_num]}" >> ./pump.txt
	echo "${pumpEndTime[$arr_num]}" >> ./pump.txt
	
	#operationFlag
	echo "${pumpFlag[$arr_num]}" >> ./pump.txt
	
	#total kw
	echo "$pump_kwh" >> ./pump.txt
	
	#runMinutes
	runMinutes_start=$(date -d "${pumpStartDay[$arr_num]} ${pumpStartTime[$arr_num]}" +%s)
	runMinutes_end=$(date -d "${pumpEndDay[$arr_num]} ${pumpEndTime[$arr_num]}" +%s)

	runMinutes=$(($runMinutes_end-$runMinutes_start))
	runMinutes=$(($runMinutes+60)) #補足相減誤差60s
	runMinutes=$(($runMinutes/60))
	echo "$runMinutes" >> ./pump.txt
	
	#Count
	echo "${pumpCount[$arr_num]}" >> ./pump.txt
	
	if [ $startDay == $today ]; then
		db="iotmgmt"
	else
		db="iotdata"
	fi

	powerMeterData=($(mysql -h ${host} -D$db -ss -e"select truncate((IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000,2) as kw,IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0) as watt
	from
	(
		SELECT *
		 FROM pm WHERE ieee='$pumpIEEE' 
		and receivedSync>='$startDay $startTime' and receivedSync<'$endDay 01:00'
	) as a WHERE 
	receivedSync >='${pumpStartDay[$arr_num]} ${pumpStartTime[$arr_num]}' and 
	receivedSync <= '${pumpEndDay[$arr_num]} ${pumpEndTime[$arr_num]}:59' and
	(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0)) >= 0
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
		echo "${powerMeterData[$whileNum]}" >> ./powerConsumptionBuf
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
	
	
	if [ $medianNum == 0 ]; then
		medianNum=1
	elif [ $medianNum == 1 ]; then
		medianNum=1
	else
		medianNum=$(($medianNum/2))
	fi
	#echo "Median Num:$medianNum"
	
	#Power Consumption
	sort -n ./powerConsumptionBuf >> ./powerConsumptionBuf.sort
	powerConsumption="$(cat powerConsumptionBuf.sort | head -n $medianNum | tail -n 1)"
	#echo " Power Consumption:$powerConsumption"

	rm ./powerConsumptionBuf
	rm ./powerConsumptionBuf.sort

	#Power Consumption(Median)
	echo "$powerConsumption" >> ./pump.txt

	#Power Consumption Level
	echo "$powerConsumptionLevel_0" >> ./pump.txt
	echo "$powerConsumptionLevel_1" >> ./pump.txt
	echo "$powerConsumptionLevel_2" >> ./pump.txt
	echo "$powerConsumptionLevel_3" >> ./pump.txt
	echo "$powerConsumptionLevel_4" >> ./pump.txt
	echo "$powerConsumptionLevel_5" >> ./pump.txt

	arr_num=$(($arr_num-1))
done

exit 0
