#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")


#rm ./data/*
rm ./buf/*

#dailyChillerData
bash chillerData.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148
bash chillerData.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148

# dailyPumpData
bash chillerPumpData.sh 23 power#3 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 148
bash chillerPumpData.sh 23 power#4 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 148

bash pumpPerformance.sh 23 power#3 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 148
bash pumpPerformance.sh 23 power#4 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 148

# dailyCoolingData
bash CoolingData.sh 23 power#7 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 148
bash CoolingData.sh 23 power#8 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 148

bash coolingPerformance.sh 23 power#7 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 148
bash coolingPerformance.sh 23 power#8 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 148

# daily Cooling Pump Data
bash coolingPumpData.sh 23 power#5 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 148
bash coolingPumpData.sh 23 power#6 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 148

bash coolingPumpDataPerformance.sh 23 power#5 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 148
bash coolingPumpDataPerformance.sh 23 power#6 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 148

# chillerTempData
bash chillerTempData.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 temp#3 temp#4
bash chillerTempData.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 temp#7 temp#8

# chillerCoolingTempData
bash chillerCoolingTempData.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 temp#5 temp#6
bash chillerCoolingTempData.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 temp#9 temp#10

# chillerCoolingPerformance
bash chillerCoolingPerformance.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 temp#5 temp#6
bash chillerCoolingPerformance.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 temp#9 temp#10

# chillerFlow
bash chillerFlowData.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 flow#1 
bash chillerFlowData.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 flow#3

# cooling Flow
bash chillerCoolingFlowData.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 flow#2
bash chillerCoolingFlowData.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 flow#4

# chillerSitePerformance
bash chillerSitePerformance.sh 23 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 148 temp#3 temp#4
bash chillerSitePerformance.sh 23 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 148 temp#7 temp#8

# plantPerformance
bash plantPerformance.sh 23 $startDay 00:00 $endDay 00:00 148
bash plantTempPerformance.sh 23 $startDay 00:00 $endDay 00:00 148
bash plantFlow.sh 23 $startDay 00:00 $endDay 00:00 148 

# #dailyChillerData
# bash chillerData.sh 23 power#1 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 148
# bash chillerData.sh 23 power#2 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 148

# # dailyPumpData
# bash chillerPumpData.sh 23 power#3 1 ChilledWaterPump#1 2021-10-09 00:00 2021-10-10 00:00 148
# bash chillerPumpData.sh 23 power#4 2 ChilledWaterPump#2 2021-10-09 00:00 2021-10-10 00:00 148

# # dailyCoolingData
# bash CoolingData.sh 23 power#7 1 CoolingTower#1 2021-10-09 00:00 2021-10-10 00:00 148
# bash CoolingData.sh 23 power#8 2 CoolingTower#2 2021-10-09 00:00 2021-10-10 00:00 148

# # dailyCoolingPumpData
# bash chillerCoolingPumpData.sh 23 power#5 1 ChilledWaterPump#1 2021-10-09 00:00 2021-10-10 00:00 148
# bash chillerCoolingPumpData.sh 23 power#6 2 ChilledWaterPump#2 2021-10-09 00:00 2021-10-10 00:00 148

# # chillerTempData
# bash chillerTempData.sh 23 power#1 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 148 temp#3 temp#4
# bash chillerTempData.sh 23 power#2 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 148 temp#7 temp#8

# # chillerCoolingTempData
# bash chillerCoolingTempData.sh 23 power#1 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 148 temp#5 temp#6
# bash chillerCoolingTempData.sh 23 power#2 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 148 temp#9 temp#10

# # chillerFlow
# bash chillerFlowData.sh 23 power#1 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 148 flow#1 
# bash chillerFlowData.sh 23 power#2 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 148 flow#3

# # chillerSitePerformance
# bash chillerSitePerformance.sh 23 power#1 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 148 temp#3 temp#4
# bash chillerSitePerformance.sh 23 power#2 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 148 temp#7 temp#8

# # plantPerformance
# bash plantPerformance.sh 23 2021-10-09 00:00 2021-10-10 00:00 148
# bash plantTempPerformance.sh 23 2021-10-09 00:00 2021-10-10 00:00 148
# bash plantFlow.sh 23 2021-10-09 00:00 2021-10-10 00:00 148 

exit 0