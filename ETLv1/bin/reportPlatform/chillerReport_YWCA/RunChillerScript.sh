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
bash chillerData.sh 24 power#19 1 chiller#1 $startDay 00:00 $endDay 00:00 152
bash chillerData.sh 24 power#20 2 chiller#2 $startDay 00:00 $endDay 00:00 152

# dailyPumpData
bash chillerPumpData.sh 24 power#25 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 152
bash chillerPumpData.sh 24 power#26 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 152
bash chillerPumpData.sh 24 power#27 3 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 152

bash pumpPerformance.sh 24 power#25 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 152
bash pumpPerformance.sh 24 power#26 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 152
bash pumpPerformance.sh 24 power#27 3 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 152

# dailyCoolingData
bash CoolingData.sh 24 power#21 power#22 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 152
bash CoolingData.sh 24 power#23 power#24 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 152

bash coolingPerformance.sh 24 power#21 power#22 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 152
bash coolingPerformance.sh 24 power#23 power#24 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 152

# dailyCoolingPumpData
bash chillerCoolingPumpData.sh 24 power#28 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 152
bash chillerCoolingPumpData.sh 24 power#29 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 152
bash chillerCoolingPumpData.sh 24 power#30 3 CoolingWaterPump#3 $startDay 00:00 $endDay 00:00 152

bash coolingPumpPerformance.sh 24 power#28 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 152
bash coolingPumpPerformance.sh 24 power#29 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 152
bash coolingPumpPerformance.sh 24 power#30 3 CoolingWaterPump#3 $startDay 00:00 $endDay 00:00 152


# chillerTempData
bash chillerTempData.sh 24 power#19 1 chiller#1 $startDay 00:00 $endDay 00:00 152 temp#1 temp#2
bash chillerTempData.sh 24 power#20 2 chiller#2 $startDay 00:00 $endDay 00:00 152 temp#3 temp#4

# chillerFlow
bash chillerFlowData.sh 24 power#19 1 chiller#1 $startDay 00:00 $endDay 00:00 152 flow#3 
bash chillerFlowData.sh 24 power#20 2 chiller#2 $startDay 00:00 $endDay 00:00 152 flow#4 

# chillerSitePerformance
bash chillerSitePerformance.sh 24 power#19 1 chiller#1 $startDay 00:00 $endDay 00:00 152 temp#1 temp#2
bash chillerSitePerformance.sh 24 power#20 2 chiller#2 $startDay 00:00 $endDay 00:00 152 temp#3 temp#4

# plantPerformance
bash plantPerformance.sh 24 $startDay 00:00 $endDay 00:00 152
bash plantTempPerformance.sh 24 $startDay 00:00 $endDay 00:00 152
bash plantFlow.sh 24 $startDay 00:00 $endDay 00:00 152 

# #dailyChillerData
# bash chillerData.sh 24 power#19 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 152
# bash chillerData.sh 24 power#20 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 152

# # dailyPumpData
# bash chillerPumpData.sh 24 power#25 1 ChilledWaterPump#1 2021-10-09 00:00 2021-10-10 00:00 152
# bash chillerPumpData.sh 24 power#26 2 ChilledWaterPump#2 2021-10-09 00:00 2021-10-10 00:00 152
# bash chillerPumpData.sh 24 power#27 3 ChilledWaterPump#3 2021-10-09 00:00 2021-10-10 00:00 152

# # dailyCoolingData
# bash CoolingData.sh 24 power#21 power#22 1 CoolingTower#1 2021-10-09 00:00 2021-10-10 00:00 152
# bash CoolingData.sh 24 power#23 power#24 2 CoolingTower#2 2021-10-09 00:00 2021-10-10 00:00 152


# # dailyCoolingPumpData
# bash chillerCoolingPumpData.sh 24 power#28 1 ChilledWaterPump#1 2021-10-09 00:00 2021-10-10 00:00 152
# bash chillerCoolingPumpData.sh 24 power#29 2 ChilledWaterPump#2 2021-10-09 00:00 2021-10-10 00:00 152
# bash chillerCoolingPumpData.sh 24 power#30 3 ChilledWaterPump#3 2021-10-09 00:00 2021-10-10 00:00 152


# # chillerTempData
# bash chillerTempData.sh 24 power#19 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 152 temp#1 temp#2
# bash chillerTempData.sh 24 power#20 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 152 temp#3 temp#4

# # chillerFlow
# bash chillerFlowData.sh 24 power#19 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 152 flow#3 
# bash chillerFlowData.sh 24 power#20 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 152 flow#4 

# # chillerSitePerformance
# bash chillerSitePerformance.sh 24 power#19 1 chiller#1 2021-10-09 00:00 2021-10-10 00:00 152 temp#1 temp#2
# bash chillerSitePerformance.sh 24 power#20 2 chiller#2 2021-10-09 00:00 2021-10-10 00:00 152 temp#3 temp#4

# # plantPerformance
# bash plantPerformance.sh 24 2021-10-09 00:00 2021-10-10 00:00 152
# bash plantTempPerformance.sh 24 2021-10-09 00:00 2021-10-10 00:00 152
# bash plantFlow.sh 24 2021-10-09 00:00 2021-10-10 00:00 152 

exit 0