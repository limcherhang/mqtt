#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 日期範圍"
		echo "		2019-12-15"
		echo "		00:00"
		echo "		2019-12-16"
		echo "		00:00"
		echo "		gatewayId"
		echo "		Cooling IEEE"
		echo " 		Cooling Capacity(W)"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}

IEEE=${6}
capacityValue=${7}

host=127.0.0.1

#array defined
powerPer=(1 2 3 4 5 6 7 8 9 10 11)


dbRPF="reportplatform"
dbMgmt="iotmgmt"

Name=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$IEEE';"))
Id=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as Id FROM iotmgmtChiller.vDeviceInfo where ieee='$IEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))


echo "bash ./cooling.sh $IEEE $startDay $startTime $endDay $endTime $capacityValue 1000"
bash ./cooling.sh $IEEE $startDay $startTime $endDay $endTime $capacityValue 1000


if [ ! -f "./data/cooling.$startDay.$IEEE" ]; then
	#檔案不存在
    echo "[ERROR]Directory ./data/cooling.$startDay.$IEEE does not exists."
	exit 0
fi

time_num="$(cat ./data/cooling.$startDay.$IEEE | head -n 1 | tail -n 1)"

if [ $time_num == 0 ]; then
	echo "++++ cooling is no data ++++"
	
	echo "REPlACE INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$Id', '$Name', '$startDay $startTime', '$startDay 23:59:00', 
		'0','0');
	"
	
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$Id', '$Name', '$startDay $startTime', '$startDay 23:59:00', 
		'0','0');
	"	
	exit 0
fi

#cooling.$IEEE
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
	
	#start time
	start_day="$(cat ./data/cooling.$startDay.$IEEE | head -n $start_day_head | tail -n 1)"
	start_time="$(cat ./data/cooling.$startDay.$IEEE | head -n $start_time_head | tail -n 1)"
	
	#end time
	end_day="$(cat ./data/cooling.$startDay.$IEEE | head -n $end_day_head | tail -n 1)"
	end_time="$(cat ./data/cooling.$startDay.$IEEE | head -n $end_time_head | tail -n 1)"

	#operationFlag
	flag="$(cat ./data/cooling.$startDay.$IEEE | head -n $flag_head | tail -n 1)"
	
	#total kw
	powerWh="$(cat ./data/cooling.$startDay.$IEEE | head -n $powerWh_head | tail -n 1)"

	#runMinutes
	runMinutes="$(cat ./data/cooling.$startDay.$IEEE | head -n $runMinutes_head | tail -n 1)"
	
	#Count
	dataCount="$(cat ./data/cooling.$startDay.$IEEE | head -n $count_head | tail -n 1)"	
	
	#Power Consumption
	powerConsumption="$(cat ./data/cooling.$startDay.$IEEE | head -n $powerConsumption_head | tail -n 1)"
	
	#Power Consumption Level
	for i in {0..5};
	do
		powerConsumptionNum=$(($powerConsumptionLevel_head+$i))
		powerPer[i]="$(cat ./data/cooling.$startDay.$IEEE | head -n $powerConsumptionNum | tail -n 1)"
	done
	

	echo "REPlACE INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerConsumptionDataCounts
		) 
		VALUES(
		'$start_day','$siteId','$gwId', '$Id', '$Name', '$start_day $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'{\"level1\": ${powerPer[0]}, 
		  \"level2\": ${powerPer[1]}, 
		  \"level3\": ${powerPer[2]}, 
		  \"level4\": ${powerPer[3]}, 
		  \"level5\": ${powerPer[4]}, 
		  \"level6\": ${powerPer[5]}}'
		);
	"
	mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyCoolingData(
		operationDate,siteId,gatewayId,coolingId,coolingDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerConsumptionDataCounts
		) 
		VALUES(
		'$start_day','$siteId','$gwId', '$Id', '$Name', '$start_day $start_time', '$end_day $end_time', 
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

rm ./data/cooling.$startDay.$IEEE
exit 0