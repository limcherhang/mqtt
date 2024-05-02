#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"

dbProcess="processETL" # processETL.chiller
dbData="dataPlatform"

startRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-3 minutes")
endRunTime=$(date "+%Y-%m-%d %H:%M:00" --date="-2 minutes")

siteId=72
echo " Site ID : $siteId"
powerName=('power#1' 'power#2')
returnName=('temp#1' 'temp#5')
supplyName=('temp#2' 'temp#6')

arrNum=0
chillerNum=1
while :
do
	if [ $arrNum == 2 ]; then
		break
	fi

	powerMainName=${powerName[$arrNum]}
	
	returnMainName=${returnName[$arrNum]}
	supplyMainName=${supplyName[$arrNum]}


	echo "  Chiller Power : $powerMainName"
	echo "  Chiller Return : $returnMainName"
	echo "  Chiller Supply : $supplyMainName"
	
	
	powerOn=($(mysql -h ${host} -D$dbData -ss -e"SELECT count(*)
		   FROM dataPlatform.power
		   where 
			 siteId=$siteId and name='$powerMainName' and ts>='$startRunTime' and ts< '$endRunTime' and powerConsumed > 10;
	"))
	
	powerNULL=($(mysql -h ${host} -D$dbData -ss -e"SELECT *
		   FROM dataPlatform.power
		   where 
			 siteId=$siteId and name='$powerMainName' and ts>='$startRunTime' and ts< '$endRunTime';
	"))
	
	if [ "$powerNULL" == "NULL" ]; then
		echo "Power Data NULL"
		break
	fi
	
	echo "$powerOn"
	if [ $powerOn == 1 ]; then
		flowCount=($(mysql -h ${host} -D$dbData -ss -e"SELECT count(*)
		   FROM dataPlatform.power
		   where 
			 siteId=$siteId and 
			 (name='power#2' or name='power#1') and 
			 ts>='$startRunTime' and ts< '$endRunTime' 
			 and powerConsumed > 10;
		"))
		
		#coolingCapacity
		coolingCapacityData=($(mysql -h ${host} -D$dbData -ss -e"select 
								  Round((977*4.2*(truncate(tempReturn-tempSupply,2))*truncate(flowRate,2))/12660.66,3),#3600*3.51685 =12660.66
								  Round(tempReturn-tempSupply,2) as delta,
								  tempReturn,
								  tempSupply,
								  flowRate
								FROM
								(
								SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
									 FROM 
										temp
									  WHERE 
										name='$supplyMainName' and 
										siteId=$siteId and
										ts >='$startRunTime' and 
										ts < '$endRunTime'
								) as a

								INNER join
								(
									SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn
									 FROM 
										temp
									  WHERE 
										name='$returnMainName' and 
										siteId=$siteId and
										ts >='$startRunTime' and 
										ts < '$endRunTime'
								) as b
								on a.time=b.time

								INNER join
								(
								 SELECT date_format(ts, '%Y-%m-%d %H:%i') time,truncate(flowRate/$flowCount,2) as flowRate
								  FROM 
									flow
								  WHERE 
									name='flow#1' and
									siteId=$siteId and
									ts >='$startRunTime' and 
									ts < '$endRunTime'
									group by time
								) as c
								on a.time=c.time;
			"))
			
		if [ "$coolingCapacityData" == "NULL" ]; then
			echo "Cooling Capacity Data NULL"
			break
		fi	
		efficiencyData=($(mysql -h ${host} -D$dbData -ss -e"SELECT 
				powerConsumed/$coolingCapacityData
			  FROM
				 power
			  where 
				siteId=$siteId and 
				name='$powerMainName' and 
				ts>='$startRunTime' and 
				ts< '$endRunTime'
				;"))
				
			
			echo "flowCount $flowCount"
			echo "opFlag $powerOn"
			echo "Cooling Capacity $coolingCapacityData"
			echo "Efficiency Data $efficiencyData"
			if [ "$efficiencyData" == "" ]; then
				echo "efficiency = NULL"
			else
				
				
				if [ "$coolingCapacityData" != "NULL" ]; then
					echo "replace INTO chiller(ts,siteId,name,opFlag,
							coolingCapacity,
							efficiency)VALUES
							('$startRunTime','$siteId','chiller#$chillerNum','$powerOn','$coolingCapacityData',if($efficiencyData is NULL,NULL,'$efficiencyData'));
						"
					mysql -h ${host} -D$dbProcess -ss -e"replace INTO chiller(ts,siteId,name,opFlag,
							coolingCapacity,
							efficiency)VALUES
							('$startRunTime','$siteId','chiller#$chillerNum','$powerOn','$coolingCapacityData',if($efficiencyData is NULL,NULL,'$efficiencyData')); 
					"
				else
					echo " coolingCapacity == NULL"
				fi
				
			fi	
	else
	
		echo "replace INTO chiller(ts,siteId,name,
					opFlag,
					coolingCapacity,
					efficiency)VALUES
					('$startRunTime',$siteId,'chiller#$chillerNum','0','0','0';
				"
				
		mysql -h ${host} -D$dbProcess -ss -e"replace INTO chiller(ts,siteId,name,
					opFlag,
					coolingCapacity,
					efficiency)VALUES
					('$startRunTime',$siteId,'chiller#$chillerNum','0','0','0');
				"
	fi
	chillerNum=$(($chillerNum+1))
	arrNum=$(($arrNum+1))

done

		
exit 0
