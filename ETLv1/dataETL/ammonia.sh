#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"

deviceInfo=($(mysql -h ${host} -ss -e" 
   SELECT name,ieee FROM 
	mgmtETL.vDataETLInfo  
   where 
	name like 'Ammonia#%'
   ;"))

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

whileNum=0
while :
do
	if [ "${deviceInfo[$whileNum]}" == "" ]; then
	 break
	fi

    name=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))
	
    ieee=${deviceInfo[$whileNum]}
	whileNum=$(($whileNum+1))

    echo "$name $ieee"

	data=($(mysql -h ${host} -ss -e"select 
			date_format(receivedSync, '%Y-%m-%d %H:%i')as time,gatewayId,ieee,conv(00h,16,10)/10 as ammonia
		from
		(
			SELECT   
			  receivedSync,gatewayId,ieee,modbusCmd,responseData, 
			  substring(responseData,7,4) as 00h
		FROM 
			iotmgmt.zigbeeRawModbus

		where ieee='$ieee' and
		   ts>='$startRunTime' and 
		   ts<'$endRunTime' and
		   modbusCmd='01030000000305cb'
	) as a
	;"))
	
	dataNum=0
	while :
	do
		if [ "${data[$dataNum]}" == "" ]; then
		 break
		fi
	
		receivedSync1=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		receivedSync2=${data[$dataNum]}
		dataNum=$(($dataNum+1))	
		
		gatewayId=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		ieee=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		ammonia=${data[$dataNum]}
		dataNum=$(($dataNum+1))
	
		echo "replace into dataETL.ammonia (ts,gatewayId,name,NH3) 
			VALUES('$receivedSync1 $receivedSync2','$gatewayId','$name','$ammonia');"
			
		if [ "$ammonia" == "" ]; then
			echo "$(date "+%Y-%m-%d %H:%M:00") [ERROR] no data  "
		else
			mysql -h ${host} -D$dbMgmt -ss -e"replace into dataETL.ammonia (ts,gatewayId,name,NH3) 
			VALUES('$receivedSync1 $receivedSync2','$gatewayId','$name','$ammonia');
			"
		fi
	done

done

exit 0	

