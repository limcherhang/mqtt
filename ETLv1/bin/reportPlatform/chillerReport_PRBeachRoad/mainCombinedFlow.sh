#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 207200 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature 00124b000be4cbf5 ultrasonicFlow"
		echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 104 00124b000be4cce4 142100 00124b000be4cb41 value2 ain 00124b000be4cb41 value1 ain 77.4 0"
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
		echo "		Flow1 IEEE"
		echo "		Flow1 Table"
		echo "		Flow2 IEEE"
		echo "		Flow2 Table"
        exit 1
fi

if [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] || [ "${12}" == "" ] || [ "${13}" == "" ] || [ "${14}" == "" ] || [ "${15}" == "" ] || [ "${16}" == "" ] || [ "${17}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 106 00124b000be4ce1e 207200 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature 00124b000be4cbf5 ultrasonicFlow"
		echo "請輸入 2020-02-12 00:00 2020-02-13 00:00 104 00124b000be4cce4 142100 00124b000be4cb41 value2 ain 00124b000be4cb41 value1 ain 77.4 0"
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
		echo "		Flow1 IEEE"
		echo "		Flow1 Table"
		echo "		Flow2 IEEE"
		echo "		Flow2 Table"
		exit 1
fi

#value defined
start_day=${1}
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

flow1IEEE=${14}
flow1Table=${15}

flow2IEEE=${16}
flow2Table=${17}

host="127.0.0.1"

dbRPF="reportplatform"
dbMgmt="iotmgmt"

chiname=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT deviceDesc FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))
chiId=($(mysql -h ${host} -D$dbMgmt -ss -e"SELECT substring_index(deviceDesc,'#',-1) as chillerId FROM iotmgmtChiller.vDeviceInfo where ieee='$chillerIEEE';"))

#array defined
chiPowerPer=(1 2 3 4 5 6 7 8 9 10 11)

tempSupplyPer=(1 2 3 4 5 6 7 8 9 10 11 12 13)
tempReturnPer=(1 2 3 4 5 6 7 8 9 10 11 12 13)

echo "bash ./chiller.sh $chillerIEEE $start_day $startTime $endDay $endTime $capacityValue"
bash ./chiller.sh $chillerIEEE $start_day $startTime $endDay $endTime $capacityValue

if [ ! -f "./data/chiller.$start_day.$chillerIEEE" ]; then
	echo "[ERROR]Directory ./data/chiller.$start_day.$chillerIEEE does not exists."
	exit 1
fi

time_num="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n 1 | tail -n 1)"

if [ $time_num == 0 ]; then
	echo "[ERROR]++++ ./data/chiller.$start_day.$chillerIEEE is no data ++++"
	exit 2
fi

#chiller
start_day_head=2
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
	start_day="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $start_day_head | tail -n 1)"
	start_time="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $start_time_head | tail -n 1)"
	
	#chiller end time
	end_day="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $end_day_head | tail -n 1)"
	end_time="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $end_time_head | tail -n 1)"

	#operationFlag
	flag="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $flag_head | tail -n 1)"
	
	#total kw
	powerWh="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $powerWh_head | tail -n 1)"

	#runMinutes
	runMinutes="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $runMinutes_head | tail -n 1)"
	
	#Count
	dataCount="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $count_head | tail -n 1)"	
	
	#Power Consumption
	powerConsumption="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $powerConsumption_head | tail -n 1)"
	
	#Power Loading
	powerLoading="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $powerLoading_head | tail -n 1)"

	for i in {0..10};
	do
		powerLoadingNum=$(($powerLoadingConut_head+$i))
		chiPowerPer[i]="$(cat ./data/chiller.$start_day.$chillerIEEE | head -n $powerLoadingNum | tail -n 1)"
	done

	#********************
	# Temp Supply        
	
	echo "bash ./tempData.sh $start_day $start_time $end_day $end_time $tempSupplyIEEE $tempSupplyValue $tempSupplyTable"
	bash ./tempData.sh $start_day $start_time $end_day $end_time $tempSupplyIEEE $tempSupplyValue $tempSupplyTable

	fileNum="$(ls ./data/ | grep temp.$start_day.$tempSupplyIEEE | wc -l)"
	
	supplyERROR=0
	if [ $fileNum == 0 ]; then
		echo "++++ cat ./data/temp.$start_day.$tempSupplyIEEE error ++++"
		supplyERROR=1
		supplyMin=0
		supplyMax=0
		supplyMedian=0
		supplyCount=0
	else
		#avgChwr minChwr maxChwr medChwr
		#avgChwr="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n 1 | tail -n 1)"
		supplyMin="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n 2 | tail -n 1)"
		supplyMax="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n 3 | tail -n 1)"
		supplyMedian="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n 4 | tail -n 1)"
		
		for i in {0..12};
		do
			num=$(($tempPer_head+$i))
			tempSupplyPer[i]="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n $num | tail -n 1)"
			#echo "${tempSupplyPer[i]}"
		done
		
		supplyCount="$(cat ./data/temp.$start_day.$tempSupplyIEEE | head -n 18 | tail -n 1)"
		rm ./data/temp.$start_day.$tempSupplyIEEE
	fi

	#*******************
	# Temp Return

	echo "bash ./tempData.sh $start_day $start_time $end_day $end_time $tempReturnIEEE $tempReturnValue $tempReturnTable"
	bash ./tempData.sh $start_day $start_time $end_day $end_time $tempReturnIEEE $tempReturnValue $tempReturnTable

	fileNum="$(ls ./data/ | grep temp.$start_day.$tempReturnIEEE | wc -l)"
	
	returnERROR=0
	
	if [ $fileNum == 0 ]; then
		echo "++++ cat temp.txt error ++++"
		returnMin=0
		returnMax=0
		returnMedian=0
		returnCount=0
		returnERROR=1
	else
		#avgChwr minChwr maxChwr medChwr
		#chitemp[4]="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n 1 | tail -n 1)"
		returnMin="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n 2 | tail -n 1)"
		returnMax="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n 3 | tail -n 1)"
		returnMedian="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n 4 | tail -n 1)"
		
		for i in {0..12};
		do
			num=$(($tempPer_head+$i))
			tempReturnPer[i]="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n $num | tail -n 1)"
			#echo "${tempReturnPer[i]}"
		done
		
		returnCount="$(cat ./data/temp.$start_day.$tempReturnIEEE | head -n 18 | tail -n 1)"
		rm ./data/temp.$start_day.$tempReturnIEEE
	fi
	
	#*******************
	# Temp Delta
	echo "bash ./tempDeltaCapacityCombinedFlow.sh $start_day $start_time $end_day $end_time $chillerIEEE $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable $flow1IEEE $flow1Table $flow2IEEE $flow2Table"
	bash ./tempDeltaCapacityCombinedFlow.sh $start_day $start_time $end_day $end_time $chillerIEEE $tempSupplyIEEE $tempSupplyValue $tempSupplyTable $tempReturnIEEE $tempReturnValue $tempReturnTable $flow1IEEE $flow1Table $flow2IEEE $flow2Table
	
	fileNum="$(ls ./data/ | grep Delta.$start_day.$chillerIEEE | wc -l)"
	
	deltaERROR=0
	if [ $fileNum == 0 ]; then
	
		echo "++++ cat ./data/Delta.$start_day.$chillerIEEE error ++++"
		
		cntDelta0=0
		cntDelta9=0
		cntDelta19=0
		cntDelta29=0
		cntDelta39=0
		cntDelta49=0
		cntDelta59=0
		cntDelta60=0

		deltaMin=0
		deltaMedian=0
		deltaMax=0

		capacity=0
		deltaCount=00
		
		deltaERROR=1
		
	else
	
		deltaCount="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 13 | tail -n 1)"
		
		cntDelta0="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 1 | tail -n 1)"
		cntDelta9="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 2 | tail -n 1)"
		cntDelta19="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 3 | tail -n 1)"
		cntDelta29="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 4 | tail -n 1)"
		cntDelta39="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 5 | tail -n 1)"
		cntDelta49="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 6 | tail -n 1)"
		cntDelta59="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 7 | tail -n 1)"
		cntDelta60="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 8 | tail -n 1)"
		
		deltaMin="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 9 | tail -n 1)"
		deltaMedian="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 10 | tail -n 1)"
		deltaMax="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 11 | tail -n 1)"
		
		capacity="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 12 | tail -n 1)"
		
		# capacityMin="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 12 | tail -n 1)"
		#Median
		# capacityMax="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 14 | tail -n 1)"
		
		# efficiencyMin="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 15 | tail -n 1)"
		# efficiencyMedian="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 16 | tail -n 1)"
		# efficiencyMax="$(cat ./data/Delta.$start_day.$chillerIEEE | head -n 17 | tail -n 1)"

		rm ./data/Delta.$start_day.$chillerIEEE
	fi

	echo "Flow Rate"
	echo "bash flowMedianCombined.sh $start_day $start_time $end_day $end_time $flow1IEEE $flow1Table $flow2IEEE $flow2Table"
	bash flowMedianCombined.sh $start_day $start_time $end_day $end_time $flow1IEEE $flow1Table $flow2IEEE $flow2Table
	
	fileNum="$(ls ./data/ | grep flowMedian.$start_day.$flow1IEEE | wc -l)"
	
	flowMedianERROR=0
	
	if [ $fileNum == 0 ]; then
	
		flowMedian=0
		flowMedianERROR=1
	else
		flowMedian="$(cat ./data/flowMedian.$start_day.$flow1IEEE | head -n 1 | tail -n 1)"
		rm ./data/flowMedian.$start_day.$flow1IEEE
	fi
	
	if [ $flowMedianERROR == 1 ] || [ $deltaERROR == 1 ] || [ $returnERROR == 1 ] || [ $supplyERROR == 1 ]; then
		echo "[ERROR]++++ [ $flowMedianERROR == 1 ] || [ $deltaERROR == 1 ] || [ $returnERROR == 1 ] || [ $supplyERROR == 1 ] ++++"
	fi
	
	echo "replace INTO dailyChillerData(
		operationDate,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerLoading,capacity,
		powerLoadingDataCounts
		) 
		VALUES(
		'$start_day','$gwId', '$chiId', '$chiname', '$start_day $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'$powerLoading','$capacity',
		'{\"level1\": ${chiPowerPer[0]}, 
		\"level2\": ${chiPowerPer[1]}, 
		\"level3\": ${chiPowerPer[2]}, 
		\"level4\": ${chiPowerPer[3]}, 
		\"level5\": ${chiPowerPer[4]}, 
		\"level6\": ${chiPowerPer[5]},
		\"level7\": ${chiPowerPer[6]},
		\"level8\": ${chiPowerPer[7]},
		\"level9\": ${chiPowerPer[8]},
		\"level10\": ${chiPowerPer[9]},
		\"level11\": ${chiPowerPer[10]}}'
		);
	"
	
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerData(
		operationDate,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,dataCount,totalPowerWh,operationFlag,powerConsumption,
		powerLoading,capacity,
		powerLoadingDataCounts
		) 
		VALUES(
		'$start_day','$gwId', '$chiId', '$chiname', '$start_day $start_time', '$end_day $end_time', 
		'$runMinutes','$dataCount', '$powerWh', '$flag','$powerConsumption',
		'$powerLoading','$capacity',
		'{\"level1\": ${chiPowerPer[0]}, 
		\"level2\": ${chiPowerPer[1]}, 
		\"level3\": ${chiPowerPer[2]}, 
		\"level4\": ${chiPowerPer[3]}, 
		\"level5\": ${chiPowerPer[4]}, 
		\"level6\": ${chiPowerPer[5]},
		\"level7\": ${chiPowerPer[6]},
		\"level8\": ${chiPowerPer[7]},
		\"level9\": ${chiPowerPer[8]},
		\"level10\": ${chiPowerPer[9]},
		\"level11\": ${chiPowerPer[10]}}'
		);
	"
	
	echo "replace INTO dailyChillerTemp(
		operationDate,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax,
		supplyDataCounts,
		returnDataCounts,
		deltaDataCounts
		) 
		VALUES(
		'$start_day','$gwId', '$chiId', '$chiname', '$start_day $start_time', '$end_day $end_time',
		'$runMinutes','$flag',
		'$supplyCount','$supplyMin','$supplyMedian','$supplyMax',
		'$returnCount','$returnMin','$returnMedian','$returnMax',
		'$deltaCount','$deltaMin','$deltaMedian','$deltaMax',
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
		  \"level13\": ${tempSupplyPer[12]}}',
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
		  \"level13\": ${tempReturnPer[12]}}',
		'{\"level1\": $cntDelta0, 
		  \"level2\": $cntDelta9, 
		  \"level3\": $cntDelta19, 
		  \"level4\": $cntDelta29, 
		  \"level5\": $cntDelta39, 
		  \"level6\": $cntDelta49,
		  \"level7\": $cntDelta59, 
		  \"level8\": $cntDelta60}'
		);
	"
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerTemp(
		operationDate,gatewayId,chillerId,chillerDescription,startTime,endTime,
		operationMinutes,operationFlag,
		supplyCount,supplyMin,supplyMedian,supplyMax,
		returnCount,returnMin,returnMedian,returnMax,
		deltaCount,deltaMin,deltaMedian,deltaMax,
		supplyDataCounts,
		returnDataCounts,
		deltaDataCounts
		) 
		VALUES(
		'$start_day','$gwId', '$chiId', '$chiname', '$start_day $start_time', '$end_day $end_time',
		'$runMinutes','$flag',
		'$supplyCount','$supplyMin','$supplyMedian','$supplyMax',
		'$returnCount','$returnMin','$returnMedian','$returnMax',
		'$deltaCount','$deltaMin','$deltaMedian','$deltaMax',
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
		  \"level13\": ${tempSupplyPer[12]}}',
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
		  \"level13\": ${tempReturnPer[12]}}',
		'{\"level1\": $cntDelta0, 
		  \"level2\": $cntDelta9, 
		  \"level3\": $cntDelta19, 
		  \"level4\": $cntDelta29, 
		  \"level5\": $cntDelta39, 
		  \"level6\": $cntDelta49,
		  \"level7\": $cntDelta59, 
		  \"level8\": $cntDelta60}'
		);
	"

	#Next Data
	time_num=$(($time_num-1))
	
	next_num=21

	start_day_head=$(($start_day_head+$next_num))
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

if [ -f "./data/chiller.$start_day.$chillerIEEE" ]; then
	rm ./data/chiller.$start_day.$chillerIEEE
fi

exit 0