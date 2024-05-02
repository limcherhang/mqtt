#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="dataPlatform"


startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-60 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00")

echo "Replace into dataPlatform.power(ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current,energyConsumed)
		SELECT a.ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current,Consumed
		FROM
			(
				SELECT ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current
				   FROM dataPlatform.power 
				   where 
					 siteId=45 and 
					 name = 'power#57' and 
					 ts >= '$startRunTime' and 
					 ts < '$endRunTime' and 
					 energyConsumed is NULL
			) as a,
			(
				SELECT ts,sum(energyConsumed) as Consumed
				   FROM dataPlatform.power 
				   where 
					 siteId=45 and 
					 name = 'power#58' or name = 'power#59' or name = 'power#60' or name = 'power#61' 
				   group by ts
			) as b
		where a.ts=b.ts
	;"
	
mysql -h ${host} -ss -e"Replace into dataPlatform.power(ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current,energyConsumed)
		SELECT a.ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current,Consumed
		FROM
			(
				SELECT ts,siteId,name,ch1Watt,ch2Watt,ch3Watt,powerConsumed,ch1Current,ch2Current,ch3Current
				   FROM dataPlatform.power 
				   where 
					 siteId=45 and 
					 name = 'power#57' and 
					 ts >= '$startRunTime' and 
					 ts < '$endRunTime' and 
					 energyConsumed is NULL
			) as a,
			(
				SELECT ts,sum(energyConsumed) as Consumed
				   FROM dataPlatform.power 
				   where 
					 siteId=45 and 
					 name = 'power#58' or name = 'power#59' or name = 'power#60' or name = 'power#61' 
				   group by ts
			) as b
		where a.ts=b.ts
	;"
	


exit 0
