#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00 gatewayId"
        exit 1
fi

host=127.0.0.1

reportPlatform="reportplatform"
dbRPF="reportplatform"
dbRPF2021="reportPlatform2021"

siteId=${1}

startDay=${2}
startTime=${3}

endDay=${4}
endTime=${5}

gatewayId=${6}
gId=${6}


today=$(date "+%Y-%m-%d" --date="-1 day")
year=$(date "+%Y" --date="-1 day")

if [ $startDay == $today ]; then

	dbPlatform="dataPlatform"
	tbPower="power"
	tbTemp="temp"
	dbProcess="processETL"
	tbChiller="chiller"
else

	dbdataYear=$(date +%Y -d "$startDay")
	dbdataMonth=$(date +%m -d "$startDay")
	
	dbPlatform="dataPlatform$dbdataYear"
	tbPower="power_$dbdataMonth"
	tbTemp="temp_$dbdataMonth"
	
	dbProcess="processETL$dbdataYear"
	tbChiller="chiller_$dbdataMonth"
fi

programStTime=$(date "+%Y-%m-%d %H:%M:%S")
echo "$programStTime Start Program: Run Chiller Site Id $siteId Performance"

#value defined
totalEnergyConsumption=0
totalRunMinutes=0
dataKWCount=0
dataKWTotal=0
powerLoading=0
avgPowerLoading=NULL

FirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
ThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))

echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp"
echo "*************************************************************************************************"

echo " "
echo "#***********************#"
echo "#Daily Plant Performance#"
echo "#***********************#"
echo " "

chillerNameList=("NULL" "power#1" "power#2")


totalEnergyConsumption=($(mysql -h ${host} -D$dbPlatform -ss -e"select
		round(avg(powerConsumed)*24,3) as TotalKWatt
	  FROM $tbPower
		  WHERE 
		  siteId='$siteId' and
		  name='power#9' and 
		  ts >= '$startDay $startTime ' and 
		  ts <= '$endDay $endTime'
	"))	

echo ""
echo "  Total Energy Consumption:$totalEnergyConsumption"

#utilization
TotalPossible=8

utilization=($(mysql -h ${host} -D$dbRPF -ss -e"
    SELECT Round((sum(operationMinutes)/60)/($TotalPossible*24)*100,2)  
	FROM(
    SELECT chillerDescription,operationMinutes 
	   FROM reportplatform.dailyChillerData
		WHERE 
		   operationDate='$startDay' and 
		   operationFlag=1 and 
		   siteId = $siteId
	union
	SELECT 
	    coolingDescription,operationMinutes 
	  FROM 
	     reportplatform.dailyCoolingData
	  WHERE 
		operationDate='$startDay' and 
		operationFlag=1 and 
		siteId = $siteId
	union
	SELECT 
	    pumpDescription,operationMinutes 
	  FROM 
	     reportplatform.dailyPumpData
	  WHERE 
		operationDate='$startDay' and 
		operationFlag=1 and 
		siteId = $siteId
	union
	SELECT 
	    description,operationMinutes 
	  FROM 
	     reportplatform.dailyChillerPumpCoolingData
	  WHERE 
		operationDate='$startDay' and 
		operationFlag=1 and 
		siteId = $siteId
	) as a
"))

if [ "$utilization" == "NULL" ]; then
	utilization=0
	echo "[ERROR]utilization is NULL"
fi

echo "[DEBUG]Utilization $utilization"

echo ""
#Energy Distribution
totalEnergyConsumptionNum=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT sum(kWh) FROM(
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerData
		WHERE operationDate='$startDay' and operationFlag=1 and siteId = $siteId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and siteId = $siteId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyPumpData
		WHERE operationDate='$startDay' and operationFlag=1 and siteId = $siteId
	union
	SELECT Round(IFNULL(totalPowerWh,0)/1000,2)  kWh FROM reportplatform.dailyChillerPumpCoolingData
		WHERE operationDate='$startDay' and operationFlag=1 and siteId = $siteId
) as a
"))	

energyDistributionNum=0

if [ -f "./buf/energyDistributionJson" ]; then
	rm ./buf/energyDistributionJson
fi

arrNum=1
jsonNum=0
chillerNum=3
while :
do
	if [ $arrNum == $chillerNum ]; then
	 break
	fi
	

	data=($(mysql -h ${host} -D$dbRPF -ss -e"
	  SELECT 
	     Round(((Round(IFNULL(sum(totalPowerWh),0)/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
	   FROM 
	      reportplatform.dailyChillerData  
		WHERE 
		  operationDate='$startDay' and 
		  operationFlag=1 and 
		  siteId = $siteId and 
		  chillerId='$arrNum'
	"))
	
	
	echo "[DEBUG] chillerId='$arrNum' $data"
	jsonNum=$(($jsonNum+1))
				  #>=
	if [ $jsonNum -ge 2 ]; then
		printf ",">> ./buf/energyDistributionJson
	fi
	
	if [ "${data[1]}" != "NULL" ]; then
		printf "\"chiller#%d\": {\"data\": %.2f}" $arrNum $data  >> ./buf/energyDistributionJson
		
		echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum
		energyDistributionNum="$(cat ./buf/energyDistributionNum | head -n 1 | tail -n 1)"
	else
		printf "\"chiller#%d\": {\"data\": %.2f}" $arrNum 0 >> ./buf/energyDistributionJson
	fi

	arrNum=$(($arrNum+1))
done

#Chiller Pump Data
pumpTotal=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT 
            Round(sum(IFNULL(totalPowerWh,0))/1000,2)
		FROM 
		    reportplatform.dailyPumpData
		WHERE 
		    operationDate='$startDay' and 
			operationFlag=1 and 
			siteId = $siteId
	"))
if [ "$pumpTotal" != "NULL" ]; then
	echo "SELECT 
          Round((($pumpTotal+(Round(sum(IFNULL(totalPowerWh,0))/1000,2)))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM 
		    reportplatform.dailyChillerPumpCoolingData
		WHERE 
		    operationDate='$startDay' and 
			operationFlag=1 and 
			siteId = $siteId"
	data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT 
          Round((($pumpTotal+(Round(sum(IFNULL(totalPowerWh,0))/1000,2)))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM 
		    reportplatform.dailyChillerPumpCoolingData
		WHERE 
		    operationDate='$startDay' and 
			operationFlag=1 and 
			siteId = $siteId
	"))
else
	data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT 
         Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM 
		    reportplatform.dailyChillerPumpCoolingData
		WHERE 
		    operationDate='$startDay' and 
			operationFlag=1 and 
			siteId = $siteId
	"))
fi

jsonNum=$(($jsonNum+1))

			  #>=
if [ $jsonNum -ge 2 ]; then
	printf ",">> ./buf/energyDistributionJson
fi

if [ "$data" != "NULL" ]; then
	printf "\"Pumps\": {\"data\": %.2f}" $data >> ./buf/energyDistributionJson
	
	echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum
	energyDistributionNum="$(cat ./buf/energyDistributionNum | head -n 1 | tail -n 1)"
else
	printf "\"Pumps\": {\"data\": 0}" >> ./buf/energyDistributionJson
fi

#CT
data=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT Round(((Round(sum(IFNULL(totalPowerWh,0))/1000,2))/$totalEnergyConsumptionNum)*100,2) as kWh 
		FROM reportplatform.dailyCoolingData  
			WHERE operationDate='$startDay' and operationFlag=1 and siteId = $siteId
	"))
jsonNum=$(($jsonNum+1))

			  #>=
if [ $jsonNum -ge 2 ]; then
	printf ",">> ./buf/energyDistributionJson
fi

if [ "$data" != "NULL" ]; then
	printf "\"CoolingTowers\": {\"data\": %.2f}" $data >> ./buf/energyDistributionJson
	
	echo "scale=3;$energyDistributionNum+$data"|bc > ./buf/energyDistributionNum
	energyDistributionNum="$(cat ./buf/energyDistributionNum.$startDay.$gId | head -n 1 | tail -n 1)"
else
	printf "\"CoolingTowers\": {\"data\": 0}" >> ./buf/energyDistributionJson
fi


energyDistributionData="$(cat ./buf/energyDistributionJson | head -n 1 | tail -n 1)"

if [ -f "./buf/energyDistributionJson" ]; then
	rm ./buf/energyDistributionJson
	echo "[DEBUG]Energy Distribution Data $energyDistributionNum %"
	echo "[DEBUG]$energyDistributionData"
fi
echo " "
echo "#**********#"
echo "#Efficiency#"
echo "#**********#"
echo " "
whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/kW.$whileHour" ]; then
		rm ./buf/kW.$whileHour
		echo "rm ./buf/kW"
	fi
	
	if [ -f "./buf/coolingCapacity.$whileHour" ]; then
		rm ./buf/coolingCapacity.$whileHour
		echo "rm ./buf/coolingCapacity.$whileHour"
	fi
	
	if [ -f "./buf/efficiency.$whileHour" ]; then
		rm ./buf/efficiency.$whileHour
		echo "rm ./buf/efficiency.$whileHour"
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/kW" ]; then
	rm ./buf/kW
fi

if [ -f "./buf/coolingCapacity" ]; then
	rm ./buf/coolingCapacity
fi

if [ -f "./buf/efficiency" ]; then
	rm ./buf/efficiency
fi


rawData=($(mysql -h ${host} -D$dbProcess -ss -e"
SELECT 
   date_format(a.ts, '%H') as hours,
   powerConsumed,
   coolingCapacity,
   efficiency
  FROM 
    $tbChiller as a,
    $dbPlatform.$tbPower as b
  where 
     a.name='chiller#1' and 
     opFlag=1 and
     b.name='power#1' and
     a.ts=b.ts and
	 a.siteId = b.siteId and
	 a.ts >= '$startDay $startTime' and 
	 a.ts < '$endDay $endTime' and 
	 a.siteId = $siteId 
union
SELECT 
   date_format(a.ts, '%H') as hours,
   powerConsumed,
   coolingCapacity,
   efficiency
  FROM 
    $tbChiller as a,
    $dbPlatform.$tbPower as b
  where 
     a.name='chiller#2' and 
     opFlag=1 and
     b.name='power#2' and
     a.ts=b.ts and 
	 a.siteId = b.siteId and
	 a.ts >= '$startDay $startTime' and 
	 a.ts < '$endDay $endTime' and 
	 a.siteId = $siteId 
;
"))

whileNum=0
while :
do
	if [ "${rawData[$whileNum]}" == "" ]; then
		break
	fi
	
	hours=${rawData[$whileNum]}
	hours=$((10#$hours))
	whileNum=$(($whileNum+1))

	kWatt=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	coolingCapacity=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))

	efficiency=${rawData[$whileNum]}
	whileNum=$(($whileNum+1))
	

	#echo "[DEBUG]kWatt coolingCapacity efficiency $hours $kWatt $coolingCapacity $efficiency"
	if [ "$kWatt" != "NULL" ]; then
		echo "$kWatt" >> ./buf/kW.$hours
		echo "$kWatt" >> ./buf/kW
	fi
	
	if [ "$coolingCapacity" != "NULL" ]; then
		echo "$coolingCapacity" >> ./buf/coolingCapacity.$hours
		echo "$coolingCapacity" >> ./buf/coolingCapacity
	fi
	
	if [ "$efficiency" != "NULL" ]; then
		echo "$efficiency" >> ./buf/efficiency.$hours
		echo "$efficiency" >> ./buf/efficiency
	fi
done

if [ -f "./buf/kW" ]; then

	countNum="$(cat ./buf/kW |wc -l)"

	if [ $countNum == 0 ]; then

		kWattMin=NULL
		kWattMedian=NULL
		kWattMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/kW > ./buf/kW.Sort
		rm ./buf/kW
		
		kWattMin="$(cat ./buf/kW.Sort | head -n 1 | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.Sort | head -n 1 | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/kW.Sort
	else

		sort -n ./buf/kW > ./buf/kW.Sort
		rm ./buf/kW
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		#echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		#echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		kWattMin="$(cat ./buf/kW.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		kWattMedian="$(cat ./buf/kW.Sort  | head -n $medianNum | tail -n 1)" 
		kWattMax="$(cat ./buf/kW.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/kW.Sort
	fi
else
	kWattMin=NULL
	kWattMedian=NULL
	kWattMax=NULL
fi

echo "k Watt $kWattMin $kWattMedian $kWattMax"

if [ -f "./buf/coolingCapacity" ]; then

	countNum="$(cat ./buf/coolingCapacity |wc -l)"

	if [ $countNum == 0 ]; then

		coolingCapacityMin=NULL
		coolingCapacityMedian=NULL
		coolingCapacityMax=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/coolingCapacity > ./buf/coolingCapacity.Sort
		rm ./buf/coolingCapacity
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.Sort | head -n 1 | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingCapacity.Sort
	else

		sort -n ./buf/coolingCapacity > ./buf/coolingCapacity.Sort
		rm ./buf/coolingCapacity
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		coolingCapacityMin="$(cat ./buf/coolingCapacity.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		coolingCapacityMedian="$(cat ./buf/coolingCapacity.Sort  | head -n $medianNum | tail -n 1)" 
		coolingCapacityMax="$(cat ./buf/coolingCapacity.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingCapacity.Sort
	fi
else
	coolingCapacityMin=NULL
	coolingCapacityMedian=NULL
	coolingCapacityMax=NULL
fi

echo "$coolingCapacityMin $coolingCapacityMedian $coolingCapacityMax"

if [ -f "./buf/efficiency" ]; then

	countNum="$(cat ./buf/efficiency |wc -l)"

	if [ $countNum == 0 ]; then

		Min=NULL
		Median=NULL
		Max=NULL
		
	elif [ $countNum == 1 ]; then

		sort -n ./buf/efficiency > ./buf/efficiency.Sort
		rm ./buf/efficiency
		
		Min="$(cat ./buf/efficiency.Sort | head -n 1 | tail -n 1)" 
		Median="$(cat ./buf/efficiency.Sort | head -n 1 | tail -n 1)" 
		Max="$(cat ./buf/efficiency.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/efficiency.Sort
	else

		sort -n ./buf/efficiency > ./buf/efficiency.Sort
		rm ./buf/efficiency
		
		echo "scale=0;$(($countNum*$FirstQuatile))/100"|bc > ./buf/data
		FirstQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)" 
		if [ $FirstQuatileNum == 0 ]; then
			FirstQuatileNum=1
			echo "[DEBUG] FirstQuatile is 0 "	
		fi
		echo "[DEBUG] First Quatile Num:$FirstQuatileNum"

		echo "scale=0;$(($countNum*$ThirdQuatile))/100"|bc > ./buf/data
		ThirdQuatileNum="$(cat ./buf/data | head -n 1 | tail -n 1)"
		echo "[DEBUG] Third Quatile Num:$ThirdQuatileNum"

		rm ./buf/data
		medianNum=$(($countNum/2))
		
		Min="$(cat ./buf/efficiency.Sort  | head -n $FirstQuatileNum | tail -n 1)" 
		Median="$(cat ./buf/efficiency.Sort  | head -n $medianNum | tail -n 1)" 
		Max="$(cat ./buf/efficiency.Sort | head -n $ThirdQuatileNum | tail -n 1)" 

		rm ./buf/efficiency.Sort
	fi
else
	Min=NULL
	Median=NULL
	Max=NULL
fi

efficiencyMin=$Min
efficiencyMedian=$Median
efficiencyMax=$Max

echo "efficiency $Min $Median $Max"

if [ -f "./buf/kw.Json" ]; then
	rm ./buf/kw.Json
fi

whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/kW.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/kW.Json
		fi
		
		sort ./buf/kW.$whileHour > ./buf/kW.$whileHour.sort
		countNum="$(cat ./buf/kW.$whileHour.sort | wc -l)"
		data="$(cat ./buf/kW.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#Energy Consumption(kW)
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/kw.Json
	fi
	whileHour=$(($whileHour+1))
done

kwDataERROR=0
if [ -f "./buf/kw.Json" ]; then
	kwData="$(cat ./buf/kw.Json | head -n 1 | tail -n 1)" 
	rm ./buf/kw.Json
else
	kwDataERROR=1
fi

#echo "$kwData"

if [ -f "./buf/coolingCapacity.Json" ]; then
	rm ./buf/coolingCapacity.Json
fi

whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/coolingCapacity.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingCapacity.Json
		fi
		
		sort ./buf/coolingCapacity.$whileHour > ./buf/coolingCapacity.$whileHour.sort
		countNum="$(cat ./buf/coolingCapacity.$whileHour.sort | wc -l)"
		data="$(cat ./buf/coolingCapacity.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#coolingCapacity
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/coolingCapacity.Json
	fi
	whileHour=$(($whileHour+1))
done

coolingCapacityDataERROR=0
if [ -f "./buf/coolingCapacity.Json" ]; then
	coolingCapacityData="$(cat ./buf/coolingCapacity.Json | head -n 1 | tail -n 1)" 
	rm ./buf/coolingCapacity.Json
else
	coolingCapacityDataERROR=1
fi

#echo "$coolingCapacityData"

if [ -f "./buf/efficiency.Json" ]; then
	rm ./buf/efficiency.Json
fi

whileHour=0
jsonNum=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/efficiency.$whileHour" ]; then

		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/efficiency.Json
		fi
		
		sort ./buf/efficiency.$whileHour > ./buf/efficiency.$whileHour.sort
		countNum="$(cat ./buf/efficiency.$whileHour.sort | wc -l)"
		data="$(cat ./buf/efficiency.$whileHour.sort | head -n $countNum | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#efficiency
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $data >> ./buf/efficiency.Json
	fi
	whileHour=$(($whileHour+1))
done

efficiencyDataERROR=0
if [ -f "./buf/efficiency.Json" ]; then
	efficiencyData="$(cat ./buf/efficiency.Json | head -n 1 | tail -n 1)" 
	rm ./buf/efficiency.Json
else
	efficiencyDataERROR=1
fi

#echo "$efficiencyData"

#energyConsumptionData
chillerPlantTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT chillerId,date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
FROM reportplatform.dailyChillerData
WHERE 
siteId=$siteId and 
operationDate='$startDay' and 
operationFlag=1
;
"))

if [ -f "./buf/energyConsumptionDataJson" ]; then
	rm ./buf/energyConsumptionDataJson
fi

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/energyConsumptionData.$whileHour" ]; then
		rm ./buf/energyConsumptionData.$whileHour
		echo "rm ./buf/energyConsumptionData.$whileHour"
	fi
	
	whileHour=$(($whileHour+1))
done

whileNum=0
jsonNum=0
while :
do
	if [ "${chillerPlantTime[$whileNum]}" == "" ]; then
		break
	fi

	chillerIdNum=${chillerPlantTime[$whileNum]}
	whileNum=$(($whileNum+1))
	
	runStartHour=${chillerPlantTime[$whileNum]}
	runStartHour=$((10#$runStartHour))
	whileNum=$(($whileNum+1))
	
	runStartMin=${chillerPlantTime[$whileNum]}
	runStartMin=$((10#$runStartMin))
	whileNum=$(($whileNum+1))
	
	runEndHour=${chillerPlantTime[$whileNum]}
	runEndHour=$((10#$runEndHour))
	whileNum=$(($whileNum+1))
	
	runEndMin=${chillerPlantTime[$whileNum]}
	runEndMin=$((10#$runEndMin))
	whileNum=$(($whileNum+1))

	stHour=0
	stMin=0
	
	endHour=0
	endMin=0


	echo " $chillerIdNum ${chillerNameList[$chillerIdNum]}  $runStartHour:$runStartMin ~ $runEndHour:$runEndMin"

	while :
	do
		if [ $stHour == 25 ]; then
		 break
		fi
		
		#stHour >= runStartHour and  stHour <= runStartHour
		if [ $stHour -ge $runStartHour ] && [ $stHour -le $runEndHour ]; then
			
			if [ $stHour == $runEndHour ]; then
			
				if [ $runEndMin == 0 ]; then
					echo "  $runEndHour:$runEndMin is 0"
					break
				fi
				
				endHour=$stHour
				stMin=0
				endMin=$runEndMin
			else
				endHour=$(($stHour+1))
				checkMin=$(($endHour-$runStartHour))
				
				if [ $checkMin == 1 ]; then
					stMin=$runStartMin
				else
					stMin=0
				fi
			fi
			
			#echo "$stHour:$stMin ~ $endHour:$endMin"
			#JSON formeat
			jsonNum=$(($jsonNum+1))
						  #>=
			if [ $jsonNum -ge 2 ]; then
				
				printf ",">> ./buf/efficiencyJson.$startDay.$gId
			fi
			
			# Median Value taken over that hour interval.
			# Example : At least 1 chiller ON from 23:00 –
			# 23:30
			# Median Plant Power Consumption Value
			# taken over the period 23:00 – 23:30
			
			startDateTime=$(date "+%Y-%m-%d %H:%M" -d "$startDay $stHour:$stMin")
			endDateTime=$(date "+%Y-%m-%d %H:%M" -d "$startDay $endHour:$endMin")
			
			dataWatt=($(mysql -h ${host} -D$dbPlatform -ss -e"select 
				round(powerConsumed,2) as kWatt
			  FROM $tbPower
				  WHERE 
				  siteId='$siteId' and
				  name='${chillerNameList[$chillerIdNum]}' and 
				  ts >= '$startDateTime' and 
				  ts <= '$endDateTime:59'
			"))

			
			dataNum=0
			
			while :
			do
				if [ "${dataWatt[$dataNum]}" == "" ]; then
					break
				fi

				echo "[DEBUG]data Watt:${dataWatt[$dataNum]}"
				echo "${dataWatt[$dataNum]}" >> ./buf/energyConsumptionData.$stHour
				
				dataNum=$(($dataNum+1))
			done
		fi

		stHour=$(($stHour+1))
	done
	#next time
done

whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/energyConsumptionData.$whileHour" ]; then
	
		#echo "./buf/energyConsumptionData.$whileHour"
		
		countNum="$(cat ./buf/energyConsumptionData.$whileHour |wc -l)"
		
		calNum=1
		wattDataTotal=0
		wattData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			wattData="$(cat ./buf/energyConsumptionData.$whileHour | head -n $calNum | tail -n 1)"
			
			#Plant Power Consumption (kW) = Every data
			#point (minute) will just be the sum of power
			#of all equipment that are on
			
			#echo "$wattDataTotal+$wattData"
			echo "scale=3;$wattDataTotal+$wattData"|bc > ./buf/wattDataTotal
			
			wattDataTotal="$(cat ./buf/wattDataTotal | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		#echo " $wattDataTotal"

		rm ./buf/energyConsumptionData.$whileHour
	
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/energyConsumptionDataJson
		fi
		
		echo "scale=2;$wattDataTotal/$countNum"|bc > ./buf/wattDataTotal
		wattDataTotal="$(cat ./buf/wattDataTotal | head -n 1 | tail -n 1)"
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#Energy Consumption(kW)
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $wattDataTotal >> ./buf/energyConsumptionDataJson
	fi
	whileHour=$(($whileHour+1))
done

energyConsumptionERROR=0
if [ -f "./buf/energyConsumptionDataJson" ]; then
	energyConsumptionData="$(cat ./buf/energyConsumptionDataJson | head -n 1 | tail -n 1)" 
	rm ./buf/energyConsumptionDataJson
else
	energyConsumptionERROR=1
fi

echo "REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	coolingCapacityData,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId','$gId',
	'$totalEnergyConsumption',
	if($energyConsumptionERROR=1,NULL,'{$energyConsumptionData}'),
	'$utilization',
	'{$energyDistributionData}',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($efficiencyDataERROR=1,NULL,'{$efficiencyData}'),
	if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	if($coolingCapacityDataERROR=1,NULL,'{$coolingCapacityData}'),
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax')
);
"

mysql -h ${host} -D$dbRPF -ss -e"REPlACE INTO dailyPlantPerformance(operationDate,siteId,gatewayId,
	totalEnergyConsumption,energyConsumptionData,
	utilization,energyDistribution,
	efficiencyMin,efficiencyMedian,efficiencyMax,
	efficiencyData,
	coolingCapacityMin,coolingCapacityMedian,coolingCapacityMax,
	coolingCapacityData,
	powerMin,powerMedian,powerMax) 
VALUES('$startDay','$siteId','$gatewayId',
	'$totalEnergyConsumption',
	if($energyConsumptionERROR=1,NULL,'{$energyConsumptionData}'),
	'$utilization',
	'{$energyDistributionData}',
	if($efficiencyMin is NULL,NULL,'$efficiencyMin'),
	if($efficiencyMedian is NULL,NULL,'$efficiencyMedian'),
	if($efficiencyMax is NULL,NULL,'$efficiencyMax'),
	if($efficiencyDataERROR=1,NULL,'{$efficiencyData}'),
	if($coolingCapacityMin is NULL,NULL,'$coolingCapacityMin'),
	if($coolingCapacityMedian is NULL,NULL,'$coolingCapacityMedian'),
	if($coolingCapacityMax is NULL,NULL,'$coolingCapacityMax'),
	if($coolingCapacityDataERROR=1,NULL,'{$coolingCapacityData}'),
	if($kWattMin is NULL,NULL,'$kWattMin'),
	if($kWattMedian is NULL,NULL,'$kWattMedian'),
	if($kWattMax is NULL,NULL,'$kWattMax')
);
"
exit 0