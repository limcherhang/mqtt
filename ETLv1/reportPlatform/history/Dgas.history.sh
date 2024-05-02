#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH


local="192.168.6.50"
dbSchemas="reportPlatform2023"

day=1

while :
do

	if [ $day == 16 ]; then
		 break
	fi
	
	dayend=$(($day+1))
	
	mysql -h ${local} -D$dbSchemas -ss -e"REPLACE INTO reportPlatform2023.Dgas (date,siteId,name,gasConsumptionInm3,totalInm3,gasConsumptionInmmBTU,totalInmmBTU) 
	SELECT date_format(ts, '%Y-%m-%d') as date,siteId,name,max(gasConsumedInm3) as gasConsumptionInm3,Max(gasInm3) as totalInm3,Max(gasConsumedInmmBTU) as gasConsumptionInmmBTU,max(gasInmmBTU) as totalInmmBTU 
	FROM dataPlatform2023.gas_03 where ts>='2023-03-$day 00:00' and ts<'2023-03-$dayend 00:00' group by name
	;"
	
	day=$(($day+1))
done
exit 0
