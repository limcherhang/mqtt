#!/bin/bash
# Program:
# 計算Power#8
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbdataPlatform="dataPlatform"

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-5 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")
#startRunTime="2023-04-01 00:00:00"
#endRunTime="2023-04-05 00:00:00"


echo "
	REPLACE INTO dataPlatform.power (ts, siteId, name, ch1Watt, ch2Watt, ch3Watt, powerConsumed,energyConsumed) 
SELECT ts,10,\"power#8\",sum(ch1Watt),sum(ch2Watt),sum(ch3Watt),round(sum(powerConsumed),2),round(sum(energyConsumed),2) 
FROM dataPlatform.power 
where siteId=10 and name in ('power#1','power#2','power#3','power#4') ts>'$startRunTime' and ts <'$endRunTime' group by ts;
;"

mysql -h ${host} -ss -e"
	REPLACE INTO dataPlatform.power (ts, siteId, name, ch1Watt, ch2Watt, ch3Watt, powerConsumed,energyConsumed) 
SELECT ts,10,\"power#8\",sum(ch1Watt),sum(ch2Watt),sum(ch3Watt),round(sum(powerConsumed),2),round(sum(energyConsumed),2) 
FROM dataPlatform.power 
where siteId=10 and ts>'$startRunTime' and ts <'$endRunTime' and name in ('power#1','power#2','power#3','power#4') group by ts;
;"
   


exit 0
