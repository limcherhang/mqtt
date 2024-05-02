#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ]; then
	echo "請輸入bash tmpe.sh 2021-07-01 00:00 2021-07-01 00:01"
	echo "   Start Date"
	echo "   Start Time"
	echo "   End Date"
	echo "   End Time"
	
	exit 1
fi

host="127.0.0.1"

dbProcess="processETL" # processETL.chiller
dbData="dataPlatform"

startRunTime="${1} ${2}"
endRunTime="${3} ${4}"


siteId=10
echo " Site ID : $siteId"
powerName=('power#1' 'power#2' 'power#3' 'power#4')
returnName=('temp#1' 'temp#2' 'temp#3' 'temp#4')
supplyName=('temp#5' 'temp#6' 'temp#7' 'temp#8')
flowName=('flow#2' 'flow#3' 'flow#4' 'flow#5')

arrNum=0
chillerNum=1
while :
do
	if [ $arrNum == 4 ]; then
		break
	fi
	
	powerMainName=${powerName[$arrNum]}
	
	returnMainName=${returnName[$arrNum]}
	supplyMainName=${supplyName[$arrNum]}
	flowMainName=${flowName[$arrNum]}

	echo "  Chiller Power : $powerMainName"
	echo "  Chiller Return : $returnMainName"
	echo "  Chiller Supply : $supplyMainName"
	echo "  Chiller Flow : $flowMainName"
	
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
	echo "powerNULL $powerNULL"
	if [ "$powerNULL" == "NULL" ]; then
		echo "Power Data NULL"
		break
	fi
	
	echo "$powerOn"
	if [ $powerOn == 1 ]; then
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
								 SELECT date_format(ts, '%Y-%m-%d %H:%i') time,flowRate
								  FROM 
									flow
								  WHERE 
									name='$flowMainName' and
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
					('$startRunTime',$siteId,'chiller#$chillerNum','0','0','0');
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

#plant
powerMainName='power#8'
returnMainName='temp#9'
supplyMainName='temp#10'
flowMainName='flow#1'

echo "  Chiller Plant Power : $powerMainName"
echo "  Chiller Plant Return : $returnMainName"
echo "  Chiller Plant Supply : $supplyMainName"
echo "  Chiller Plant Flow : $flowMainName"

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
echo "powerNULL $powerNULL"
if [ "$powerNULL" == "NULL" ]; then
	echo "Power Data NULL"
	break
fi

echo "$powerOn"
if [ $powerOn == 1 ]; then
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
							 SELECT date_format(ts, '%Y-%m-%d %H:%i') time,flowRate
							  FROM 
								flow
							  WHERE 
								name='$flowMainName' and
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
						('$startRunTime','$siteId','chiller#plant','$powerOn','$coolingCapacityData',if($efficiencyData is NULL,NULL,'$efficiencyData'));
					"
				mysql -h ${host} -D$dbProcess -ss -e"replace INTO chiller(ts,siteId,name,opFlag,
						coolingCapacity,
						efficiency)VALUES
						('$startRunTime','$siteId','chiller#plant','$powerOn','$coolingCapacityData',if($efficiencyData is NULL,NULL,'$efficiencyData')); 
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
				('$startRunTime',$siteId,'chiller#plant','0','0','0');
			"
			
	mysql -h ${host} -D$dbProcess -ss -e"replace INTO chiller(ts,siteId,name,
				opFlag,
				coolingCapacity,
				efficiency)VALUES
				('$startRunTime',$siteId,'chiller#plant','0','0','0');
			"		
fi
exit 0
