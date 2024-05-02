#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ]; then
        echo "請輸入 日期範圍"
		echo "		2019-12-15"
		echo "		00:00"
		echo "		2019-12-16"
		echo "		00:00"
       exit 1
fi

if [ -f "./data/*" ]; then
	rm ./data/*
fi
if [ -f "./buf/*" ]; then
	rm ./buf/*
fi

startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}

echo "Beach Road bash RunChillerReport.sh 133 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 133 $startDay $startTime $endDay $endTime
exit 0