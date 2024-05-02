#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ] || [ "${7}" == "" ] || [ "${8}" == "" ]; then
        echo "請輸入 2020-09-11 00:00 2020-09-11 23:59 00124b000be4cfb7 value2 ain 113"
		echo "		起始日期"
		echo "		起始時間"
		echo "		結束日期"
		echo "		結束時間"
		echo "		IEEEaddr"
		echo "		temp value"
		echo "		temp table"
		echo "		Gateway Id"
        exit 1
fi

dbRPF="reportplatform"

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

gwId=${8}
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM gateway_info where gatewayId=$gwId;"))
tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "  ----------------DataBase--------------------- "
echo "  dbdata $dbdata tempTable $tempTable"

tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT date_format(receivedSync, '%Y-%m-%d %H:%i')as time,ieee,truncate((truncate($tempValue,2))*100,0) as Temp
 FROM 
	$tempTable 
 WHERE 
	ieee='$tempIEEE' and 
	receivedSync >= '$startDay $startTime' and 
	receivedSync <= '$endDay $endTime:59' and 
	$tempValue >= 0 and 
	$tempValue is not NULL
GROUP BY time
"))

whileNum=0
count=0


if [ "${tempData[$whileNum]}" == "" ]; then
	echo "[ERROR]++++$tempIEEE $startDay $startTime~$endDay $endTime Temp no data+++"
	
	echo "NULL" > ./data/temp.$startDay.$tempIEEE
	
	#echo -n "  EvaTempMin: "
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	#echo -n "  EvaTempMax: "
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	#echo -n "  EvaTempMedian: "
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE

	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE
	echo "NULL" >> ./data/temp.$startDay.$tempIEEE

	exit 0
fi

while :
do
	if [ "${tempData[$whileNum]}" == "" ]; then
		break
	fi
	
	whileNum=$(($whileNum+6))
	
	count=$(($count+1))
done

#echo "$count" > ./tempBuf.txt

whileNum=0
TempMax=0
TempMin=100000
TempMedianTotal=0
count=0

if [ -f "./buf/temp.value.$startDay.$tempIEEE" ]; then
	echo "  remove ./buf/temp.value.$startDay.$tempIEEE"
	rm ./buf/temp.value.$startDay.$tempIEEE
fi

while :
do
	if [ "${tempData[$whileNum]}" == "" ]; then
		break
	fi
	
	ts_day=${tempData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	ts_time=${tempData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	ieee=${tempData[$whileNum]}
	whileNum=$(($whileNum+1))

	value1=${tempData[$whileNum]}
	whileNum=$(($whileNum+1))
	
	# > TempMax
	# if [ $value1 -gt $TempMax ]; then
		# TempMax=$value1
	# fi
	
	# < TempMin
	# if [ $value1 -lt $TempMin ]; then
		# TempMin=$value1
	# fi
	echo "$value1" >> ./buf/temp.value.$startDay.$tempIEEE
	
	#TempMedianTotal
	TempMedianTotal=$(($TempMedianTotal+$value1))
	
	count=$(($count+1))
	
	if [ $value1 -gt 300 ] && [ $value1 -le 599 ]; then
		temp_per_0=$(($temp_per_0+1))
	elif [ $value1 -ge 600 ] && [ $value1 -le 699 ]; then
		temp_per_1=$(($temp_per_1+1))
	elif [ $value1 -ge 700 ] && [ $value1 -le 799 ]; then
		temp_per_2=$(($temp_per_2+1))
	elif [ $value1 -ge 800 ] && [ $value1 -le 899 ]; then
		temp_per_3=$(($temp_per_3+1))
	elif [ $value1 -ge 900 ] && [ $value1 -le 999 ]; then
		temp_per_4=$(($temp_per_4+1))
	elif [ $value1 -ge 1000 ] && [ $value1 -le 1099 ]; then
		temp_per_5=$(($temp_per_5+1))
	elif [ $value1 -ge 1100 ] && [ $value1 -le 1199 ]; then
		temp_per_6=$(($temp_per_6+1))
	elif [ $value1 -ge 1200 ] && [ $value1 -le 1499 ]; then
		temp_per_7=$(($temp_per_7+1))
	elif [ $value1 -ge 1500 ] && [ $value1 -le 1799 ]; then
		temp_per_8=$(($temp_per_8+1))
	elif [ $value1 -ge 1800 ] && [ $value1 -le 2099 ]; then
		temp_per_9=$(($temp_per_9+1))
	elif [ $value1 -ge 2100 ] && [ $value1 -le 2399 ]; then
		temp_per_10=$(($temp_per_10+1))
	elif [ $value1 -ge 2400 ] && [ $value1 -le 2699 ]; then
		temp_per_11=$(($temp_per_11+1))
	elif [ $value1 -ge 2699 ]; then
		temp_per_12=$(($temp_per_12+1))
	else
		echo "value1 ERROR $value1"
	fi
done

#TempMedianTotal=$(($TempMedianTotal/$count))
echo "scale=2;($TempMedianTotal/$count)/100"|bc > ./data/temp.$startDay.$tempIEEE

sort ./buf/temp.value.$startDay.$tempIEEE > ./buf/temp.value.$startDay.$tempIEEE.sort
tempCounts="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | wc -l)" 

echo "[DEBUG] tempCounts Num:$tempCounts"	

if [ $tempCounts == 0 ]; then

	tempMin=NULL
	tempMedian=NULL
	tempMax=NULL
	
elif [ $tempCounts == 1 ]; then

	tempMin="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | head -n  1 | tail -n 1)" 
	tempMedian="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | head -n 1 | tail -n 1)" 
	tempMax="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | head -n 1 | tail -n 1)" 
else
	
	echo "scale=0;$(($tempCounts*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$tempIEEE
	tempFirstQuatileNum="$(cat ./buf/data.$startDay.$tempIEEE | head -n 1 | tail -n 1)"
	if [ $tempFirstQuatileNum == 0 ]; then
		tempFirstQuatileNum=1
		echo "[DEBUG] tempFirstQuatile is 0 "	
	fi
	echo "[DEBUG] tempFirstQuatile Num:$tempFirstQuatileNum"
	
	echo "scale=0;$(($tempCounts*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$tempIEEE
	tempThirdQuatileNum="$(cat ./buf/data.$startDay.$tempIEEE | head -n 1 | tail -n 1)"
	echo "[DEBUG] tempThirdQuatile Num:$tempThirdQuatileNum"	
	
	rm ./buf/data.$startDay.$tempIEEE
	medianNum=$(($tempCounts/2))
	
	tempMin="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | head -n  $tempFirstQuatileNum | tail -n 1)" 
	tempMedian="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort | head -n $medianNum | tail -n 1)" 
	tempMax="$(cat ./buf/temp.value.$startDay.$tempIEEE.sort  | head -n $tempThirdQuatileNum | tail -n 1)" 
fi

rm ./buf/temp.value.$startDay.$tempIEEE.sort

echo "scale=2;$tempMin/100"|bc >> ./data/temp.$startDay.$tempIEEE
echo "scale=2;$tempMax/100"|bc >> ./data/temp.$startDay.$tempIEEE
echo "scale=2;$tempMedian/100"|bc >> ./data/temp.$startDay.$tempIEEE

# 20210930 D.w
# echo "$tempMin" >> ./data/temp.$startDay.$tempIEEE
# echo "$tempMax" >> ./data/temp.$startDay.$tempIEEE
# echo "$tempMedian" >> ./data/temp.$startDay.$tempIEEE

# numMedian=$(($count/2))

# tempData=($(mysql -h ${host} -D$dbdata -ss -e"SELECT truncate((truncate($tempValue,2))*100,0) as Temp
	# FROM $tempTable WHERE ieee='$tempIEEE' 
# and receivedSync>='$startDay $startTime' and receivedSync<='$endDay $endTime:59' and $tempValue is not NULL
# GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i') ORDER BY Temp desc
# "))

# TempMedian=${tempData[$numMedian]}

# #echo -n "  EvaTempMin: "
# echo "scale=2;$TempMin/100"|bc >> ./data/temp.$startDay.$tempIEEE
# #echo -n "  EvaTempMax: "
# echo "scale=2;$TempMax/100"|bc >> ./data/temp.$startDay.$tempIEEE
# #echo -n "  EvaTempMedian: "
# echo "scale=2;$TempMedian/100"|bc >> ./data/temp.$startDay.$tempIEEE

echo "$temp_per_0" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_1" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_2" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_3" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_4" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_5" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_6" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_7" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_8" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_9" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_10" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_11" >> ./data/temp.$startDay.$tempIEEE
echo "$temp_per_12" >> ./data/temp.$startDay.$tempIEEE
echo "$count" >> ./data/temp.$startDay.$tempIEEE
exit 0
