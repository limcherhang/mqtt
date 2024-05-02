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
	select tempSupply,tempReturn,IFNULL(Round(tempReturn-tempSupply,2),0) as delta
	from
	(
	SELECT date_format(b.ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
	  FROM 
			$dbProcess.$tbChiller as a,
			$tbTemp as b
		WHERE 
			a.siteId=47 and
			a.name='CTP#Plant' and
			b.name='temp#1' and 
			opFlag=1 and
			b.ts >='$startDay $startTime' and 
			b.ts <'$endDay $endTime'and
			a.siteId = b.siteId and
			a.ts = b.ts
	) as a

	INNER join
	(
	SELECT date_format(b.ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn
		FROM 
			$dbProcess.$tbChiller as a,
			$tbTemp as b
		WHERE
			a.siteId=47 and
			a.name='CTP#Plant' and
			b.name='temp#2' and 
			opFlag=1 and
			b.ts >='$startDay $startTime' and 
			b.ts <'$endDay $endTime'and
			a.siteId = b.siteId and
			a.ts = b.ts
	) as b
	on a.time=b.time;
"))
if [ -f "./buf/tempSupply" ]; then
	rm ./buf/tempSupply
fi

if [ -f "./buf/tempReturn" ]; then
	rm ./buf/tempReturn
fi

if [ -f "./buf/tempDelta" ]; then
	rm ./buf/tempDelta
fi

whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi

	tempSupply=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	tempReturn=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	tempDelta=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	echo "[DEBUG]Supply  $tempSupply Return $tempReturn Delta $tempDelta"
	
	if [ "$tempSupply" != "NULL" ]; then
		echo "$tempSupply" >> ./buf/tempSupply
	fi
	
	if [ "$tempReturn" != "NULL" ]; then
		echo "$tempReturn" >> ./buf/tempReturn
	fi	
	
	if [ "$tempDelta" != "NULL" ]; then
		echo "$tempDelta" >> ./buf/tempDelta
	fi
done
if [ -f "./buf/tempSupply" ]; then

	countNum="$(cat ./buf/tempSupply |wc -l)"

	if [ $countNum == 0 ]; then

		tempSupplyMin=NULL
		tempSupplyMedian=NULL
		tempSupplyMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/tempSupply > ./buf/tempSupply.Sort
		rm ./buf/tempSupply
		
		tempSupplyMin="$(cat ./buf/tempSupply.Sort | head -n 1 | tail -n 1)" 
		tempSupplyMedian="$(cat ./buf/tempSupply.Sort | head -n 1 | tail -n 1)" 
		tempSupplyMax="$(cat ./buf/tempSupply.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/tempSupply.Sort
	else

		sort -n ./buf/tempSupply > ./buf/tempSupply.Sort
		rm ./buf/tempSupply
		
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
		
		tempSupplyMin="$(cat ./buf/tempSupply.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		tempSupplyMedian="$(cat ./buf/tempSupply.Sort  | head -n $medianNum | tail -n 1)" 
		tempSupplyMax="$(cat ./buf/tempSupply.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/tempSupply.Sort
	fi
else
	tempSupplyMin=NULL
	tempSupplyMedian=NULL
	tempSupplyMax=NULL
fi

echo "Temp Supply $tempSupplyMin $tempSupplyMedian $tempSupplyMax"

if [ -f "./buf/tempReturn" ]; then

	countNum="$(cat ./buf/tempReturn |wc -l)"

	if [ $countNum == 0 ]; then

		tempReturnMin=NULL
		tempReturnMedian=NULL
		tempReturnMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/tempReturn > ./buf/tempReturn.Sort
		rm ./buf/tempReturn
		
		tempReturnMin="$(cat ./buf/tempReturn.Sort | head -n 1 | tail -n 1)" 
		tempReturnMedian="$(cat ./buf/tempReturn.Sort | head -n 1 | tail -n 1)" 
		tempReturnMax="$(cat ./buf/tempReturn.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/tempReturn.Sort
	else

		sort -n ./buf/tempReturn > ./buf/tempReturn.Sort
		rm ./buf/tempReturn
		
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
		
		tempReturnMin="$(cat ./buf/tempReturn.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		tempReturnMedian="$(cat ./buf/tempReturn.Sort  | head -n $medianNum | tail -n 1)" 
		tempReturnMax="$(cat ./buf/tempReturn.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/tempReturn.Sort
	fi
else
	tempReturnMin=NULL
	tempReturnMedian=NULL
	tempReturnMax=NULL
fi

echo "Temp Return $tempReturnMin $tempReturnMedian $tempReturnMax"

if [ -f "./buf/tempDelta" ]; then

	countNum="$(cat ./buf/tempDelta |wc -l)"

	if [ $countNum == 0 ]; then

		tempDeltaMin=NULL
		tempDeltaMedian=NULL
		tempDeltaMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/tempDelta > ./buf/tempDelta.Sort
		rm ./buf/tempDelta
		
		tempDeltaMin="$(cat ./buf/tempDelta.Sort | head -n 1 | tail -n 1)" 
		tempDeltaMedian="$(cat ./buf/tempDelta.Sort | head -n 1 | tail -n 1)" 
		tempDeltaMax="$(cat ./buf/tempDelta.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/tempDelta.Sort
	else

		sort -n ./buf/tempDelta > ./buf/tempDelta.Sort
		rm ./buf/tempDelta
		
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
		
		tempDeltaMin="$(cat ./buf/tempDelta.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		tempDeltaMedian="$(cat ./buf/tempDelta.Sort  | head -n $medianNum | tail -n 1)" 
		tempDeltaMax="$(cat ./buf/tempDelta.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/tempDelta.Sort
	fi
else
	tempDeltaMin=NULL
	tempDeltaMedian=NULL
	tempDeltaMax=NULL
fi

echo "Temp Delta $tempDeltaMin $tempDeltaMedian $tempDeltaMax"


echo "REPlACE INTO dailyPlantWaterTemp(operationDate,siteId,gatewayId,
	coolingReturnMin,coolingReturnMedian,coolingReturnMax,
	coolingSupplyMin,coolingSupplyMedian,coolingSupplyMax,
	coolingDeltaMin,coolingDeltaMedian,coolingDeltaMax) 
VALUES('$startDay','$siteId','$gId',
	if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
	if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
	if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
	if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
	if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
	if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
	if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
	if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
	if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantWaterTemp(operationDate,siteId,gatewayId,
	coolingReturnMin,coolingReturnMedian,coolingReturnMax,
	coolingSupplyMin,coolingSupplyMedian,coolingSupplyMax,
	coolingDeltaMin,coolingDeltaMedian,coolingDeltaMax) 
VALUES('$startDay','$siteId','$gId',
	if($tempReturnMin is NULL,NULL,'$tempReturnMin'),
	if($tempReturnMedian is NULL,NULL,'$tempReturnMedian'),
	if($tempReturnMax is NULL,NULL,'$tempReturnMax'),
	if($tempSupplyMin is NULL,NULL,'$tempSupplyMin'),
	if($tempSupplyMedian is NULL,NULL,'$tempSupplyMedian'),
	if($tempSupplyMax is NULL,NULL,'$tempSupplyMax'),
	if($tempDeltaMin is NULL,NULL,'$tempDeltaMin'),
	if($tempDeltaMedian is NULL,NULL,'$tempDeltaMedian'),
	if($tempDeltaMax is NULL,NULL,'$tempDeltaMax')
);
"
exit 0
