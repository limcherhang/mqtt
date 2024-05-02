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


rm ./data/*
rm ./buf/*

startDay=${1}
startTime=${2}
endDay=${3}
endTime=${4}


# plantPerformance
bash plantPerformance.sh 42 $startDay 00:00 $endDay 00:00 167
bash plantTempPerformance.sh 42 $startDay 00:00 $endDay 00:00 167
bash plantFlow.sh 42 $startDay 00:00 $endDay 00:00 167

exit 0