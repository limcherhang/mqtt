#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入 2020-01-09 09:00 2020-01-09 18:00 00124b000be4cbb8 "
		echo "		day 2019-12-15"
		echo "		00:00"
		echo "		day 2019-12-16"
		echo "		00:00"
		echo "		flow IEEE"
		echo "		flow table"
        exit 1
fi

host="127.0.0.1"
today=$(date "+%Y-%m-%d" --date="-1 day")

flowIEEE=${5}
flowTable=${6}

if [ $flowIEEE == 0 ] || [ $flowTable == 0 ] ; then
	echo "  flowIEEE is $flowIEEE & flowTable is $flowTable"
	exit 0
fi

if [ ${1} == $today ]; then
	db="iotmgmt"
else
	db="iotdata"
fi

data=($(mysql -h ${host} -D$db -ss -e"
SELECT truncate(flowRate,2)
     FROM $flowTable WHERE ieee='$flowIEEE'
    and receivedSync>='${1} ${2}' and receivedSync<='${3} ${4}:59'
    GROUP BY date_format(receivedSync, '%Y-%m-%d %H:%i') order by flowRate desc;
"))

num=0
if [ "${data[$num]}" == "" ]; then
	echo "[ERROR]++++$flowIEEE ${1} ${2}~${3} ${4} flow Median no data+++"
	exit 0
fi

if [ -f "./buf/flowDataBuf.${1}.$flowIEEE" ]; then
	rm ./buf/flowDataBuf.${1}.$flowIEEE
fi

while :
do
	if [ "${data[$num]}" == "" ]; then
		break
	fi
	
	echo "${data[$num]}" >> ./buf/flowDataBuf.${1}.$flowIEEE
	num=$(($num+1))

	#echo " ${data[$num]}"
done

sort -n ./buf/flowDataBuf.${1}.$flowIEEE > ./buf/flowDataBuf.${1}.$flowIEEE.Sort
rm ./buf/flowDataBuf.${1}.$flowIEEE

if [ $num == 0 ]; then
	medianNum=1
elif [ $num == 1 ]; then
	medianNum=1
else
	medianNum=$(($num/2))
fi

flowMedian="$(cat ./buf/flowDataBuf.${1}.$flowIEEE.Sort | head -n $medianNum | tail -n 1)"

if [ -f "./data/flowMedian.${1}.$flowIEEE" ]; then
	rm ./data/flowMedian.${1}.$flowIEEE
fi

echo "$flowMedian" > ./data/flowMedian.${1}.$flowIEEE

rm ./buf/flowDataBuf.${1}.$flowIEEE.Sort

exit 0
