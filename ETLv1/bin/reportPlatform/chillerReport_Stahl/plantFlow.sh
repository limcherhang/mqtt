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
dbRPF2021="reportPlatform2021"

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
	tbFlow="flow"
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"
	tbFlow="flow_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"
fi

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

#value defined
totalEnergyConsumption=0
totalRunMinutes=0
dataKWCount=0
dataKWTotal=0
powerLoading=0
avgPowerLoading=NULL

FirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
ThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))


echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp"
echo "*************************************************************************************************"

echo " "
echo "#**********#"
echo "#Plant Temp#"
echo "#**********#"
echo " "

rawData=($(mysql -h ${host} -D$dbPlatform -ss -e"
	SELECT flowRate
	FROM 
	   $dbProcess.$tbChiller as a,
	   $tbFlow as b
	where 
	a.siteId=$siteId and
    a.name='chiller#Plant' and
	a.ts >='$startDay $startTime' and 
	a.ts <'$endDay $endTime'and
    opFlag=1 and
	a.siteId=b.siteId and
	a.ts=b.ts and 
	b.name ='flow#1'
    group by b.ts;
"))
if [ -f "./buf/flowRate" ]; then
	rm ./buf/flowRate
fi


whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi

	flowRate=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	

	echo "[DEBUG]flowRate  $flowRate "
	
	if [ "$flowRate" != "NULL" ]; then
		echo "$flowRate" >> ./buf/flowRate
	fi
	
done
if [ -f "./buf/flowRate" ]; then

	countNum="$(cat ./buf/flowRate |wc -l)"

	if [ $countNum == 0 ]; then

		flowRateMin=NULL
		flowRateMedian=NULL
		flowRateMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/flowRate > ./buf/flowRate.Sort
		rm ./buf/flowRate
		
		flowRateMin="$(cat ./buf/flowRate.Sort | head -n 1 | tail -n 1)" 
		flowRateMedian="$(cat ./buf/flowRate.Sort | head -n 1 | tail -n 1)" 
		flowRateMax="$(cat ./buf/flowRate.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/flowRate.Sort
	else

		sort -n ./buf/flowRate > ./buf/flowRate.Sort
		rm ./buf/flowRate
		
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
		
		flowRateMin="$(cat ./buf/flowRate.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		flowRateMedian="$(cat ./buf/flowRate.Sort  | head -n $medianNum | tail -n 1)" 
		flowRateMax="$(cat ./buf/flowRate.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/flowRate.Sort
	fi
else
	flowRateMin=NULL
	flowRateMedian=NULL
	flowRateMax=NULL
fi

echo "Flow Rate $flowRateMin $flowRateMedian $flowRateMax"

echo "REPlACE INTO dailyPlantFlow(operationDate,siteId,gatewayId,
	CoolingFlowRateMin,CoolingFlowRateMedian,CoolingFlowRateMax) 
VALUES('$startDay','$siteId','$gId',
	if($flowRateMin is NULL,NULL,'$flowRateMin'),
	if($flowRateMedian is NULL,NULL,'$flowRateMedian'),
	if($flowRateMax is NULL,NULL,'$flowRateMax')
;
"

mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyPlantFlow(operationDate,siteId,gatewayId,
	CoolingFlowRateMin,CoolingFlowRateMedian,CoolingFlowRateMax) 
VALUES('$startDay','$siteId','$gId',
	if($flowRateMin is NULL,NULL,'$flowRateMin'),
	if($flowRateMedian is NULL,NULL,'$flowRateMedian'),
	if($flowRateMax is NULL,NULL,'$flowRateMax'))
;
"
exit 0
