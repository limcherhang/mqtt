#!/bin/bash
# Program: 時間區間 一次一筆，請勿超過1分鐘
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbMgmt="iotmgmt"
dbdataETL="dataETL"
dbdataPlatform="dataPlatform"

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-3 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")


PowerName=("power#1" "power#2" "power#3" "power#4")
TempReturnName=("temp#1" "temp#2" "temp#3" "temp#4")
TempSupplyName=("temp#5" "temp#6" "temp#7" "temp#8")

returnConut=0
supplyConut=0

returnTempData=0
supplyTempData=0

whileNum=0
while :
do
	if [ "${PowerName[$whileNum]}" == "" ]; then
	 break
	fi
	

	stauts=($(mysql -h ${host} -ss -e" 
		SELECT sum(IF(powerConsumed>0,1,0)) as PowerNum FROM dataPlatform.power 
		where 
			siteId=10 and 
			ts >='$startRunTime' and 
			ts < '$endRunTime' and
			name = '${PowerName[$whileNum]}'
	;"))
	
	if [ "$stauts" == "" ]; then
	  echo "${PowerName[$whileNum]} Data NULL"
	  exit 0
	fi
	
	echo "${PowerName[$whileNum]} ON/OFF $stauts"
	
	if [ $stauts == 1 ]; then
		returnTempData=($(mysql -h ${host} -ss -e" 
			SELECT $returnTempData+temp FROM dataPlatform.temp 
			where 
				siteId=10 and 
				ts >='$startRunTime' and 
				ts < '$endRunTime' and
				name = '${TempReturnName[$whileNum]}'
		;"))
		
		echo "${TempReturnName[$whileNum]} Temp $returnTempData"
		returnConut=$(($returnConut+1))
	fi
	
	if [ $stauts == 1 ]; then
		supplyTempData=($(mysql -h ${host} -ss -e" 
			SELECT $supplyTempData+temp FROM dataPlatform.temp 
			where 
				siteId=10 and 
				ts >='$startRunTime' and 
				ts < '$endRunTime' and
				name = '${TempSupplyName[$whileNum]}'
		;"))
		
		supplyConut=$(($supplyConut+1))
		
		echo "${TempSupplyName[$whileNum]} Temp $supplyTempData"
	fi
	
	
	whileNum=$(($whileNum+1))
done


echo "replace INTO dataPlatform.temp (ts, siteId, name, temp) 
SELECT '$startRunTime',10,'temp#9',round($returnTempData/$returnConut,2) as temp
		FROM 
			dataPlatform.temp where 
			ts >='$startRunTime' and 
			ts < '$endRunTime' and siteId=10 and
			name = 'temp#10' limit 1;"
			
mysql -h ${host} -ss -e"replace INTO dataPlatform.temp (ts, siteId, name, temp) 
SELECT '$startRunTime',10,'temp#9',round($returnTempData/$returnConut,2) as temp
		FROM 
			dataPlatform.temp where 
			ts >='$startRunTime' and 
			ts < '$endRunTime' and siteId=10 and
			name = 'temp#10' limit 1;"
			
echo "replace INTO dataPlatform.temp (ts, siteId, name, temp) 
SELECT '$startRunTime',10,'temp#10',round($supplyTempData/$supplyConut,2) as temp
		FROM 
			dataPlatform.temp where 
			ts >='$startRunTime' and 
			ts < '$endRunTime' and siteId=10 and
			name = 'temp#10' limit 1;"

mysql -h ${host} -ss -e"replace INTO dataPlatform.temp (ts, siteId, name, temp) 
SELECT '$startRunTime',10,'temp#10',round($supplyTempData/$supplyConut,2) as temp
		FROM 
			dataPlatform.temp where 
			ts >='$startRunTime' and 
			ts < '$endRunTime' and siteId=10 and
			name = 'temp#10' limit 1;"
			
exit 0
