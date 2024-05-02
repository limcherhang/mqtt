#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ]; then
        echo "請輸入 2020/02/12 00:00 2020/02/12 23:59 00124b000be4cd60 temp1 dTemperature"
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
		echo "		IEEEaddr"
		echo "		temp value"
		echo "		temp table"
        exit 1
fi

#value defined
startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}
tempIEEE=${5}
tempValue=${6}


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
	
	tempTable=${7}
	
else
	#dbdata="iotdata"
	
	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")

	tempTable=${7}_$dbdataMonth
	
	dbdata="iotdata$dbdataYear"
fi

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata tempTable $tempTable"

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
	tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT Round(avg($tempValue),2) as Temp
	 FROM 
		$tempTable 
	 WHERE 
		ieee='$tempIEEE' and 
		receivedSync>='$startDay $stHour:00' and 
		receivedSync<='$startDay $endHour:$endMin:59' and 
		$tempValue >=0 and 
		$tempValue is not NULL
	"))

	jsonNum=$(($jsonNum+1))
				  #>=
	if [ $jsonNum -ge 2 ]; then
		printf ",">> ./data/tempHours.$startDay.$tempIEEE
	fi
	
	if [ $tempData == 99999 ]; then
		printf "\"data%d\": {\"stHours\": %d,\"stMin\": %d,\"endHours\": %d,\"endMin\": %d,\"data\": null}"  $jsonNum $stHour 00 $endHour $endMin >> ./data/tempHours.$startDay.$tempIEEE
	else
		printf "\"data%d\": {\"stHours\": %d,\"stMin\": %d,\"endHours\": %d,\"endMin\": %d,\"data\": %.02f}"  $jsonNum $stHour 00 $endHour $endMin $tempData >> ./data/tempHours.$startDay.$tempIEEE	
	fi
	
	stHour=$(($stHour+1))
done

exit 0