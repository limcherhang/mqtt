#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"

deviceInfo=($(mysql -h ${host} -ss -e" 
   SELECT siteId,name,ieee,dataTableRaw FROM 
	mgmtETL.vDataETLInfo  
   where 
	name like 'WaterQuality#%'
   ;"))

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

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

	if [ "$dataTableRaw" == "waterQuality" ]; then
	
			data=($(mysql -h ${host} -ss -e"
			SELECT 
				date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,gatewayId,
				  temperature,
				  ph,
				  oxidationReductionPotential,
				  totalDissovedSolids,
				  electricConductivity,
				  electricResistivity,
				  liquidLevel
			FROM 
				iotmgmt.waterQuality 
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
			
			temp=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			ph=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			#oxidationReductionPotential
			ORP=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			#totalDissovedSolids
			TDS=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			#electricConductivity
			EC=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			#electricResistivity
			ER=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			liquidLevel=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			echo "replace into dataETL.waterQuality(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  ph,
				  ORP,
				  TDS,
				  EC,
				  ER,
				  liquidLevel
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
				  if($temp is NULL,NULL,'$temp'),
				  if($ph is NULL,NULL,'$ph'),
				  if($ORP is NULL,NULL,'$ORP'),
				  if($TDS is NULL,NULL,'$TDS'),
				  if($EC is NULL,NULL,'$EC'),
				  if($ER is NULL,NULL,'$ER'),
				  if($liquidLevel is NULL,NULL,'$liquidLevel')
				);
				"
				
			mysql -h ${host} -ss -e"replace into dataETL.waterQuality(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  ph,
				  ORP,
				  TDS,
				  EC,
				  ER,
				  liquidLevel
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
				  if($temp is NULL,NULL,'$temp'),
				  if($ph is NULL,NULL,'$ph'),
				  if($ORP is NULL,NULL,'$ORP'),
				  if($TDS is NULL,NULL,'$TDS'),
				  if($EC is NULL,NULL,'$EC'),
				  if($ER is NULL,NULL,'$ER'),
				  if($liquidLevel is NULL,NULL,'$liquidLevel')
				);
				"
			
		done
	fi
done

exit 0
