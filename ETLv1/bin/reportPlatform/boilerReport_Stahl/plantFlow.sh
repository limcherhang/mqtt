#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00 powerName tempName "
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"
dbRPF="reportplatform"
dbData="reportplatform"

siteId=${1}

startDay=${2}
startTime=${3}

endDay=${4}
endTime=${5}

powerName=${6} #Power#4
flowName=${7} #flow#2

today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbTemp="temp"
	tbFlow="flow"
	dbProcess="processETL"
	tbChiller="chiller"
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

FirstQuatile=25
ThirdQuatile=75

echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbFlow"
echo "*************************************************************************************************"

echo " "
echo "#**********#"
echo "#Plant Flow#"
echo "#**********#"
echo " "



if [ -f "./buf/flow" ]; then
	rm ./buf/flow
fi

rawData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT flowRate FROM 
      $tbPower as a,
      $tbFlow as b
   where 
   a.ts=b.ts and 
   a.siteId=b.siteId and
   a.siteId=$siteId and 
   a.name='$powerName' and 
   b.name='$flowName' and 
   a.ts >'$startDay $startTime' and 
   a.ts <' $endDay $endTime' and 
   powerConsumed>1;
"))
	
whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi

	flow=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	#echo "[DEBUG]flow  $flow"
	
	if [ "$flow" != "NULL" ]; then
		
		echo "$flow" >> ./buf/flow
	fi

done

if [ -f "./buf/flow" ]; then

	countNum="$(cat ./buf/flow |wc -l)"

	if [ $countNum == 0 ]; then

		flowMin=NULL
		flowMedian=NULL
		flowMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/flow > ./buf/flow.Sort
		rm ./buf/flow
		
		flowMin="$(cat ./buf/flow.Sort | head -n 1 | tail -n 1)" 
		flowMedian="$(cat ./buf/flow.Sort | head -n 1 | tail -n 1)" 
		flowMax="$(cat ./buf/flow.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/flow.Sort
	else

		sort -n ./buf/flow > ./buf/flow.Sort
		rm ./buf/flow
		
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
		
		flowMin="$(cat ./buf/flow.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		flowMedian="$(cat ./buf/flow.Sort  | head -n $medianNum | tail -n 1)" 
		flowMax="$(cat ./buf/flow.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/flow.Sort
	fi
else
	flowMin=NULL
	flowMedian=NULL
	flowMax=NULL
fi

echo "$flowMin $flowMedian $flowMax"


echo "REPlACE INTO dailyPlantBoilerFlow(operationDate,siteId,name,
	firstQuartile,median,thirdQuartile) 
VALUES('$startDay','$siteId','$flowName',
	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantBoilerFlow(operationDate,siteId,name,
	firstQuartile,median,thirdQuartile) 
VALUES('$startDay','$siteId','$flowName',
	if($flowMin is NULL,NULL,'$flowMin'),
	if($flowMedian is NULL,NULL,'$flowMedian'),
	if($flowMax is NULL,NULL,'$flowMax')
);
"
exit 0
