#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")

if [ -f "./data/" ]; then
	rm ./data/*
fi
if [ -f "./buf/" ]; then
	rm ./buf/*
fi

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