#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbRPF="reportplatform"

if [ ! -f "./chillerPerformanceOperation" ]; then
	#檔案不存在
	echo "[ERROR]Directory ./chillerPerformanceOperation does not exists."
	exit 1
fi

operation="$(cat ./chillerPerformanceOperation | head -n 1 | tail -n 1)"	
rm ./chillerPerformanceOperation

if [ $operation == 0 ]; then
	echo "  chiller operation OFF"
	exit 1
fi

#chiller start time
operationDate="$(cat ./chillerPerformanceData | head -n 1 | tail -n 1)"	
gatewayId="$(cat ./chillerPerformanceData | head -n 2 | tail -n 1)"	
siteId=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT siteId FROM reportplatform.gateway_info where gatewayId=$gatewayId;"))

chillerDescription="$(cat ./chillerPerformanceData | head -n 3 | tail -n 1)"	
chillerId="$(cat ./chillerPerformanceData | head -n 4 | tail -n 1)"
activityCount="$(cat ./chillerPerformanceData | head -n 5 | tail -n 1)"
activityState="$(cat ./chillerPerformanceData | head -n 6 | tail -n 1)"
totalOperationMinutes="$(cat ./chillerPerformanceData | head -n 7 | tail -n 1)"
avgPowerConsumption="$(cat ./chillerPerformanceData | head -n 8 | tail -n 1)"
totalEnergyConsumption="$(cat ./chillerPerformanceData | head -n 9 | tail -n 1)"
avgPowerLoading="$(cat ./chillerPerformanceData | head -n 10 | tail -n 1)"
efficiencyMin="$(cat ./chillerPerformanceData | head -n 11 | tail -n 1)"
efficiencyMedian="$(cat ./chillerPerformanceData | head -n 12 | tail -n 1)"
efficiencyMax="$(cat ./chillerPerformanceData | head -n 13 | tail -n 1)"
coolingCapacityMin="$(cat ./chillerPerformanceData | head -n 14 | tail -n 1)"
coolingCapacityMedian="$(cat ./chillerPerformanceData | head -n 15 | tail -n 1)"
coolingCapacityMax="$(cat ./chillerPerformanceData | head -n 16 | tail -n 1)"

# returnTempMin="$(cat ./chillerPerformanceData | head -n 17 | tail -n 1)"
# returnTempMedian="$(cat ./chillerPerformanceData | head -n 18 | tail -n 1)"
# returnTempMax="$(cat ./chillerPerformanceData | head -n 19 | tail -n 1)"
# supplyTempMin="$(cat ./chillerPerformanceData | head -n 20 | tail -n 1)"
# supplyTempMedian="$(cat ./chillerPerformanceData | head -n 21 | tail -n 1)"
# supplyTempMax="$(cat ./chillerPerformanceData | head -n 22 | tail -n 1)"
# 2020 09 15 修改
supplyTempMin="$(cat ./chillerPerformanceData | head -n 17 | tail -n 1)"
supplyTempMedian="$(cat ./chillerPerformanceData | head -n 18 | tail -n 1)"
supplyTempMax="$(cat ./chillerPerformanceData | head -n 19 | tail -n 1)"
returnTempMin="$(cat ./chillerPerformanceData | head -n 20 | tail -n 1)"
returnTempMedian="$(cat ./chillerPerformanceData | head -n 21 | tail -n 1)"
returnTempMax="$(cat ./chillerPerformanceData | head -n 22 | tail -n 1)"
deltaTempMin="$(cat ./chillerPerformanceData | head -n 23 | tail -n 1)"
deltaTempMedian="$(cat ./chillerPerformanceData | head -n 24 | tail -n 1)"
deltaTempMax="$(cat ./chillerPerformanceData | head -n 25 | tail -n 1)"

efficiencyData="$(cat ./efficiencyDetailData | head -n 1 | tail -n 1)"
coolingCapacityData="$(cat ./coolingCapacityDetailData | head -n 1 | tail -n 1)"
powerConsumptionData="$(cat ./powerConsumptionDetailData | head -n 1 | tail -n 1)"

returnTempDataNULL=0

if [ -f "./data/tempReturnHours.$gatewayId.$operationDate" ]; then
	returnTempData="$(cat ./data/tempReturnHours.$gatewayId.$operationDate | head -n 1 | tail -n 1)"
	rm ./data/tempReturnHours.$gatewayId.$operationDate
else
	returnTempDataNULL=1
fi

supplyTempDataNULL=0

if [ -f "./data/tempSupplyHours.$gatewayId.$operationDate" ]; then
	supplyTempData="$(cat ./data/tempSupplyHours.$gatewayId.$operationDate | head -n 1 | tail -n 1)"
	rm ./data/tempSupplyHours.$gatewayId.$operationDate
else
	supplyTempDataNULL=1
fi


deltaTempDataNULL=0

if [ -f "./data/tempDeltaHours.$gatewayId.$operationDate" ]; then
	deltaTempData="$(cat ./data/tempDeltaHours.$gatewayId.$operationDate | head -n 1 | tail -n 1)"
	rm ./data/tempDeltaHours.$gatewayId.$operationDate
else
	deltaTempDataNULL=1
fi

if [ "$operationDate" == "" ] || [ "$efficiencyData" == "" ] || [ "$coolingCapacityData" == "" ] || [ "$powerConsumptionData" == "" ] ; then
	echo "[ERROR]replace dailyChillerPerformance "
	exit 0
fi

echo "replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
	  activityCount,activityState,
	  totalOperationMinutes,
	  avgPowerConsumption,
	  totalEnergyConsumption,
	  avgPowerLoading,
	  efficiencyMin,efficiencyMedian,efficiencyMax,
	  coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	  returnTempMin,returnTempMedian,returnTempMax,
	  supplyTempMin,supplyTempMedian,supplyTempMax,
	  deltaTempMin,deltaTempMedian,deltaTempMax,
	  efficiencyData,
	  coolingCapacityData,
	  powerConsumptionData,
	  returnTempData,
      supplyTempData,
	  deltaTempData) 
	VALUES('$operationDate','$siteId','$gatewayId','$chillerId','$chillerDescription',
	  '$activityCount','{$activityState}',
	  '$totalOperationMinutes',
	  '$avgPowerConsumption',
	  '$totalEnergyConsumption',
	  '$avgPowerLoading',
	  '$efficiencyMin','$efficiencyMedian','$efficiencyMax',
	  if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	  if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	  if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	  '$returnTempMin','$returnTempMedian','$returnTempMax',
	  '$supplyTempMin','$supplyTempMedian','$supplyTempMax',
	  '$deltaTempMin','$deltaTempMedian','$deltaTempMax',
	  '{$efficiencyData}',
	  if($coolingCapacityData is NULL,NULL,'{$coolingCapacityData}'),
	  '{$powerConsumptionData}',
	  if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
      if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
	  if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
	);
"

if [ "$activityState" == "0" ]; then
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
	  activityCount,activityState,
	  totalOperationMinutes,
	  avgPowerConsumption,
	  totalEnergyConsumption,
	  avgPowerLoading,
	  efficiencyMin,efficiencyMedian,efficiencyMax,
	  coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	  returnTempMin,returnTempMedian,returnTempMax,
	  supplyTempMin,supplyTempMedian,supplyTempMax,
	  deltaTempMin,deltaTempMedian,deltaTempMax,
	  efficiencyData,
	  coolingCapacityData,
	  powerConsumptionData,
	  returnTempData,
	  supplyTempData,
	  deltaTempData) 
	VALUES('$operationDate','$siteId','$gatewayId','$chillerId','$chillerDescription',
	  '$activityCount','$activityState',
	  '$totalOperationMinutes',
	  '$avgPowerConsumption',
	  '$totalEnergyConsumption',
	  '$avgPowerLoading',
	  '$efficiencyMin','$efficiencyMedian','$efficiencyMax',
	  if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	  if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	  if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	  '$returnTempMin','$returnTempMedian','$returnTempMax',
	  '$supplyTempMin','$supplyTempMedian','$supplyTempMax',
	  '$deltaTempMin','$deltaTempMedian','$deltaTempMax',
	  '{$efficiencyData}',
	  if($coolingCapacityData is NULL,NULL,'{$coolingCapacityData}'),
	  '{$powerConsumptionData}',
	  if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
      if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
	  if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
	);
	"	
else
	mysql -h ${host} -D$dbRPF -ss -e"replace INTO dailyChillerPerformance(operationDate,siteId,gatewayId,chillerId,chillerDescription,
	  activityCount,activityState,
	  totalOperationMinutes,
	  avgPowerConsumption,
	  totalEnergyConsumption,
	  avgPowerLoading,
	  efficiencyMin,efficiencyMedian,efficiencyMax,
	  coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	  returnTempMin,returnTempMedian,returnTempMax,
	  supplyTempMin,supplyTempMedian,supplyTempMax,
	  deltaTempMin,deltaTempMedian,deltaTempMax,
	  efficiencyData,
	  coolingCapacityData,
	  powerConsumptionData,
	  returnTempData,
      supplyTempData,
	  deltaTempData) 
	VALUES('$operationDate','$siteId','$gatewayId','$chillerId','$chillerDescription',
	  '$activityCount','{$activityState}',
	  '$totalOperationMinutes',
	  '$avgPowerConsumption',
	  '$totalEnergyConsumption',
	  '$avgPowerLoading',
	  '$efficiencyMin','$efficiencyMedian','$efficiencyMax',
	  if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	  if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	  if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	  '$returnTempMin','$returnTempMedian','$returnTempMax',
	  '$supplyTempMin','$supplyTempMedian','$supplyTempMax',
	  '$deltaTempMin','$deltaTempMedian','$deltaTempMax',
	  '{$efficiencyData}',
	  if($coolingCapacityData is NULL,NULL,'{$coolingCapacityData}'),
	  '{$powerConsumptionData}',
	  if($returnTempDataNULL = 1,NULL,'{$returnTempData}'),
      if($supplyTempDataNULL = 1,NULL,'{$supplyTempData}'),
	  if($deltaTempDataNULL = 1,NULL,'{$deltaTempData}')
	);
	"
fi

rm ./chillerPerformanceData
rm ./powerConsumptionDetailData
rm ./coolingCapacityDetailData
rm ./efficiencyDetailData

exit 0