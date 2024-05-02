#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")


#rm ./data/*
#rm ./buf/*
rm ./buf/*

#dailyChillerData
bash chillerData.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168
bash chillerData.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168
bash chillerData.sh 44 power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 168
bash chillerData.sh 44 power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 168

# dailyPumpData
bash chillerPumpData.sh 44 power#5 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 168
bash chillerPumpData.sh 44 power#6 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 168
bash chillerPumpData.sh 44 power#7 1 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 168
bash chillerPumpData.sh 44 power#8 2 ChilledWaterPump#4 $startDay 00:00 $endDay 00:00 168

bash pumpPerformance.sh 44 power#5 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 168
bash pumpPerformance.sh 44 power#6 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 168
bash pumpPerformance.sh 44 power#7 3 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 168
bash pumpPerformance.sh 44 power#8 4 ChilledWaterPump#4 $startDay 00:00 $endDay 00:00 168

# dailyCoolingData
bash CoolingData.sh 44 power#13 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 168
bash CoolingData.sh 44 power#14 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 168
bash CoolingData.sh 44 power#15 3 CoolingTower#3 $startDay 00:00 $endDay 00:00 168
bash CoolingData.sh 44 power#16 4 CoolingTower#4 $startDay 00:00 $endDay 00:00 168

bash coolingPerformance.sh 44 power#13 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 168
bash coolingPerformance.sh 44 power#14 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 168
bash coolingPerformance.sh 44 power#15 3 CoolingTower#3 $startDay 00:00 $endDay 00:00 168
bash coolingPerformance.sh 44 power#16 4 CoolingTower#4 $startDay 00:00 $endDay 00:00 168

# daily Cooling Pump Data
bash coolingPumpData.sh 44 power#9 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 168
bash coolingPumpData.sh 44 power#10 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 168
bash coolingPumpData.sh 44 power#11 3 CoolingWaterPump#3 $startDay 00:00 $endDay 00:00 168
bash coolingPumpData.sh 44 power#12 4 CoolingWaterPump#4 $startDay 00:00 $endDay 00:00 168

bash coolingPumpDataPerformance.sh 44 power#9 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 168
bash coolingPumpDataPerformance.sh 44 power#10 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 168
bash coolingPumpDataPerformance.sh 44 power#11 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 168
bash coolingPumpDataPerformance.sh 44 power#12 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 168

# chillerTempData
bash chillerTempData.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 temp#1 temp#2
bash chillerTempData.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 temp#5 temp#6
bash chillerTempData.sh 44 power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 168 temp#9 temp#10
bash chillerTempData.sh 44 power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 168 temp#13 temp#14

# chillerCoolingTempData
bash chillerCoolingTempData.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 temp#3 temp#4
bash chillerCoolingTempData.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 temp#7 temp#8
bash chillerCoolingTempData.sh 44 power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 168 temp#11 temp#12
bash chillerCoolingTempData.sh 44 power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 168 temp#15 temp#16

# chillerCoolingPerformance
bash chillerCoolingPerformance.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 temp#3 temp#4
bash chillerCoolingPerformance.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 temp#7 temp#8
bash chillerCoolingPerformance.sh 44 power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 168 temp#11 temp#12
bash chillerCoolingPerformance.sh 44 power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 168 temp#15 temp#16

# chillerFlow
bash chillerFlowData.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 flow#1 
bash chillerFlowData.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 flow#3
bash chillerFlowData.sh 44 power#3 1 Chiller#3 $startDay 00:00 $endDay 00:00 168 flow#5 
bash chillerFlowData.sh 44 power#4 2 Chiller#4 $startDay 00:00 $endDay 00:00 168 flow#7

# cooling Flow
bash chillerCoolingFlowData.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 flow#2 
bash chillerCoolingFlowData.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 flow#4
bash chillerCoolingFlowData.sh 44 power#3 1 Chiller#3 $startDay 00:00 $endDay 00:00 168 flow#6 
bash chillerCoolingFlowData.sh 44 power#4 2 Chiller#4 $startDay 00:00 $endDay 00:00 168 flow#8

# chillerSitePerformance
bash chillerSitePerformance.sh 44 power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 168 temp#1 temp#2
bash chillerSitePerformance.sh 44 power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 168 temp#5 temp#6
bash chillerSitePerformance.sh 44 power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 168 temp#9 temp#10
bash chillerSitePerformance.sh 44 power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 168 temp#13 temp#14

bash plantPerformance.sh 44 $startDay 00:00 $endDay 00:00 168
bash plantTempPerformance.sh 44 $startDay 00:00 $endDay 00:00 168
bash plantFlow.sh 44 $startDay 00:00 $endDay 00:00 168


exit 0