#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00 gatewayId "
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"
dbRPF="reportplatform"

siteId=${1}
startDay=${2}
startTime=${3}

endDay=${4}
endTime=${5}

gatewayId=${6}
gId=${6}

ChillerFlowName="flow#5"
CoolingFlowName="flow#6"

today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbFlow="flow"
	
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbFlow="flow_$dbdataMonth"

fi

tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))
echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbFlow $ChillerFlowName $CoolingFlowName"
echo "*************************************************************************************************"

echo " "
echo "#*******************#"
echo "#Plant Flow Data HDR#"
echo "#*******************#"
echo " "

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/flowDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/flowDataHDR.$startDay.$gId.$whileHour
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/flowDataHDR.$startDay.$gId.$whileHour" ]; then
	rm ./buf/flowDataHDR.$startDay.$gId.$whileHour
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour" ]; then
	rm ./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour
fi

stHour=0
while :
do
	if [ $stHour == 24 ]; then
	 break
	fi
	
	echo "  Run Flow Data $stHour"
	
	stMin=0
	while :
	do
		if [ $stMin == 60 ]; then
			break
		elif [ $stMin == 59 ]; then
			endHour=$(($stHour+1))
			endMin=00
		else
			endHour=$stHour
			endMin=$(($stMin+1))
		fi
		
		#echo "$stHour:$stMin ~ $endHour:$endMin"

		flowTrue=0
		flowPlantTime=($(mysql -h ${host} -D$dbRPF -ss -e"
		SELECT 
			date_format(startTime, '%H %i') as startTime,
			date_format(endTime, '%H %i') as endTime 
		 FROM 
			 reportplatform.dailyChillerData
		 WHERE 
			 siteId=$siteId and 
			 operationDate='$startDay'and 
			 operationFlag=1;
		"))
		
		whileNum=0
		while :
		do
			if [ "${flowPlantTime[$whileNum]}" == "" ]; then
			 break
			fi
			
			runStartHour=${flowPlantTime[$whileNum]}
			runStartHour=$((10#$runStartHour))
			whileNum=$(($whileNum+1))
			
			runStartMin=${flowPlantTime[$whileNum]}
			runStartMin=$((10#$runStartMin))
			whileNum=$(($whileNum+1))
			
			runEndHour=${flowPlantTime[$whileNum]}
			runEndHour=$((10#$runEndHour))
			whileNum=$(($whileNum+1))
			
			runEndMin=${flowPlantTime[$whileNum]}
			runEndMin=$((10#$runEndMin))
			whileNum=$(($whileNum+1))
			
			if [ $stHour -gt $runStartHour ]; then
			
				if [ $endHour -lt $runEndHour ]; then
					flowTrue=1
				elif [ $endHour == $runEndHour ]; then
					if [ $endMin -le $runEndMin ]; then
						flowTrue=1
					fi
				fi
			elif [ $stHour == $runStartHour ]; then
			
				if [ $stMin -ge $runStartMin ]; then
					if [ $endHour -lt $runEndHour ]; then
						flowTrue=1
					elif [ $endHour == $runEndHour ]; then
						if [ $endMin -le $runEndMin ]; then
							flowTrue=1
						fi
					fi
				fi
			fi
		done
	
		
		if [ $flowTrue == 1 ]; then
			#echo " $stHour:$stMin ~ $endHour:$endMin || $runStartHour $runStartMin $runEndHour $runEndMin"

			flowData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT truncate(flowRate,2)
				 FROM 
					$tbFlow 
				 WHERE 
					siteId='$siteId' and
					name='$ChillerFlowName' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin'
					order by flowRate asc
			"))
			
			if [ "$flowData" != "" ]; then
			  echo "$flowData" >> ./buf/flowDataHDR.$startDay.$gId
			  echo "$flowData" >> ./buf/flowDataHDR.$startDay.$gId.$stHour
			else
			  echo " $stHour:$stMin ~ $endHour:$endMin || $runStartHour $runStartMin $runEndHour $runEndMin no data:$flowData"
			fi

			
			CoolingFlowData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT 
					truncate(flowRate,2)
				 FROM 
					$tbFlow 
				 WHERE 
					siteId='$siteId' and
					name='$CoolingFlowName' and 
					ts >= '$startDay $stHour:$stMin' and 
					ts <= '$startDay $endHour:$endMin'
					order by flowRate asc
			"))
			
			if [ "$CoolingFlowData" != "" ]; then
				echo "$CoolingFlowData" >> ./buf/CoolingFlowDataHDR.$startDay.$gId
				echo "$CoolingFlowData" >> ./buf/CoolingFlowDataHDR.$startDay.$gId.$stHour
			else
			  echo " $stHour:$stMin ~ $endHour:$endMin || $runStartHour $runStartMin $runEndHour $runEndMin no data:$CoolingFlowData"
			fi

			flowTrue=0
		fi
		
		stMin=$(($stMin+1))
	done
	
	stHour=$(($stHour+1))
done

echo "  Run Flow Data HDR Min Median Max"	
if [ -f "./buf/flowDataHDR.$startDay.$gId" ]; then

	flowCountNum="$(cat ./buf/flowDataHDR.$startDay.$gId |wc -l)"

	if [ $flowCountNum == 0 ]; then

		flowMin=NULL
		flowMedian=NULL
		flowMax=NULL
		
	elif [ $flowCountNum == 1 ]; then

		sort -n ./buf/flowDataHDR.$startDay.$gId > ./buf/flowDataHDR.$startDay.$gId.Sort
		rm ./buf/flowDataHDR.$startDay.$gId
		
		flowMin="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		flowMedian="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		flowMax="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/flowDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/flowDataHDR.$startDay.$gId > ./buf/flowDataHDR.$startDay.$gId.Sort
		rm ./buf/flowDataHDR.$startDay.$gId
				
		echo "scale=0;$(($flowCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] flowCountNum FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($flowCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] flowCountNum ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($flowCountNum/2))
		
		flowMin="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		flowMedian="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		flowMax="$(cat ./buf/flowDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/flowDataHDR.$startDay.$gId.Sort
	fi
else
	flowMin=NULL
	flowMedian=NULL
	flowMax=NULL
fi


echo "  Run Flow Data"
whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/flowDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/flowDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/flowDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalFlow=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/flowDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalFlow+$tempData"
			echo "scale=3;$dataTotalFlow+$tempData"|bc > ./buf/dataTotalFlow.$startDay.$gId
			
			dataTotalFlow="$(cat ./buf/dataTotalFlow.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalFlow/$countNum"|bc > ./buf/dataTotalFlow.$startDay.$gId
			
		dataTotalFlow="$(cat ./buf/dataTotalFlow.$startDay.$gId | head -n 1 | tail -n 1)"
		echo " $dataTotalFlow"

		rm ./buf/flowDataHDR.$startDay.$gId.$whileHour

	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/flowDataJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))
 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalFlow >> ./buf/flowDataJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

flowDataERROR=0
if [ -f "./buf/flowDataJson.$startDay.$gId" ]; then
	flowData="$(cat ./buf/flowDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/flowDataJson.$startDay.$gId
else
	flowDataERROR=1
fi


echo "  Run Cooling Flow Data HDR Min Median Max"	
if [ -f "./buf/CoolingFlowDataHDR.$startDay.$gId" ]; then

	CoolingFlowCountNum="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId |wc -l)"

	if [ $CoolingFlowCountNum == 0 ]; then

		CoolingFlowMin=NULL
		CoolingFlowMedian=NULL
		CoolingFlowMax=NULL
		
	elif [ $CoolingFlowCountNum == 1 ]; then

		sort -n ./buf/CoolingFlowDataHDR.$startDay.$gId > ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort
		rm ./buf/CoolingFlowDataHDR.$startDay.$gId
		
		CoolingFlowMin="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		CoolingFlowMedian="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		CoolingFlowMax="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/CoolingFlowDataHDR.$startDay.$gId > ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort
		rm ./buf/CoolingFlowDataHDR.$startDay.$gId
		
		echo "scale=0;$(($CoolingFlowCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] CoolingFlowCountNum FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($CoolingFlowCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] CoolingFlowCountNum ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($CoolingFlowCountNum/2))
		
		CoolingFlowMin="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		CoolingFlowMedian="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		CoolingFlowMax="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/CoolingFlowDataHDR.$startDay.$gId.Sort
	fi
else
	CoolingFlowMin=NULL
	CoolingFlowMedian=NULL
	CoolingFlowMax=NULL
fi

echo "  Run Cooling Flow Data"

whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalFlow=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalFlow+$tempData"
			echo "scale=3;$dataTotalFlow+$tempData"|bc > ./buf/dataTotalFlow.$startDay.$gId
			
			dataTotalFlow="$(cat ./buf/dataTotalFlow.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalFlow/$countNum"|bc > ./buf/dataTotalFlow.$startDay.$gId
			
		dataTotalFlow="$(cat ./buf/dataTotalFlow.$startDay.$gId | head -n 1 | tail -n 1)"
		echo " $dataTotalFlow"

		rm ./buf/CoolingFlowDataHDR.$startDay.$gId.$whileHour

	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/CoolingFlowDataJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalFlow >> ./buf/CoolingFlowDataJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

CoolingFlowDataERROR=0
if [ -f "./buf/CoolingFlowDataJson.$startDay.$gId" ]; then
	CoolingFlowData="$(cat ./buf/CoolingFlowDataJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/CoolingFlowDataJson.$startDay.$gId
else
	CoolingFlowDataERROR=1
fi

echo "REPlACE INTO dailyPlantFlow(operationDate,siteId,gatewayId,
	chillerFlowRateMin,chillerFlowRateMedian,chillerFlowRateMax,
	CoolingFlowRateMin,CoolingFlowRateMedian,CoolingFlowRateMax,
	chillerFlowRateData,
	CoolingFlowRateData) 
VALUES('$startDay','$siteId','$gId',
	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax'),
	if($CoolingFlowMin is NULL,NULL,'$CoolingFlowMin'),
	if($CoolingFlowMedian is NULL,NULL,'$CoolingFlowMedian'),
	if($CoolingFlowMax is NULL,NULL,'$CoolingFlowMax'),
	if($flowDataERROR=1,NULL,'{$flowData}'),
	if($CoolingFlowDataERROR=1,NULL,'{$CoolingFlowData}'))
;
"

mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyPlantFlow(operationDate,siteId,gatewayId,
	chillerFlowRateMin,chillerFlowRateMedian,chillerFlowRateMax,
	CoolingFlowRateMin,CoolingFlowRateMedian,CoolingFlowRateMax,
	chillerFlowRateData,
	CoolingFlowRateData) 
VALUES('$startDay','$siteId','$gId',
	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax'),
	if($CoolingFlowMin is NULL,NULL,'$CoolingFlowMin'),
	if($CoolingFlowMedian is NULL,NULL,'$CoolingFlowMedian'),
	if($CoolingFlowMax is NULL,NULL,'$CoolingFlowMax'),
	if($flowDataERROR=1,NULL,'{$flowData}'),
	if($CoolingFlowDataERROR=1,NULL,'{$CoolingFlowData}'))
;
"
exit 0