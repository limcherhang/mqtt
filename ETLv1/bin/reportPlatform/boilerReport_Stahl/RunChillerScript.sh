#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")


#rm ./data/*
#rm ./buf/*


bash plantPerformance.sh 42 $startDay 00:00 $endDay 00:00
bash plantTemp.sh 42 $startDay 00:00 $endDay 00:00 power#4 temp#5
bash plantTemp.sh 42 $startDay 00:00 $endDay 00:00 power#4 temp#6
bash plantFlow.sh 42 $startDay 00:00 $endDay 00:00 power#4 flow#2
exit 0