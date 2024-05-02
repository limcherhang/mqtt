#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"

deviceInfo=($(mysql -h ${host} -ss -e" 
    SELECT 
	   siteId,name,ieee 
	 FROM 
	   mgmtETL.Device 
	 where 
	   name like 'Power#%'
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
	
    echo "$siteId $name $ieee"

	data=($(mysql -h ${host} -ss -e"
		SELECT 
		  date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts,
		  gatewayId,
		  ch1Watt,ch2Watt,ch3Watt,
		  totalPositiveWattHour,
		  totalNegativeWattHour,
		  ch1Current,
		  ch2Current,
		  ch3Current,
		  ch1Voltage,
		  ch2Voltage,
		  ch3Voltage,
		  ch1PowerFactor,
		  ch2PowerFactor,
		  ch3PowerFactor,
		  voltage12,
		  voltage23,
		  voltage31,
		  ch1Hz,
		  ch2Hz,
		  ch3Hz,
		  i1THD,
		  i2THD,
		  i3THD,
		  v1THD,
		  v2THD,
		  v3THD
		FROM 
			iotmgmt.pm 
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
		
		ch1Watt=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch2Watt=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch3Watt=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		totalPositiveWattHour=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		totalNegativeWattHour=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		
		ch1Current=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch2Current=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch3Current=${data[$dataNum]}
		dataNum=$(($dataNum+1))
	
		ch1Voltage=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch2Voltage=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch3Voltage=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		ch1PowerFactor=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch2PowerFactor=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch3PowerFactor=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		voltage12=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		voltage23=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		voltage31=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		ch1Hz=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch2Hz=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		ch3Hz=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		i1THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		i2THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		i3THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		v1THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		v2THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		v3THD=${data[$dataNum]}
		dataNum=$(($dataNum+1))

		echo "replace into dataETL.power(
			  ts,
			  gatewayId,
			  name,
			  ch1Watt,ch2Watt,ch3Watt,
			  totalPositiveWattHour,
			  totalNegativeWattHour,
			  ch1Current,
			  ch2Current,
			  ch3Current,
			  ch1Voltage,
			  ch2Voltage,
			  ch3Voltage,
			  ch1PowerFactor,
			  ch2PowerFactor,
			  ch3PowerFactor,
			  voltage12,
			  voltage23,
			  voltage31,
			  ch1Hz,
			  ch2Hz,
			  ch3Hz,
			  i1THD,
			  i2THD,
			  i3THD,
			  v1THD,
			  v2THD,
			  v3THD
			) 
			VALUES('$ts1 $ts2','$gatewayId','$name',
				if($ch1Watt is NULL,NULL,'$ch1Watt'),
				if($ch2Watt is NULL,NULL,'$ch2Watt'),
				if($ch3Watt is NULL,NULL,'$ch3Watt'),
				if($totalPositiveWattHour is NULL,NULL,'$totalPositiveWattHour'),
				if($totalNegativeWattHour is NULL,NULL,'$totalNegativeWattHour'),
				if($ch1Current is NULL,NULL,'$ch1Current'),
				if($ch2Current is NULL,NULL,'$ch2Current'),
				if($ch3Current is NULL,NULL,'$ch3Current'),
				if($ch1Voltage is NULL,NULL,'$ch1Voltage'),
				if($ch2Voltage is NULL,NULL,'$ch2Voltage'),
				if($ch3Voltage is NULL,NULL,'$ch3Voltage'),
				if($ch1PowerFactor is NULL,NULL,'$ch1PowerFactor'),
				if($ch2PowerFactor is NULL,NULL,'$ch2PowerFactor'),
				if($ch3PowerFactor is NULL,NULL,'$ch3PowerFactor'),
				if($voltage12 is NULL,NULL,'$voltage12'),
				if($voltage23 is NULL,NULL,'$voltage23'),
				if($voltage31 is NULL,NULL,'$voltage31'),
				if($ch1Hz is NULL,NULL,'$ch1Hz'),
				if($ch2Hz is NULL,NULL,'$ch2Hz'),
				if($ch3Hz is NULL,NULL,'$ch3Hz'),
				if($i1THD is NULL,NULL,'$i1THD'),
				if($i2THD is NULL,NULL,'$i2THD'),
				if($i3THD is NULL,NULL,'$i3THD'),
				if($v1THD is NULL,NULL,'$v1THD'),
				if($v2THD is NULL,NULL,'$v2THD'),
				if($v3THD is NULL,NULL,'$v3THD')
			);
			"
		mysql -h ${host} -ss -e"replace into dataETL.power(
			  ts,
			  gatewayId,
			  name,
			  ch1Watt,ch2Watt,ch3Watt,
			  totalPositiveWattHour,
			  totalNegativeWattHour,
			  ch1Current,
			  ch2Current,
			  ch3Current,
			  ch1Voltage,
			  ch2Voltage,
			  ch3Voltage,
			  ch1PowerFactor,
			  ch2PowerFactor,
			  ch3PowerFactor,
			  voltage12,
			  voltage23,
			  voltage31,
			  ch1Hz,
			  ch2Hz,
			  ch3Hz,
			  i1THD,
			  i2THD,
			  i3THD,
			  v1THD,
			  v2THD,
			  v3THD
			) 
			VALUES('$ts1 $ts2','$gatewayId','$name',
				if($ch1Watt is NULL,NULL,'$ch1Watt'),
				if($ch2Watt is NULL,NULL,'$ch2Watt'),
				if($ch3Watt is NULL,NULL,'$ch3Watt'),
				if($totalPositiveWattHour is NULL,NULL,'$totalPositiveWattHour'),
				if($totalNegativeWattHour is NULL,NULL,'$totalNegativeWattHour'),
				if($ch1Current is NULL,NULL,'$ch1Current'),
				if($ch2Current is NULL,NULL,'$ch2Current'),
				if($ch3Current is NULL,NULL,'$ch3Current'),
				if($ch1Voltage is NULL,NULL,'$ch1Voltage'),
				if($ch2Voltage is NULL,NULL,'$ch2Voltage'),
				if($ch3Voltage is NULL,NULL,'$ch3Voltage'),
				if($ch1PowerFactor is NULL,NULL,'$ch1PowerFactor'),
				if($ch2PowerFactor is NULL,NULL,'$ch2PowerFactor'),
				if($ch3PowerFactor is NULL,NULL,'$ch3PowerFactor'),
				if($voltage12 is NULL,NULL,'$voltage12'),
				if($voltage23 is NULL,NULL,'$voltage23'),
				if($voltage31 is NULL,NULL,'$voltage31'),
				if($ch1Hz is NULL,NULL,'$ch1Hz'),
				if($ch2Hz is NULL,NULL,'$ch2Hz'),
				if($ch3Hz is NULL,NULL,'$ch3Hz'),
				if($i1THD is NULL,NULL,'$i1THD'),
				if($i2THD is NULL,NULL,'$i2THD'),
				if($i3THD is NULL,NULL,'$i3THD'),
				if($v1THD is NULL,NULL,'$v1THD'),
				if($v2THD is NULL,NULL,'$v2THD'),
				if($v3THD is NULL,NULL,'$v3THD')
			);
			"
			
		# mysql -h ${host} -ss -e"replace into dataETL.power(
			  # ts,
			  # gatewayId,
			  # name,
			  # ch1Watt,ch2Watt,ch3Watt,
			  # totalPositiveWattHour,
			  # totalNegativeWattHour,
			  # ch1Current,
			  # ch2Current,
			  # ch3Current,
			  # ch1Voltage,
			  # ch2Voltage,
			  # ch3Voltage,
			  # ch1PowerFactor,
			  # ch2PowerFactor,
			  # ch3PowerFactor,
			  # voltage12,
			  # voltage23,
			  # voltage31,
			  # ch1Hz,
			  # ch2Hz,
			  # ch3Hz,
			  # i1THD,
			  # i2THD,
			  # i3THD,
			  # v1THD,
			  # v2THD,
			  # v3THD
			# ) 
			# VALUES('$ts1 $ts2','$gatewayId','$name',
				# '$ch1Watt',
				# '$ch2Watt',
				# '$ch3Watt',
				# '$totalPositiveWattHour',
				# '$totalNegativeWattHour',
				# '$ch1Current',
				# '$ch2Current',
				# '$ch3Current',
				# '$ch1Voltage',
				# '$ch2Voltage',
				# '$ch3Voltage',
				# '$ch1PowerFactor',
				# '$ch2PowerFactor',
				# '$ch3PowerFactor',
				# '$voltage12',
				# '$voltage23',
				# '$voltage31',
				# '$ch1Hz',
				# '$ch2Hz',
				# '$ch3Hz',
				# '$i1THD',
				# '$i2THD',
				# '$i3THD',
				# '$v1THD',
				# '$v2THD',
				# '$v3THD'
			# );
			# "
	done

done

exit 0
