#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入 日期範圍"
		echo "		2019-12-15"
		echo "		00:00"
		echo "		2019-12-16"
		echo "		00:00"
		echo "		gatewayId"
		echo "		泵浦IEEE"
		echo " 		Capacity(W)"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}

pumpIEEE=${6}
capacityValue=${7}

#array defined
powerPer=(1 2 3 4 5 6 7 8 9 10 11)

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

pumpName=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$pumpIEEE';"))
pumpId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as pumpId FROM iotmgmtChiller.vDeviceInfo where ieee='$pumpIEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))

echo "bash ./pump.sh $pumpIEEE $startDay $startTime $endDay $endTime $capacityValue 1000"
bash ./pump.sh $pumpIEEE $startDay $startTime $endDay $endTime $capacityValue 1000

if [ ! -f "pump.txt" ]; then
	echo "[ERROR]Directory pump.txt does not exists."
	exit 1
fi

time_num="$(cat pump.txt | head -n 1 | tail -n 1)"

if [ "$time_num" == "" ]; then
	echo "++++ cat pump.txt error ++++"
	echo "error" > delete.txt
	rm *.txt
	exit 0
fi

#pump
start_day_head=2
start_time_head=3
end_day_head=4
end_time_head=5
flag_head=6
powerWh_head=7
runMinutes_head=8
count_head=9
powerConsumption_head=10
powerConsumptionLevel_head=11

while :
do
	if [ $time_num == 0 ]; then
		break
	fi
	
	#pump start time
	start_day="$(cat pump.txt | head -n $start_day_head | tail -n 1)"
	start_time="$(cat pump.txt | head -n $start_time_head | tail -n 1)"
	
	#pump end time
	end_day="$(cat pump.txt | head -n $end_day_head | tail -n 1)"
	end_time="$(cat pump.txt | head -n $end_time_head | tail -n 1)"

	#operationFlag
	flag="$(cat pump.txt | head -n $flag_head | tail -n 1)"
	
	#total kw
	powerWh="$(cat pump.txt | head -n $powerWh_head | tail -n 1)"

	#runMinutes
	runMinutes="$(cat pump.txt | head -n $runMinutes_head | tail -n 1)"
	
	#Count
	dataCount="$(cat pump.txt | head -n $count_head | tail -n 1)"	
	
	#Power Consumption
	powerConsumption="$(cat pump.txt | head -n $powerConsumption_head | tail -n 1)"
	
	#Power Consumption Level
	for i in {0..5};
	do
		powerConsumptionNum=$(($powerConsumptionLevel_head+$i))
		powerPer[i]="$(cat pump.txt | head -n $powerConsumptionNum | tail -n 1)"
	done
	

	echo "replace INTO dailyPumpData(
		operationDate,siteId,gatewayId,pumpId,pumpDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerConsumptionDataCounts
		) 
		VALUES(
		'$start_day','$siteId','$gwId', '$pumpId', '$pumpName', '$start_day $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'{\"level1\": ${powerPer[0]}, 
		  \"level2\": ${powerPer[1]}, 
		  \"level3\": ${powerPer[2]}, 
		  \"level4\": ${powerPer[3]}, 
		  \"level5\": ${powerPer[4]}, 
		  \"level6\": ${powerPer[5]}}'
		);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyPumpData(
		operationDate,siteId,gatewayId,pumpId,pumpDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerConsumptionDataCounts
		) 
		VALUES(
		'$start_day','$siteId','$gwId', '$pumpId', '$pumpName', '$start_day $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'{\"level1\": ${powerPer[0]}, 
		  \"level2\": ${powerPer[1]}, 
		  \"level3\": ${powerPer[2]}, 
		  \"level4\": ${powerPer[3]}, 
		  \"level5\": ${powerPer[4]}, 
		  \"level6\": ${powerPer[5]}}'
		);
	"							 

	#Next Data
	time_num=$(($time_num-1))
	
	next_num=15

	start_day_head=$(($start_day_head+$next_num))
	start_time_head=$(($start_time_head+$next_num))
	
	end_day_head=$(($end_day_head+$next_num))
	end_time_head=$(($end_time_head+$next_num))
	
	flag_head=$(($flag_head+$next_num))
	powerWh_head=$(($powerWh_head+$next_num))
	
	runMinutes_head=$(($runMinutes_head+$next_num))
	count_head=$(($count_head+$next_num))
	
	powerConsumption_head=$(($powerConsumption_head+$next_num))
	powerConsumptionLevel_head=$(($powerConsumptionLevel_head+$next_num))

done

rm ./pump.txt
exit 0