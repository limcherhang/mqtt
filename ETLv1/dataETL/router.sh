#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"

deviceInfo=($(mysql -h ${host} -ss -e" 
   SELECT 
     siteId,name,ieee,dataTableRaw FROM mgmtETL.vDataETLInfo  
   where 
	name like 'Router#%'
   ;"))

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-1 minutes")
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

	data=($(mysql -h ${host} -ss -e"
		SELECT 
		  date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,
		  gatewayId
		FROM 
			iotmgmt.ain 
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
		
		echo "replace into dataETL.router(
			  ts,
			  gatewayId,
			  name
			) 
			VALUES('$ts1 $ts2','$gatewayId','$name');
			"
			
		mysql -h ${host} -ss -e"replace into dataETL.router(
			  ts,
			  gatewayId,
			  name
			) 
			VALUES('$ts1 $ts2','$gatewayId','$name');
			
			"
	done
	
done

exit 0
