#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入 "
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
		echo " 		chiler IEEEaddr"
		echo "		supply IEEEaddr"
		echo "		supply temp value"
		echo "		supply temp table"
		echo "		return IEEEaddr"
		echo "		return temp value"
		echo "		return temp table"
		echo "		flow IEEEaddr"
		echo "		flow table"
        exit 1
fi

if [ "${7}" == "" ] || [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ] || [ "${11}" == "" ] || [ "${12}" == "" ] || [ "${13}" == "" ] || [ "${14}" == "" ]; then
        echo "請輸入 "
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
		echo " 		chiler IEEEaddr"
		echo "		supply IEEEaddr"
		echo "		supply temp value"
		echo "		supply temp table"
		echo "		return IEEEaddr"
		echo "		return temp value"
		echo "		return temp table"
		echo "		flow IEEEaddr"
		echo "		flow table"
        exit 1
fi

dbRPF="reportplatform"

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

chiIEEE=${5}

supplyIEEE=${6}
supplyValue=${7}
supplyTable=${8}

returnIEEE=${9}
returnValue=${10}
returnTable=${11}

flowIEEE=${12}
flowTable=${13}


host="127.0.0.1"
today=$(date "+%Y-%m-%d" --date="-1 day")

gwId=${14}
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM gateway_info where gatewayId=$gwId;"))
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

if [ -f "./data/Delta.$startDay.$chiIEEE" ]; then
	echo "  rm ./data/Delta.$startDay.$chiIEEE"
	rm ./data/Delta.$startDay.$chiIEEE
fi

if [ -f "./buf/DeltaData.$startDay.$chiIEEE" ]; then
	echo "  rm ./buf/DeltaData.$startDay.$chiIEEE"
	rm ./buf/DeltaData.$startDay.$chiIEEE
fi

if [ -f "./buf/Capacity.$startDay.$chiIEEE" ]; then
	echo "  rm ./buf/Capacity.$startDay.$chiIEEE"
	rm ./buf/Capacity.$startDay.$chiIEEE
fi

if [ $startDay == $today ]; then
	dbdata="iotmgmt"
	
	pmTable=pm
	supplyTable=${8}
	returnTable=${11}
	flowTable=${13}
else
	#dbdata="iotdata"
	
	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	pmTable=pm_$dbdataMonth
	supplyTable=${8}_$dbdataMonth
	returnTable=${11}_$dbdataMonth
	flowTable=${13}_$dbdataMonth
	
	dbdata="iotdata$dbdataYear"
fi

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata pmTable=$pmTable supplyTable=$supplyTable returnTable=$returnTable flowTable=$flowTable"

if [ $flowIEEE == 0 ] || [ $flowTable == 0 ] ; then

	echo "  flowIEEE is $flowIEEE & flowTable is $flowTable"
	
	delta_data=($(mysql -h ${host} -D$dbdata -ss -e"select Round((Round(tempReturn-tempSupply,2))*100,0) as delta
	from
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($supplyValue,2) as tempSupply
	  FROM  $supplyTable
		 WHERE 
		  ieee='$supplyIEEE' and 
		  receivedSync>='$startDay $startTime' and 
		  receivedSync<='$endDay $endTime:59' and 
		  $supplyValue >= 0 and
		  $supplyValue is not NULL
		GROUP BY time
	) as a
	INNER join
	(
	  SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($returnValue,2) as tempReturn 
	   FROM $returnTable 
		WHERE 
		 ieee='$returnIEEE' and 
		 receivedSync>='$startDay $startTime' and 
		 receivedSync<='$endDay $endTime:59' and 
		 $returnValue >=0 and
		 $returnValue is not NULL 
		GROUP BY time
	) as b
	on a.time=b.time
	order by delta desc;
	"))

	whileNum=0
	
	if [ "${delta_data[$whileNum]}" == "" ]; then
		echo "[ERROR]++++$chiIEEE $startDay $startTime~$endDay $endTime Temp Delta Capacity no data+++"
		exit 0
	fi

	count=0
	while :
	do
		if [ "${delta_data[$count]}" == "" ]; then
			break
		fi
		
		echo "${delta_data[$count]}" >> ./buf/DeltaData.$startDay.$chiIEEE
		
		#echo " deltaData=${delta_data[$count]}"
		
		count=$(($count+1))
	done
	
	capacityMedian=NULL

else
	delta_data=($(mysql -h ${host} -D$dbdata -ss -e"select Round((Round(tempReturn-tempSupply,2))*100,0) as delta,truncate(flowRate,2),watt
	from
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($supplyValue,2) as tempSupply
		 FROM (
			SELECT * FROM $supplyTable
			WHERE ieee='$supplyIEEE' and 
			receivedSync>='$startDay 00:00' and 
			receivedSync<='$startDay 23:59' and 
			$supplyValue >= 0 and 
			$supplyValue is not NULL
		 )as x
		 WHERE receivedSync>='$startDay $startTime' and receivedSync<='$endDay $endTime:59'
		GROUP BY time
	) as a

	INNER join
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($returnValue,2) as tempReturn
		FROM (
			SELECT * FROM $returnTable 
			WHERE ieee='$returnIEEE' and
			receivedSync>='$startDay 00:00' and
			receivedSync<='$startDay 23:59' and 
			$returnValue >=0 and
			$returnValue is not NULL
		 )as x  
		where receivedSync>='$startDay $startTime' and receivedSync<='$endDay $endTime:59'
		GROUP BY time
	) as b
	on a.time=b.time

	INNER join
	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,(IFNULL(ch1Watt,0)+IFNULL(ch2Watt,0)+IFNULL(ch3Watt,0))/1000 as watt
		 FROM (
			SELECT * FROM $pmTable
			WHERE ieee='$chiIEEE' 
			and receivedSync>='$startDay 00:00' and receivedSync<='$startDay 23:59'
		 )as x  
		where receivedSync>='$startDay $startTime' and receivedSync<='$endDay $endTime:59'
		GROUP BY time
	) as c
	on a.time=c.time

	INNER join

	(
	SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') time,Round(flowRate,2) as flowRate
		 FROM (
			SELECT * FROM $flowTable 
			WHERE ieee='$flowIEEE' and 
			receivedSync>='$startDay 00:00' and 
			receivedSync<='$startDay 23:59' and
			flowRate >= 0
		 )as x 
		where receivedSync>='$startDay $startTime' and receivedSync<='$endDay $endTime:59'
		GROUP BY time
	) as d

	on a.time=d.time

	order by delta desc;
	"))

	whileNum=0
	
	if [ "${delta_data[$whileNum]}" == "" ]; then
		echo "[ERROR]++++$chiIEEE $startDay $startTime~$endDay $endTime Temp Delta Capacity no data+++"
		exit 0
	fi

	count=0
	
	while :
	do
		if [ "${delta_data[$whileNum]}" == "" ]; then
			break
		fi
		
		echo "${delta_data[$whileNum]}" >> ./buf/DeltaData.$startDay.$chiIEEE
		
		deltaData=${delta_data[$whileNum]}
		whileNum=$(($whileNum+1))
		
		flowData=${delta_data[$whileNum]}
		whileNum=$(($whileNum+1))
		
		power=${delta_data[$whileNum]}
		whileNum=$(($whileNum+1))
		#echo " $deltaData $flowData $power"
		
		#ton = (4.2*997*(Eva Return - Eva Supply)*Flow rate) / 3.5168525
		#4.2 = heat capacity of water, 997 = density of water, 3.5168525 = to convert from kW to RT
		echo "scale=3;($deltaData*4.2*977*$flowData/(3600*3.5168525))/100"|bc >> ./buf/Capacity.$startDay.$chiIEEE

		count=$(($count+1))
	done
	
	if [ $count == 1 ]; then
	
		capacityMedian=NULL
		
	elif [ $count == 1 ]; then
	
		capacityMedian="$(cat ./buf/Capacity.$startDay.$chiIEEE | head -n 1 | tail -n 1)"
	else
	
		medianNum=$(($count/2))
		capacityMedian="$(cat ./buf/Capacity.$startDay.$chiIEEE | head -n $medianNum | tail -n 1)"
	fi

	rm ./buf/Capacity.$startDay.$chiIEEE
fi

Delta_per_0=0
Delta_per_1=0
Delta_per_2=0
Delta_per_3=0
Delta_per_4=0
Delta_per_5=0
Delta_per_6=0
Delta_per_7=0

whereNum=1
while :
do
	if [ $whereNum -gt $count ]; then
		break
	fi

	Delta="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n $whereNum | tail -n 1)"

	#echo "[DEBUG]$whereNum $Delta"
	
	if [ $Delta -le 0 ]; then
		Delta_per_0=$(($Delta_per_0+1))
	elif [ $Delta -gt 0 ] && [ $Delta -lt 100 ]; then
		Delta_per_1=$(($Delta_per_1+1))
	elif [ $Delta -ge 100 ] && [ $Delta -lt 200 ]; then
		Delta_per_2=$(($Delta_per_2+1))
	elif [ $Delta -ge 200 ] && [ $Delta -lt 300 ]; then
		Delta_per_3=$(($Delta_per_3+1))
	elif [ $Delta -ge 300 ] && [ $Delta -lt 400 ]; then
		Delta_per_4=$(($Delta_per_4+1))
	elif [ $Delta -ge 400 ] && [ $Delta -lt 500 ]; then
		Delta_per_5=$(($Delta_per_5+1))
	elif [ $Delta -ge 500 ] && [ $Delta -lt 600 ]; then
		Delta_per_6=$(($Delta_per_6+1))
	elif [ $Delta -ge 600 ]; then
		Delta_per_7=$(($Delta_per_7+1))
	else
		echo "[ERROR]Delta $head:$Delta"
	fi
	
	whereNum=$(($whereNum+1))
done

echo "$Delta_per_0" > ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_1" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_2" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_3" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_4" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_5" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_6" >> ./data/Delta.$startDay.$chiIEEE
echo "$Delta_per_7" >> ./data/Delta.$startDay.$chiIEEE

if [ $count == 0 ]; then

	#Min
	echo "NULL" >> ./data/Delta.$startDay.$chiIEEE
	
	#Median
	echo "NULL" >> ./data/Delta.$startDay.$chiIEEE
	
	#Max
	echo "NULL" >> ./data/Delta.$startDay.$chiIEEE
	
elif [ $count == 1 ]; then

	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n 1 | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE

	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n 1 | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE

	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n 1 | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE
	
else

	echo "scale=0;$(($count*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$chiIEEE
	tempFirstQuatileNum="$(cat ./buf/data.$startDay.$chiIEEE | head -n 1 | tail -n 1)" 

	echo "scale=0;$(($count*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$chiIEEE
	tempThirdQuatileNum="$(cat ./buf/data.$startDay.$chiIEEE | head -n 1 | tail -n 1)"
		
	rm ./buf/data.$startDay.$chiIEEE
	medianNum=$(($count/2))
	echo "[DEBUG] total Num:$count"
	echo "[DEBUG] tempFirstQuatile Num:$tempFirstQuatileNum"
	echo "[DEBUG] median Num:$medianNum"
	echo "[DEBUG] tempThirdQuatile Num:$tempThirdQuatileNum"
			
	#deltaMin
	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n $tempThirdQuatileNum | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE	
	
	#deltaMedian
	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n $medianNum | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE
	
	#deltaMax
	deltaTemp="$(cat ./buf/DeltaData.$startDay.$chiIEEE | head -n $tempFirstQuatileNum | tail -n 1)"
	echo "scale=2;$deltaTemp/100"|bc >> ./data/Delta.$startDay.$chiIEEE
	
fi

rm ./buf/DeltaData.$startDay.$chiIEEE

echo "$capacityMedian" >>  ./data/Delta.$startDay.$chiIEEE

echo "$count" >> ./data/Delta.$startDay.$chiIEEE
exit 0
