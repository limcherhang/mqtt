#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"

deviceInfo=($(mysql -h ${host} -ss -e" 
   SELECT siteId,name,ieee,dataTableRaw FROM 
	mgmtETL.vDeviceInfo  
   where 
	name like 'FlowU#%' and siteId=10
   ;"))

# startRunTime=$(date "+%Y-%m-%d 00:00:00")
# endRunTime=$(date "+%Y-%m-%d %H:%M:00")
startRunTime="2023-04-01 00:00:00"
endRunTime="2023-04-05 00:00:00"

whileNum=0
while :
do
	if [ "${deviceInfo[$whileNum]}" == "" ]; then
	 break
	fi
	
	siteId=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))
	
    name=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))
	
    ieee=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))
	
	dataTableRaw=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))
	
    echo "$siteId $name $ieee $dataTableRaw"

	if [ "$dataTableRaw" == "ultrasonicFlow2" ]; then
	
			data=($(mysql -h ${host} -ss -e"
			SELECT 
				date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,gatewayId,
				  flowRate,
				  velocity,
				  netAccumulator,
				  temp1Inlet,
				  temp2Outlet,
				  errorCode,
				  signalQuality,
				  upstreamStrength,
				  downstreamStrength,
				  calcRateMeasTravelTime,
				  reynoldsNumber,
				  pipeReynoldsFactor,
				  totalWorkingTime,
				  totalPowerOnOffTime
			FROM 
				iotdata2023.ultrasonicFlow2_04
			where 
			 ieee='$ieee' and
			 receivedSync>='$startRunTime' and 
			 receivedSync<'$endRunTime'
	   ;"))
   

		dataNum=0
		while :
		do
			if [ "${data[$dataNum]}" == "" ]; then
			 break
			fi
			
			ts1=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			ts2=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			gatewayId=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			flowRate=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			velocity=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			netAccumulator=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			temp1Inlet=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			temp2Outlet=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			errorCode=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			signalQuality=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			upstreamStrength=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			downstreamStrength=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			calcRateMeasTravelTime=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			reynoldsNumber=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			pipeReynoldsFactor=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			totalWorkingTime=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			totalPowerOnOffTime=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			echo "replace into dataETL2023.flowU_04(
				  ts,
				  gatewayId,
				  name,
				  flowRate,
				  velocity,
				  netAccumulator,
				  temp1Inlet,
				  temp2Outlet,
				  errorCode,
				  signalQuality,
				  upstreamStrength,
				  downstreamStrength,
				  calcRateMeasTravelTime,
				  reynoldsNumber,
				  pipeReynoldsFactor,
				  totalWorkingTime,
				  totalPowerOnOffTime
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					'$flowRate',
				  '$velocity',
				  '$netAccumulator',
				  '$temp1Inlet',
				  '$temp2Outlet',
				  '$errorCode',
				  '$signalQuality',
				  '$upstreamStrength',
				  '$downstreamStrength',
				  '$calcRateMeasTravelTime',
				  '$reynoldsNumber',
				  '$pipeReynoldsFactor',
				  '$totalWorkingTime',
				  '$totalPowerOnOffTime'
				);
				"
				
			mysql -h ${host} -ss -e"replace into dataETL2023.flowU_04(
				  ts,
				  gatewayId,
				  name,
				  flowRate,
				  velocity,
				  netAccumulator,
				  temp1Inlet,
				  temp2Outlet,
				  errorCode,
				  signalQuality,
				  upstreamStrength,
				  downstreamStrength,
				  calcRateMeasTravelTime,
				  reynoldsNumber,
				  pipeReynoldsFactor,
				  totalWorkingTime,
				  totalPowerOnOffTime
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					'$flowRate',
				  '$velocity',
				  '$netAccumulator',
				  '$temp1Inlet',
				  '$temp2Outlet',
				  '$errorCode',
				  '$signalQuality',
				  '$upstreamStrength',
				  '$downstreamStrength',
				  '$calcRateMeasTravelTime',
				  '$reynoldsNumber',
				  '$pipeReynoldsFactor',
				  '$totalWorkingTime',
				  '$totalPowerOnOffTime'
				);
				"
			
		done
	fi
done

exit 0
