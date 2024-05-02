#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
#connectDB
host="127.0.0.1"             

dbMgmt="iotmgmt"
dbdataETL="dataETL"
#語法
deviceInfo=($(mysql -h ${host} -ss -e"     
   SELECT name,ieee FROM 
	mgmtETL.vDataETLInfo  
   where 
	name like 'Ammonia#%'
   ;"))
#時間
startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

whileNum=0
while :
do
	if [ "${deviceInfo[$whileNum]}" == "" ]; then
	 break
	fi

    name=${deviceInfo[$whileNum]} #0
	whileNum=$(($whileNum+1))
	
    ieee=${deviceInfo[$whileNum]} #1
	whileNum=$(($whileNum+1))

    echo "$name $ieee"
#第二次SQL
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
	
		receivedSync1=${data[$dataNum]} #變數名稱，值0 
		dataNum=$(($dataNum+1)) #運算式
		receivedSync2=${data[$dataNum]} #1
		dataNum=$(($dataNum+1))	
		
		gatewayId=${data[$dataNum]}	# 2
		dataNum=$(($dataNum+1))
		
		ieee=${data[$dataNum]} #3
		dataNum=$(($dataNum+1))
		
		ammonia=${data[$dataNum]} #4
		dataNum=$(($dataNum+1))
		#顯示
		echo "replace into dataETL.ammonia (ts,gatewayId,name,NH3) 
			VALUES('$receivedSync1 $receivedSync2','$gatewayId','$name','$ammonia');"
			
		if [ "$ammonia" == "" ]; then
			echo "$(date "+%Y-%m-%d %H:%M:00") [ERROR] no data  "
		#執行
		else
			mysql -h ${host} -D$dbMgmt -ss -e"replace into dataETL.ammonia (ts,gatewayId,name,NH3) 
			VALUES('$receivedSync1 $receivedSync2','$gatewayId','$name','$ammonia');
			"
		fi
	done

done

exit 0	

