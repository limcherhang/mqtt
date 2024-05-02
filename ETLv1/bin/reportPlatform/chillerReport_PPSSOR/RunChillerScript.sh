#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")


rm ./data/*
rm ./buf/*


echo "PPSS OrchardRoad bash RunChillerReport.sh 106 $startDay $startTime $endDay $endTime"
bash RunChillerReport.sh 106 $startDay $startTime $endDay $endTime

exit 0