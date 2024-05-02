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
	name like 'Gpio#%'
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


	data=($(mysql -h ${host} -ss -e"
		SELECT 
		  date_format(receivedSync, '%Y-%m-%d %H:%i:%s') as ts,
		  gatewayId,
		  pin0,
		  pin1,
		  pin2,
		  pin3,
		  pin4,
		  pin5,
		  pin6,
		  pin7
		FROM 
			iotmgmt.gpio 
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
			
			pin0=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin1=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin2=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin3=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin4=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin5=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin6=${data[$dataNum]}
			dataNum=$(($dataNum+1))
			pin7=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			echo "replace into dataETL.gpio(
				  ts,
				  gatewayId,
				  name,
				  pin0,
				  pin1,
				  pin2,
				  pin3,
				  pin4,
				  pin5,
				  pin6,
				  pin7
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($pin0 is NULL,NULL,'$pin0'),
					if($pin1 is NULL,NULL,'$pin1'),
					if($pin2 is NULL,NULL,'$pin2'),
					if($pin3 is NULL,NULL,'$pin3'),
					if($pin4 is NULL,NULL,'$pin4'),
					if($pin5 is NULL,NULL,'$pin5'),
					if($pin6 is NULL,NULL,'$pin6'),
					if($pin7 is NULL,NULL,'$pin7')
				);
				"
			mysql -h ${host} -ss -e"replace into dataETL.gpio(
				  ts,
				  gatewayId,
				  name,
				  pin0,
				  pin1,
				  pin2,
				  pin3,
				  pin4,
				  pin5,
				  pin6,
				  pin7
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($pin0 is NULL,NULL,'$pin0'),
					if($pin1 is NULL,NULL,'$pin1'),
					if($pin2 is NULL,NULL,'$pin2'),
					if($pin3 is NULL,NULL,'$pin3'),
					if($pin4 is NULL,NULL,'$pin4'),
					if($pin5 is NULL,NULL,'$pin5'),
					if($pin6 is NULL,NULL,'$pin6'),
					if($pin7 is NULL,NULL,'$pin7')
				);
			"
	done
done

exit 0
