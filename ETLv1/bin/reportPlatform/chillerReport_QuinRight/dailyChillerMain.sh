#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入./chillerMain.sh 2020-09-17 00:00 2020-09-18 00:00 112 ppssbms0001 230400 ppssbms0010 temp1 dTemperature ppssbms0010 temp2 dTemperature 0 0"
		echo "		start date"
		echo "		start time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo " 		Capacity(W)"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Supply Table"
		echo "		Flow IEEE"
		echo "		Flow Table"
        exit 1
fi

if [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] || [ "${12}" == "" ] || [ "${13}" == "" ] || [ "${14}" == "" ] || [ "${15}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 207200 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature 00124b000be4cbf5 ultrasonicFlow"
		echo "		start date"
		echo "		start time"
		echo "		end date"
		echo "		end time"
		echo "	 	Gateway ID"
		echo "		Chiler IEEE"
		echo " 		Capacity(W)"
		echo "		Supply Temp IEEE"
		echo "		Supply Value"
		echo "		Supply Table"
		echo "		Return Temp IEEE"
		echo "		Return Value"
		echo "		Supply Table"
		echo "		Flow IEEE"
		echo "		Flow Table"
		exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

gwId=${5}

chillerIEEE=${6}
capacityValue=${7}

tempSupplyIEEE=${8}
tempSupplyValue=${9}
tempSupplyTable=${10}

tempReturnIEEE=${11}
tempReturnValue=${12}
tempReturnTable=${13}

flowIEEE=${14}
flowTable=${15}

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

chiname=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))
chiId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as chillerId FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))
siteId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gwId;"))

echo "  -----------------Id:$chiId $chiname-------------------- "

#array defined

#tempSupplyPer=(1 2 3 4 5 6 7 8 9 10 11 12 13)
#tempReturnPer=(1 2 3 4 5 6 7 8 9 10 11 12 13)
echo "  bash ./chiller.sh $chillerIEEE $startDay $startTime $endDay $endTime $capacityValue 10000"
bash ./chiller.sh $chillerIEEE $startDay $startTime $endDay $endTime $capacityValue 10000

if [ ! -f "./data/chiller.$startDay.$chillerIEEE" ]; then
	echo "[ERROR]Directory ./data/chiller.$startDay.$chillerIEEE does not exists."
	exit 1
fi

time_num="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n 1 | tail -n 1)"

if [ $time_num == 0 ]; then
	echo "[ERROR]++++ ./data/chiller.$startDay.$chillerIEEE is no data ++++"
	exit 2
fi

#chiller
startDay_head=2
start_time_head=3
end_day_head=4
end_time_head=5
flag_head=6
powerWh_head=7
runMinutes_head=8
count_head=9
powerConsumption_head=10
powerLoading_head=11
powerLoadingConut_head=12

#temp
tempPer_head=5

while :
do
	if [ $time_num == 0 ]; then
		break
	fi
	
	#chiller start time
	startDay="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $startDay_head | tail -n 1)"
	start_time="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $start_time_head | tail -n 1)"
	
	#chiller end time
	end_day="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $end_day_head | tail -n 1)"
	end_time="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $end_time_head | tail -n 1)"

	#operationFlag
	flag="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $flag_head | tail -n 1)"
	
	#total kw
	powerWh="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $powerWh_head | tail -n 1)"

	#runMinutes
	runMinutes="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $runMinutes_head | tail -n 1)"
	
	#Count
	dataCount="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $count_head | tail -n 1)"	
	
	#Power Consumption
	powerConsumption="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $powerConsumption_head | tail -n 1)"
	
	#Power Loading
	powerLoading="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $powerLoading_head | tail -n 1)"

	for i in {0..10};
	do
		powerLoadingNum=$(($powerLoadingConut_head+$i))
		chiPowerPer[i]="$(cat ./data/chiller.$startDay.$chillerIEEE | head -n $powerLoadingNum | tail -n 1)"
	done

	#********************
	# Temp Supply        
	
	echo "  bash ./tempData.sh $startDay $start_time $end_day $end_time $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $gwId"
	bash ./tempData.sh $startDay $start_time $end_day $end_time $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $gwId

	fileNum="$(ls ./data/ | grep temp.$startDay.$tempSupplyIEEE | wc -l)"
	

	if [ $fileNum == 0 ]; then
	
		echo "++++ cat ./data/temp.$startDay.$tempSupplyIEEE error ++++"
		supplyMin="NULL"
		supplyMax="NULL"
		supplyMedian="NULL"
		tempSupplyPer[0]="NULL"
		supplyCount="NULL"

	else
		#avgChwr minChwr maxChwr medChwr
		#avgChwr="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n 1 | tail -n 1)"
		supplyMin="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n 2 | tail -n 1)"
		supplyMax="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n 3 | tail -n 1)"
		supplyMedian="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n 4 | tail -n 1)"
		
		for i in {0..12};
		do
			num=$(($tempPer_head+$i))
			tempSupplyPer[i]="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n $num | tail -n 1)"
			#echo "${tempSupplyPer[i]}"
		done
		
		supplyCount="$(cat ./data/temp.$startDay.$tempSupplyIEEE | head -n 18 | tail -n 1)"
		rm ./data/temp.$startDay.$tempSupplyIEEE
	fi

	#*******************
	# Temp Return

	echo "  bash ./tempData.sh $startDay $start_time $end_day $end_time $tempReturnIEEE $tempReturnValue $tempReturnTable $gwId"
	bash ./tempData.sh $startDay $start_time $end_day $end_time $tempReturnIEEE $tempReturnValue $tempReturnTable $gwId

	fileNum="$(ls ./data/ | grep temp.$startDay.$tempReturnIEEE | wc -l)"
	

	if [ $fileNum == 0 ]; then
		echo "++++ cat temp.$startDay.$tempReturnIEEE error ++++"
		returnMin="NULL"
		returnMax="NULL"
		returnMedian="NULL"
		tempReturnPer[0]="NULL"
		returnCount="NULL"
	else
		#avgChwr minChwr maxChwr medChwr
		#chitemp[4]="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n 1 | tail -n 1)"
		returnMin="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n 2 | tail -n 1)"
		returnMax="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n 3 | tail -n 1)"
		returnMedian="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n 4 | tail -n 1)"
		
		for i in {0..12};
		do
			num=$(($tempPer_head+$i))
			tempReturnPer[i]="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n $num | tail -n 1)"
			#echo "${tempReturnPer[i]}"
		done
		
		returnCount="$(cat ./data/temp.$startDay.$tempReturnIEEE | head -n 18 | tail -n 1)"
		rm ./data/temp.$startDay.$tempReturnIEEE
	fi
	
	#*******************
	# Temp Delta
	echo "  bash ./tempDeltaCapacity.sh $startDay $start_time $end_day $end_time $chillerIEEE $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable $flowIEEE $flowTable $gwId"
	bash ./tempDeltaCapacity.sh $startDay $start_time $end_day $end_time $chillerIEEE $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable $flowIEEE $flowTable $gwId
	
	fileNum="$(ls ./data/ | grep Delta.$startDay.$chillerIEEE | wc -l)"
	
	if [ $fileNum == 0 ]; then
		echo "++++ cat Delta.$startDay.$chillerIEEE error ++++"
		deltaCount="NULL"
		
		cntDelta0="NULL"
		cntDelta9="NULL"
		cntDelta19="NULL"
		cntDelta29="NULL"
		cntDelta39="NULL"
		cntDelta49="NULL"
		cntDelta59="NULL"
		cntDelta60="NULL"
		
		deltaMin="NULL"
		deltaMedian="NULL"
		deltaMax="NULL"
		
		capacity="NULL"
	else
		
		deltaCount="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 13 | tail -n 1)"
		
		cntDelta0="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 1 | tail -n 1)"
		cntDelta9="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 2 | tail -n 1)"
		cntDelta19="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 3 | tail -n 1)"
		cntDelta29="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 4 | tail -n 1)"
		cntDelta39="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 5 | tail -n 1)"
		cntDelta49="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 6 | tail -n 1)"
		cntDelta59="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 7 | tail -n 1)"
		cntDelta60="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 8 | tail -n 1)"
		
		deltaMin="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 9 | tail -n 1)"
		deltaMedian="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 10 | tail -n 1)"
		deltaMax="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 11 | tail -n 1)"
		
		capacity="$(cat ./data/Delta.$startDay.$chillerIEEE | head -n 12 | tail -n 1)"

		rm ./data/Delta.$startDay.$chillerIEEE
	fi
	
	# echo "  Flow Rate"
	# echo "  bash flowMedian.sh $startDay $start_time $end_day $end_time $flowIEEE $flowTable"
	# bash flowMedian.sh $startDay $start_time $end_day $end_time $flowIEEE $flowTable
	
	# fileNum="$(ls ./data/ | grep flowMedian.$startDay.$flowIEEE | wc -l)"
	
	# flowMedianNULL=0
	
	# if [ $fileNum == 0 ]; then
		# flowMedianNULL=1
		# #flowMedian
	# else
		# flowMedian="$(cat ./data/flowMedian.$startDay.$flowIEEE | head -n 1 | tail -n 1)"
		# rm ./data/flowMedian.$startDay.$flowIEEE
	# fi

	echo "replace INTO dailyChillerData(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerLoading,capacity,
		powerLoadingDataCounts
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiname', '$startDay $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'$powerLoading',if($capacity is NULL,NULL,'$capacity'),
		if(${chiPowerPer[0]} is NULL,NULL,'{\"level1\": ${chiPowerPer[0]}, 
		\"level2\": ${chiPowerPer[1]}, 
		\"level3\": ${chiPowerPer[2]}, 
		\"level4\": ${chiPowerPer[3]}, 
		\"level5\": ${chiPowerPer[4]}, 
		\"level6\": ${chiPowerPer[5]},
		\"level7\": ${chiPowerPer[6]},
		\"level8\": ${chiPowerPer[7]},
		\"level9\": ${chiPowerPer[8]},
		\"level10\": ${chiPowerPer[9]},
		\"level11\": ${chiPowerPer[10]}}')
		);
	"
	
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerData(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerLoading,capacity,
		powerLoadingDataCounts
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiname', '$startDay $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'$powerLoading',if($capacity is NULL,NULL,'$capacity'),
		if(${chiPowerPer[0]} is NULL,NULL,'{\"level1\": ${chiPowerPer[0]}, 
		\"level2\": ${chiPowerPer[1]}, 
		\"level3\": ${chiPowerPer[2]}, 
		\"level4\": ${chiPowerPer[3]}, 
		\"level5\": ${chiPowerPer[4]}, 
		\"level6\": ${chiPowerPer[5]},
		\"level7\": ${chiPowerPer[6]},
		\"level8\": ${chiPowerPer[7]},
		\"level9\": ${chiPowerPer[8]},
		\"level10\": ${chiPowerPer[9]},
		\"level11\": ${chiPowerPer[10]}}')
		);
	"
	
	echo "replace INTO dailyChillerTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax,
		supplyDataCounts,
		returnDataCounts,
		deltaDataCounts
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiname', '$startDay $start_time', '$end_day $end_time',
		'$runMinutes','$flag',
		if($supplyCount is NULL,NULL,'$supplyCount'),if($supplyMin is NULL,NULL,'$supplyMin'),
		if($supplyMedian is NULL,NULL,'$supplyMedian'),if($supplyMax is NULL,NULL,'$supplyMax'),
		if($returnCount is NULL,NULL,'$returnCount'),if($returnMin is NULL,NULL,'$returnMin'),
		if($returnMedian is NULL,NULL,'$returnMedian'),if($returnMax is NULL,NULL,'$returnMax'),
		if($deltaCount is NULL,NULL,'$deltaCount'),
		if($deltaMin is NULL,NULL,'$deltaMin'),
		if($deltaMedian is NULL,NULL,'$deltaMedian'),
		if($deltaMax is NULL,NULL,'$deltaMax'),
		if(${tempSupplyPer[0]} is NULL,NULL,
		'{\"level1\": ${tempSupplyPer[0]}, 
		  \"level2\": ${tempSupplyPer[1]}, 
		  \"level3\": ${tempSupplyPer[2]}, 
		  \"level4\": ${tempSupplyPer[3]}, 
		  \"level5\": ${tempSupplyPer[4]}, 
		  \"level6\": ${tempSupplyPer[5]},
		  \"level7\": ${tempSupplyPer[6]}, 
		  \"level8\": ${tempSupplyPer[7]}, 
		  \"level9\": ${tempSupplyPer[8]}, 
		  \"level10\": ${tempSupplyPer[9]}, 
		  \"level11\": ${tempSupplyPer[10]},
		  \"level12\": ${tempSupplyPer[11]},
		  \"level13\": ${tempSupplyPer[12]}}'),
		if(${tempReturnPer[0]} is NULL,NULL,'{\"level1\": ${tempReturnPer[0]}, 
		  \"level2\": ${tempReturnPer[1]}, 
		  \"level3\": ${tempReturnPer[2]}, 
		  \"level4\": ${tempReturnPer[3]}, 
		  \"level5\": ${tempReturnPer[4]}, 
		  \"level6\": ${tempReturnPer[5]},
		  \"level7\": ${tempReturnPer[6]}, 
		  \"level8\": ${tempReturnPer[7]}, 
		  \"level9\": ${tempReturnPer[8]}, 
		  \"level10\": ${tempReturnPer[9]}, 
		  \"level11\": ${tempReturnPer[10]},
		  \"level12\": ${tempReturnPer[11]},
		  \"level13\": ${tempReturnPer[12]}}'),
		if($cntDelta0 is NULL,NULL,'
		 {\"level1\": $cntDelta0, 
		  \"level2\": $cntDelta9, 
		  \"level3\": $cntDelta19, 
		  \"level4\": $cntDelta29, 
		  \"level5\": $cntDelta39, 
		  \"level6\": $cntDelta49,
		  \"level7\": $cntDelta59, 
		  \"level8\": $cntDelta60}')
		);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerTemp(
		operationDate,siteId,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax,
		supplyDataCounts,
		returnDataCounts,
		deltaDataCounts
		) 
		VALUES(
		'$startDay','$siteId','$gwId', '$chiId', '$chiname', '$startDay $start_time', '$end_day $end_time',
		'$runMinutes','$flag',
		if($supplyCount is NULL,NULL,'$supplyCount'),if($supplyMin is NULL,NULL,'$supplyMin'),
		if($supplyMedian is NULL,NULL,'$supplyMedian'),if($supplyMax is NULL,NULL,'$supplyMax'),
		if($returnCount is NULL,NULL,'$returnCount'),if($returnMin is NULL,NULL,'$returnMin'),
		if($returnMedian is NULL,NULL,'$returnMedian'),if($returnMax is NULL,NULL,'$returnMax'),
		if($deltaCount is NULL,NULL,'$deltaCount'),
		if($deltaMin is NULL,NULL,'$deltaMin'),
		if($deltaMedian is NULL,NULL,'$deltaMedian'),
		if($deltaMax is NULL,NULL,'$deltaMax'),
		if(${tempSupplyPer[0]} is NULL,NULL,
		'{\"level1\": ${tempSupplyPer[0]}, 
		  \"level2\": ${tempSupplyPer[1]}, 
		  \"level3\": ${tempSupplyPer[2]}, 
		  \"level4\": ${tempSupplyPer[3]}, 
		  \"level5\": ${tempSupplyPer[4]}, 
		  \"level6\": ${tempSupplyPer[5]},
		  \"level7\": ${tempSupplyPer[6]}, 
		  \"level8\": ${tempSupplyPer[7]}, 
		  \"level9\": ${tempSupplyPer[8]}, 
		  \"level10\": ${tempSupplyPer[9]}, 
		  \"level11\": ${tempSupplyPer[10]},
		  \"level12\": ${tempSupplyPer[11]},
		  \"level13\": ${tempSupplyPer[12]}}'),
		if(${tempReturnPer[0]} is NULL,NULL,
		'{\"level1\": ${tempReturnPer[0]}, 
		  \"level2\": ${tempReturnPer[1]}, 
		  \"level3\": ${tempReturnPer[2]}, 
		  \"level4\": ${tempReturnPer[3]}, 
		  \"level5\": ${tempReturnPer[4]}, 
		  \"level6\": ${tempReturnPer[5]},
		  \"level7\": ${tempReturnPer[6]}, 
		  \"level8\": ${tempReturnPer[7]}, 
		  \"level9\": ${tempReturnPer[8]}, 
		  \"level10\": ${tempReturnPer[9]}, 
		  \"level11\": ${tempReturnPer[10]},
		  \"level12\": ${tempReturnPer[11]},
		  \"level13\": ${tempReturnPer[12]}}'),
		if($cntDelta0 is NULL,NULL,'
		 {\"level1\": $cntDelta0, 
		  \"level2\": $cntDelta9, 
		  \"level3\": $cntDelta19, 
		  \"level4\": $cntDelta29, 
		  \"level5\": $cntDelta39, 
		  \"level6\": $cntDelta49,
		  \"level7\": $cntDelta59, 
		  \"level8\": $cntDelta60}')
		);
	"

	#Next Data
	time_num=$(($time_num-1))
	
	next_num=21

	startDay_head=$(($startDay_head+$next_num))
	start_time_head=$(($start_time_head+$next_num))
	
	end_day_head=$(($end_day_head+$next_num))
	end_time_head=$(($end_time_head+$next_num))
	
	flag_head=$(($flag_head+$next_num))
	powerWh_head=$(($powerWh_head+$next_num))
	
	runMinutes_head=$(($runMinutes_head+$next_num))
	count_head=$(($count_head+$next_num))
	
	powerConsumption_head=$(($powerConsumption_head+$next_num))
	powerLoading_head=$(($powerLoading_head+$next_num))
	powerLoadingConut_head=$(($powerLoadingConut_head+$next_num))

done

if [ -f "./data/chiller.$startDay.$chillerIEEE" ]; then
	rm ./data/chiller.$startDay.$chillerIEEE
fi

exit 0