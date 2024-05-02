#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")


#rm ./data/*
#rm ./buf/*

bash plantPerformance.sh 47 $startDay 00:00 $endDay 00:00 172
bash plantTempPerformance.sh 47 $startDay 00:00 $endDay 00:00 172
bash plantFlow.sh 47 $startDay 00:00 $endDay 00:00 172


exit 0