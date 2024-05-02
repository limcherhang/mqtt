#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

startDay=$(date "+%Y-%m-%d" --date="-1 day")
startTime=$(date "+00:00")

endDay=$(date "+%Y-%m-%d")
endTime=$(date "+00:00")

siteId=48
gatewayId=174

#rm ./data/*
#rm ./buf/*
rm ./buf/*

#dailyChillerData
bash chillerData.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerData.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerData.sh $siteId power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerData.sh $siteId power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId

# dailyPumpData
bash chillerPumpData.sh $siteId power#5 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerPumpData.sh $siteId power#6 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerPumpData.sh $siteId power#7 1 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 $gatewayId
bash chillerPumpData.sh $siteId power#8 2 ChilledWaterPump#4 $startDay 00:00 $endDay 00:00 $gatewayId

bash pumpPerformance.sh $siteId power#5 1 ChilledWaterPump#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash pumpPerformance.sh $siteId power#6 2 ChilledWaterPump#2 $startDay 00:00 $endDay 00:00 $gatewayId
bash pumpPerformance.sh $siteId power#7 3 ChilledWaterPump#3 $startDay 00:00 $endDay 00:00 $gatewayId
bash pumpPerformance.sh $siteId power#8 4 ChilledWaterPump#4 $startDay 00:00 $endDay 00:00 $gatewayId

# dailyCoolingData
bash CoolingData.sh $siteId power#13 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash CoolingData.sh $siteId power#14 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 $gatewayId

bash coolingPerformance.sh $siteId power#13 1 CoolingTower#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPerformance.sh $siteId power#14 2 CoolingTower#2 $startDay 00:00 $endDay 00:00 $gatewayId

# daily Cooling Pump Data
bash coolingPumpData.sh $siteId power#9 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpData.sh $siteId power#10 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpData.sh $siteId power#11 3 CoolingWaterPump#3 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpData.sh $siteId power#12 4 CoolingWaterPump#4 $startDay 00:00 $endDay 00:00 $gatewayId

bash coolingPumpDataPerformance.sh $siteId power#9 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpDataPerformance.sh $siteId power#10 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpDataPerformance.sh $siteId power#11 1 CoolingWaterPump#1 $startDay 00:00 $endDay 00:00 $gatewayId
bash coolingPumpDataPerformance.sh $siteId power#12 2 CoolingWaterPump#2 $startDay 00:00 $endDay 00:00 $gatewayId

# chillerTempData                                                                            Supply   Return
bash chillerTempData.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId temp#12 temp#13
bash chillerTempData.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId temp#16 temp#17
bash chillerTempData.sh $siteId power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId temp#20 temp#21
bash chillerTempData.sh $siteId power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId temp#24 temp#25

# chillerCoolingTempData
bash chillerCoolingTempData.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId temp#14 temp#15
bash chillerCoolingTempData.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId temp#18 temp#19
bash chillerCoolingTempData.sh $siteId power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId temp#22 temp#23
bash chillerCoolingTempData.sh $siteId power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId temp#26 temp#27

# chillerCoolingPerformance
bash chillerCoolingPerformance.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId temp#14 temp#15
bash chillerCoolingPerformance.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId temp#18 temp#19
bash chillerCoolingPerformance.sh $siteId power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId temp#22 temp#23
bash chillerCoolingPerformance.sh $siteId power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId temp#26 temp#27

# chillerFlow
bash chillerFlowData.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId flow#5
bash chillerFlowData.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId flow#6
bash chillerFlowData.sh $siteId power#3 1 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId flow#7
bash chillerFlowData.sh $siteId power#4 2 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId flow#8

# cooling Flow
# bash chillerCoolingFlowData.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId flow#2 
# bash chillerCoolingFlowData.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId flow#4
# bash chillerCoolingFlowData.sh $siteId power#3 1 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId flow#6 
# bash chillerCoolingFlowData.sh $siteId power#4 2 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId flow#8

# chillerSitePerformance
bash chillerSitePerformance.sh $siteId power#1 1 Chiller#1 $startDay 00:00 $endDay 00:00 $gatewayId temp#12 temp#13
bash chillerSitePerformance.sh $siteId power#2 2 Chiller#2 $startDay 00:00 $endDay 00:00 $gatewayId temp#16 temp#17
bash chillerSitePerformance.sh $siteId power#3 3 Chiller#3 $startDay 00:00 $endDay 00:00 $gatewayId temp#20 temp#21
bash chillerSitePerformance.sh $siteId power#4 4 Chiller#4 $startDay 00:00 $endDay 00:00 $gatewayId temp#24 temp#25

bash plantPerformance.sh $siteId $startDay 00:00 $endDay 00:00 $gatewayId
bash plantTempPerformance.sh $siteId $startDay 00:00 $endDay 00:00 $gatewayId
bash plantFlow.sh $siteId $startDay 00:00 $endDay 00:00 $gatewayId


exit 0