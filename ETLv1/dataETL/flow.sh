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
	name like 'Flow#%'
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

	if [ "$dataTableRaw" == "flowTMR2RMT" ]; then
	
		data=($(mysql -h ${host} -ss -e"
			SELECT 
				date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,gatewayId,
				flowInstant,
				flowTotalPositive
			FROM 
				iotmgmt.flowTMR2RMT 
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

			flowTotalPositive=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			echo "replace into dataETL.flow(
				  ts,
				  gatewayId,
				  name,
				  flowRate,
				  flowTotalPositive
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($flowRate is NULL,NULL,'$flowRate'),
					if($flowTotalPositive is NULL,NULL,'$flowTotalPositive')
				);
				"
			mysql -h ${host} -ss -e"replace into dataETL.flow(
				  ts,
				  gatewayId,
				  name,
				  flowRate,
				  flowTotalPositive
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($flowRate is NULL,NULL,'$flowRate'),
					if($flowTotalPositive is NULL,NULL,'$flowTotalPositive')
				);
				"
		done

	fi
done

exit 0
