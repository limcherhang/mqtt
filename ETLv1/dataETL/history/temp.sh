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
	name like 'Temp#%' and deviceGId=110
   ;"))

# startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-5 minutes")
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

	if [ "$dataTableRaw" == "dTemperature" ]; then
	

	data=($(mysql -h ${host} -ss -e"
		SELECT 
		  date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,
		  gatewayId,
		  temp1,
		  temp2,
		  temp3,
		  temp4
		FROM 
			#iotmgmt.dTemperature 
			iotdata2023.dTemperature_04
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
			
			temp1=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			temp2=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			temp3=${data[$dataNum]}
			dataNum=$(($dataNum+1))

			temp4=${data[$dataNum]}
			dataNum=$(($dataNum+1))


			echo "replace into dataETL2023.temp_04(
				  ts,
				  gatewayId,
				  name,
				  temp1,
				  temp2,
				  temp3,
				  temp4
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp1 is NULL,NULL,'$temp1'),
					if($temp2 is NULL,NULL,'$temp2'),
					if($temp3 is NULL,NULL,'$temp3'),
					if($temp4 is NULL,NULL,'$temp4')
				);
				"
			mysql -h ${host} -ss -e"replace into dataETL2023.temp_04(
				  ts,
				  gatewayId,
				  name,
				  temp1,
				  temp2,
				  temp3,
				  temp4
				) 
				VALUES('$ts1 $ts2','$gatewayId','$name',
					if($temp1 is NULL,NULL,'$temp1'),
					if($temp2 is NULL,NULL,'$temp2'),
					if($temp3 is NULL,NULL,'$temp3'),
					if($temp4 is NULL,NULL,'$temp4')
				);
				"
		done
	fi
done

exit 0
