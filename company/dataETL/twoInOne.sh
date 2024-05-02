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
	name like 'TwoInOne#%'
   ;"))

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-3 minutes")
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

	if [ "$dataTableRaw" == "co2" ]; then
	

	data=($(mysql -h ${host} -ss -e"
		SELECT 
			date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,gatewayId,
			round(((temp*10/65535)*175)-45,2) as temperature,
			round((humidity*10/65535)*100,2) as humid
		FROM 
			iotmgmt.co2 
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

			humidity=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			echo "replace into dataETL.twoInOne(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  humidity
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp is NULL,NULL,'$temp'),
					if($humidity is NULL,NULL,'$humidity')
				);
				"
			mysql -h ${host} -ss -e"replace into dataETL.twoInOne(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  humidity
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp is NULL,NULL,'$temp'),
					if($humidity is NULL,NULL,'$humidity')
				);
				"
		done
	fi
done

exit 0
