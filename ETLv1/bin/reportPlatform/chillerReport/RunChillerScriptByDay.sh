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


echo "PresidentBakery bash RunChillerReport.sh 110 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 110 $startDay $startTime $endDay $endTime

#echo "SCG bash RunChillerReport.sh 104 $startDay $startTime $endDay $endTime"
#bash RunChillerReport.sh 104 $startDay $startTime $endDay $endTime

#echo "OceanMarina bash RunChillerReport.sh 105 $startDay $startTime $endDay $endTime"
#bash RunChillerReport.sh 105 $startDay $startTime $endDay $endTime

#echo "OrchardRoad bash RunChillerReport.sh 106 $startDay $startTime $endDay $endTime"
#bash RunChillerReport.sh 106 $startDay $startTime $endDay $endTime

#echo "BeachRoad bash RunChillerReport.sh 109 $startDay $startTime $endDay $endTime"
#bash RunChillerReport.sh 109 $startDay $startTime $endDay $endTime

echo "KichenerRoad bash RunChillerReport.sh 112 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 112 $startDay $startTime $endDay $endTime

echo "Pickering bash RunChillerReport.sh 113 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 113 $startDay $startTime $endDay $endTime
exit 0