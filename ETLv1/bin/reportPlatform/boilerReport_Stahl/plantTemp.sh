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
tempName=${7} #temp#5

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

FirstQuatile=25
ThirdQuatile=75

echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp"
echo "*************************************************************************************************"

echo " "
echo "#**********#"
echo "#Plant Temp#"
echo "#**********#"
echo " "



if [ -f "./buf/temp" ]; then
	rm ./buf/temp
fi

rawData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT temp FROM 
      $tbPower as a,
      $tbTemp as b
   where 
   a.ts=b.ts and 
   a.siteId=b.siteId and
   a.siteId=$siteId and 
   a.name='$powerName' and 
   b.name='$tempName' and 
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

	temp=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	#echo "[DEBUG]temp  $temp"
	
	if [ "$temp" != "NULL" ]; then
		
		echo "$temp" >> ./buf/temp
	fi

done

if [ -f "./buf/temp" ]; then

	countNum="$(cat ./buf/temp |wc -l)"

	if [ $countNum == 0 ]; then

		tempMin=NULL
		tempMedian=NULL
		tempMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/temp > ./buf/temp.Sort
		rm ./buf/temp
		
		tempMin="$(cat ./buf/temp.Sort | head -n 1 | tail -n 1)" 
		tempMedian="$(cat ./buf/temp.Sort | head -n 1 | tail -n 1)" 
		tempMax="$(cat ./buf/temp.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/temp.Sort
	else

		sort -n ./buf/temp > ./buf/temp.Sort
		rm ./buf/temp
		
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
		
		tempMin="$(cat ./buf/temp.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		tempMedian="$(cat ./buf/temp.Sort  | head -n $medianNum | tail -n 1)" 
		tempMax="$(cat ./buf/temp.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/temp.Sort
	fi
else
	tempMin=NULL
	tempMedian=NULL
	tempMax=NULL
fi

echo "$tempMin $tempMedian $tempMax"


echo "REPlACE INTO dailyPlantBoilerTemp(operationDate,siteId,name,
	firstQuartile,median,thirdQuartile) 
VALUES('$startDay','$siteId','$tempName',
	if($tempMin is NULL,NULL,'$tempMin'),
	if($tempMedian is NULL,NULL,'$tempMedian'),
	if($tempMax is NULL,NULL,'$tempMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantBoilerTemp(operationDate,siteId,name,
	firstQuartile,median,thirdQuartile) 
VALUES('$startDay','$siteId','$tempName',
	if($tempMin is NULL,NULL,'$tempMin'),
	if($tempMedian is NULL,NULL,'$tempMedian'),
	if($tempMax is NULL,NULL,'$tempMax')
);
"
exit 0
