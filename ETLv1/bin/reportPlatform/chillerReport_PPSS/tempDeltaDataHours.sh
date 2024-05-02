#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ] || [ "${8}" == "" ] || [ "${9}" == "" ] || [ "${10}" == "" ]; then
        echo "請輸入 2020-02-12 00:00 2020-02-12 23:59 00124b000be4cd60 temp1 dTemperature 00124b000be4cd60 temp2 dTemperature"
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
		echo "		temp Supply IEEE"
		echo "		temp Supply Value"
		echo "		temp Supply Table"
		echo "		temp Return IEEE"
		echo "		temp Return Value"
		echo "		temp Return Table"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

tempSupplyIEEE=${5}
tempSupplyValue=${6}
tempSupplyTable=${7}

tempReturnIEEE=${8}
tempReturnValue=${9}
tempReturnTable=${10}

temp_per_0=0
temp_per_1=0
temp_per_2=0
temp_per_3=0
temp_per_4=0
temp_per_5=0
temp_per_6=0
temp_per_7=0
temp_per_8=0
temp_per_9=0
temp_per_10=0
temp_per_11=0
temp_per_12=0

host="127.0.0.1"
today=$(date "+%Y-%m-%d" --date="-1 day")

if [ $startDay == $today ]; then
	dbdata="iotmgmt"
	
	tempSupplyTable=${7}
	tempReturnTable=${10}
	
else
	#dbdata="iotdata"
	
	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")

	tempSupplyTable=${7}_$dbdataMonth
	tempReturnTable=${10}_$dbdataMonth
	
	dbdata="iotdata$dbdataYear"
fi

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata tempSupplyTable $tempSupplyTable tempReturnTable $tempReturnTable"

if [ -f "./data/tempHours.$startDay.$tempIEEE" ]; then
	#echo "rm data"
	rm ./data/tempHours.$startDay.$tempIEEE
fi

stHour=0
jsonNum=0
while :
do
	if [ $stHour == 24 ]; then
		break
	elif [ $stHour == 23 ]; then
		endHour=23
		endMin=59
	else
		endHour=$(($stHour+1))
		endMin=00
	fi
	
	#echo " $stHour:00 ~ $endHour:$endMin"
	tempData=($(mysql -h ${host} -D$dbdata -ss -e"select Avg(Round(tempReturn-tempSupply,2)) as delta
		from
		(
		SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempSupplyValue,2) as tempSupply
			 FROM 
				$tempSupplyTable
			 where
				ieee='$tempSupplyIEEE' and
				receivedSync>='$startDay $stHour:$stMin' and 
				receivedSync<='$startDay $endHour:$endMin:59'and
				$tempSupplyValue >= 0 and
				$tempSupplyValue is not NULL
			GROUP BY time
		) as a

		INNER join
		(
		SELECT date_format(receivedSync, '%Y-%m-%d %H:%i') as time,truncate($tempReturnValue,2) as tempReturn
			FROM
				$tempReturnTable
			where
				ieee='$tempReturnIEEE' and
				receivedSync>='$startDay $stHour:$stMin' and 
				receivedSync<='$startDay $endHour:$endMin:59' and 
				$tempReturnValue >= 0 and
				$tempReturnValue is not NULL
			GROUP BY time			
		) as b
		on a.time=b.time;
	"))

	jsonNum=$(($jsonNum+1))
				  #>=
	if [ $jsonNum -ge 2 ]; then
		printf ",">> ./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE
	fi
	
	if [ $tempData == "" ]; then
		printf "\"data%d\": {\"stHours\": %d,\"stMin\": %d,\"endHours\": %d,\"endMin\": %d,\"data\": null}"  $jsonNum $stHour 00 $endHour $endMin >> ./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE
	else
		printf "\"data%d\": {\"stHours\": %d,\"stMin\": %d,\"endHours\": %d,\"endMin\": %d,\"data\": %.02f}"  $jsonNum $stHour 00 $endHour $endMin $tempData >> ./data/tempDeltaHours.$startDay.$tempSupplyIEEE.$tempReturnIEEE	
	fi
	
	stHour=$(($stHour+1))
done

exit 0