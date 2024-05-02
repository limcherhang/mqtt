#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")

if [ -f "./data/*" ]; then
	rm ./data/*
fi
if [ -f "./buf/*" ]; then
	rm ./buf/*
fi


echo "Quin Right bash RunChillerReport.sh 136 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 136 $startDay $startTime $endDay $endTime


exit 0