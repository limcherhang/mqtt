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
	name like 'ThreeInOne#%' and siteId=65
   ;"))

# startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")
# endRunTime=$(date "+%Y-%m-%d %H:%M:00")
startRunTime="2023-05-13 14:06:00"
endRunTime="2023-05-15 10:18:10"

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
			round(temp,2) as temperature,
			round(humidity,2) as humid,
		co2ppm
			FROM 
			iotdata2023.co2_05
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
			
			co2=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			
			echo "replace into dataETL2023.threeInOne_05(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  humidity,
				  co2
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp is NULL,NULL,'$temp'),
					if($humidity is NULL,NULL,'$humidity'),
					if($co2 is NULL,NULL,'$co2')
				);
				"
				
			mysql -h ${host} -ss -e"replace into dataETL2023.threeInOne_05(
				  ts,
				  gatewayId,
				  name,
				  temp,
				  humidity,
				  co2
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp is NULL,NULL,'$temp'),
					if($humidity is NULL,NULL,'$humidity'),
					if($co2 is NULL,NULL,'$co2')
				);
			"
		done
	fi
done

exit 0
