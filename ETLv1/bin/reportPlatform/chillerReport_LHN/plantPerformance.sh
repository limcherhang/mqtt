#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00 gatewayId"
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


today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbTemp="temp"
	dbProcess="processETL"
	tbChiller="chiller"
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"
fi

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

FirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
ThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp"
echo "*************************************************************************************************"

echo " "
echo "#***********************#"
echo "#Daily Plant Performance#"
echo "#***********************#"
echo " "

if [ -f "./buf/kW" ]; then
	rm ./buf/kW
fi

if [ -f "./buf/coolingCapacity" ]; then
	rm ./buf/coolingCapacity
fi

if [ -f "./buf/efficiency" ]; then
	rm ./buf/efficiency
fi

rawData=($(mysql -h ${host} -D$dbProcess -ss -e"
	SELECT coolingCapacity,efficiency 
	FROM 
	   $tbChiller
	where 
	siteId=47 and
    name='CTP#Plant' and
	ts >= '$startDay $startTime ' and 
    ts <= '$endDay $endTime' and
    opFlag=1;
"))

whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi

	coolingCapacity=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	efficiency=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	#echo "[DEBUG]kWatt coolingCapacity $coolingCapacity efficiency $efficiency"

	if [ "$coolingCapacity" != "NULL" ]; then
		echo "$coolingCapacity" >> ./buf/coolingCapacity
	fi

	if [ "$efficiency" != "NULL" ]; then
		echo "$efficiency" >> ./buf/efficiency
	fi
done

if [ -f "./buf/coolingCapacity" ]; then

	countNum="$(cat ./buf/coolingCapacity |wc -l)"

	if [ $countNum == 0 ]; then

		coolingCapacityMin=NULL
		coolingCapacityMedian=NULL
		coolingCapacityMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/coolingCapacity > ./buf/coolingCapacity.Sort
		rm ./buf/coolingCapacity
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingCapacity.Sort
	else

		sort -n ./buf/coolingCapacity > ./buf/coolingCapacity.Sort
		rm ./buf/coolingCapacity
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.Sort  | head -n $medianNum | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingCapacity.Sort
	fi
else
	coolingCapacityMin=NULL
	coolingCapacityMedian=NULL
	coolingCapacityMax=NULL
fi

echo "$coolingCapacityMin $coolingCapacityMedian $coolingCapacityMax"

if [ -f "./buf/efficiency" ]; then

	countNum="$(cat ./buf/efficiency |wc -l)"

	if [ $countNum == 0 ]; then

		Min=NULL
		Median=NULL
		Max=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/efficiency > ./buf/efficiency.Sort
		rm ./buf/efficiency
		
		Min="$(cat ./buf/efficiency.Sort | head -n 1 | tail -n 1)" 
		Median="$(cat ./buf/efficiency.Sort | head -n 1 | tail -n 1)" 
		Max="$(cat ./buf/efficiency.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/efficiency.Sort
	else

		sort -n ./buf/efficiency > ./buf/efficiency.Sort
		rm ./buf/efficiency
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		Min="$(cat ./buf/efficiency.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		Median="$(cat ./buf/efficiency.Sort  | head -n $medianNum | tail -n 1)" 
		Max="$(cat ./buf/efficiency.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/efficiency.Sort
	fi
else
	Min=NULL
	Median=NULL
	Max=NULL
fi

efficiencyMin=$Min
efficiencyMedian=$Median
efficiencyMax=$Max

echo "efficiency $Min $Median $Max"

rawData=($(mysql -h ${host} -D$dbPlatform -ss -e"
	SELECT round(sum(powerConsumed),3)
	FROM 
	   $dbProcess.$tbChiller as a,
	   $tbPower as b
	where 
	a.siteId=47 and
    a.name='CTP#Plant' and
	a.ts >= '$startDay $startTime ' and 
    a.ts <= '$endDay $endTime' and
    opFlag=1 and
	a.siteId=b.siteId and
	a.ts=b.ts and 
	b.name in ('power#1','power#2','power#3','power#4','power#5','power#6','power#7','power#8','power#9','power#10')
    group by b.ts;
"))
whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi

	kWatt=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	#echo "[DEBUG]kWatt  $kWatt"
	
	if [ "$kWatt" != "NULL" ]; then
		
		echo "$kWatt" >> ./buf/kW
	fi

done

if [ -f "./buf/kW" ]; then

	countNum="$(cat ./buf/kW |wc -l)"

	if [ $countNum == 0 ]; then

		kWattMin=NULL
		kWattMedian=NULL
		kWattMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/kW > ./buf/kW.Sort
		rm ./buf/kW
		
		kWattMin="$(cat ./buf/kW.Sort | head -n 1 | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.Sort | head -n 1 | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/kW.Sort
	else

		sort -n ./buf/kW > ./buf/kW.Sort
		rm ./buf/kW
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		#echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		#echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		kWattMin="$(cat ./buf/kW.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.Sort  | head -n $medianNum | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/kW.Sort
	fi
else
	kWattMin=NULL
	kWattMedian=NULL
	kWattMax=NULL
fi

echo "k Watt $kWattMin $kWattMedian $kWattMax"

echo "REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId','$gatewayId',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId','$gatewayId',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax')
);
"


exit 0