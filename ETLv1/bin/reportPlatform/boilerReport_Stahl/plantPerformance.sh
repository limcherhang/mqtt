#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00"
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

today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbTemp="temp"
	dbProcess="processETL"
	tbChiller="chiller"
	tbBoiler="boiler"
	
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"
	tbBoiler="boiler_$dbdataMonth" 
fi

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

FirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
ThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))


chillerNameList=("NULL" "power#7")

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

if [ -f "./buf/COP" ]; then
	rm ./buf/COP
fi

rawData=($(mysql -h ${host} -D$dbProcess -ss -e"
	SELECT 
		date_format(ts, '%H') as hours,COP 
	FROM 
	   $tbBoiler
	where 
	siteId=$siteId and
    name='boiler#Plant' and
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
	
	hours=${rawData[$whileNum]}
	hours=$((10#$hours))
	whileNum=$(($whileNum+1))
	
	COP=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	

	#echo "[DEBUG]Hours:$hours COP $COP "

	if [ "$COP" != "NULL" ]; then
		echo "$COP" >> ./buf/COP
	fi

done


if [ -f "./buf/COP" ]; then

	countNum="$(cat ./buf/COP |wc -l)"

	if [ $countNum == 0 ]; then

		COPMin=NULL
		COPMedian=NULL
		COPMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/COP > ./buf/COP.Sort
		rm ./buf/COP
		
		COPMin="$(cat ./buf/COP.Sort | head -n 1 | tail -n 1)" 
		COPMedian="$(cat ./buf/COP.Sort | head -n 1 | tail -n 1)" 
		COPMax="$(cat ./buf/COP.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/COP.Sort
	else

		sort -n ./buf/COP > ./buf/COP.Sort
		rm ./buf/COP
		
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
		
		COPMin="$(cat ./buf/COP.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		COPMedian="$(cat ./buf/COP.Sort  | head -n $medianNum | tail -n 1)" 
		COPMax="$(cat ./buf/COP.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/COP.Sort
	fi
else
	COPMin=NULL
	COPMedian=NULL
	COPMax=NULL
fi

echo "$COPMin $COPMedian $COPMax"

rawData=($(mysql -h ${host} -D$dbPlatform -ss -e"
	SELECT powerConsumed FROM 
      $tbPower
   where 
   siteId=$siteId and 
   name='power#4' and 
   ts >'$startDay $startTime' and 
   ts <' $endDay $endTime' and 
   powerConsumed>1;
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


echo "REPlACE INTO dailyPlantBoiler(operationDate,siteId,
	COPMin,COPMedian,COPMax,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId',
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax'),
	if($COPMin is NULL,NULL,'$COPMin'),
	if($COPMedian is NULL,NULL,'$COPMedian'),
	if($COPMax is NULL,NULL,'$COPMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyPlantBoiler(operationDate,siteId,
	COPMin,COPMedian,COPMax,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId',
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax'),
	if($COPMin is NULL,NULL,'$COPMin'),
	if($COPMedian is NULL,NULL,'$COPMedian'),
	if($COPMax is NULL,NULL,'$COPMax')
);
"

exit 0