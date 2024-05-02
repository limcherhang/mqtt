#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH
if [ "${1}" == "" ] || [ "${2}" == "" ] || [ "${3}" == "" ] || [ "${4}" == "" ] || [ "${5}" == "" ] || [ "${6}" == "" ]; then
        echo "請輸入SiteId 2021-10-08 00:00 2021-10-09 00:00 gatewayId "
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

tempFirstQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempFirstQuatile FROM site_info where id=$siteId;"))
tempThirdQuatile=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT tempThirdQuatile FROM site_info where id=$siteId;"))


echo "$siteId $startDay $startTime $endDay $endTime $dbPlatform $tbPower $tbTemp"
echo "*************************************************************************************************"

echo " "
echo "#**********#"
echo "#Plant Temp#"
echo "#**********#"
echo " "

whileHour=0
while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/returnTempDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/returnTempDataHDR.$startDay.$gId.$whileHour
	fi
	if [ -f "./buf/supplyTempDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/supplyTempDataHDR.$startDay.$gId.$whileHour
	fi

	if [ -f "./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour
	fi
	
	if [ -f "./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour" ]; then
		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour
	fi
	
	whileHour=$(($whileHour+1))
done

if [ -f "./buf/returnTempDataHDR.$startDay.$gId" ]; then
	rm ./buf/returnTempDataHDR.$startDay.$gId
fi

if [ -f "./buf/supplyTempDataHDR.$startDay.$gId" ]; then
	rm ./buf/supplyTempDataHDR.$startDay.$gId
fi

if [ -f "./buf/coolingReturnTempDataHDR.$startDay.$gId" ]; then
	rm ./buf/coolingReturnTempDataHDR.$startDay.$gId
fi

if [ -f "./buf/coolingSupplyTempDataHDR.$startDay.$gId" ]; then
	rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId
fi			

stHour=0
while :
do
	if [ $stHour == 24 ]; then
	 break
	fi
	
	echo "  Run Temp Data $stHour"
	
	stMin=0
	while :
	do
		if [ $stMin == 60 ]; then
			break
		elif [ $stMin == 59 ]; then
			endHour=$(($stHour+1))
			endMin=00
		else
			endHour=$stHour
			endMin=$(($stMin+1))
		fi
		
		#echo "$stHour:$stMin ~ $endHour:$endMin"

		tempTrue=0
		tempPlantTime=($(mysql -h ${host} -D$dbRPF -ss -e"SELECT date_format(startTime, '%H %i') as startTime,date_format(endTime, '%H %i') as endTime 
			FROM 
			  reportplatform.dailyChillerData
			WHERE 
			 siteId=$siteId and 
			 operationDate='$startDay'and 
			 operationFlag=1
		"))
			
		whileNum=0
		while :
		do
			if [ "${tempPlantTime[$whileNum]}" == "" ]; then
			 break
			fi
			
			runStartHour=${tempPlantTime[$whileNum]}
			runStartHour=$((10#$runStartHour))
			whileNum=$(($whileNum+1))
			
			runStartMin=${tempPlantTime[$whileNum]}
			runStartMin=$((10#$runStartMin))
			whileNum=$(($whileNum+1))
			
			runEndHour=${tempPlantTime[$whileNum]}
			runEndHour=$((10#$runEndHour))
			whileNum=$(($whileNum+1))
			
			runEndMin=${tempPlantTime[$whileNum]}
			runEndMin=$((10#$runEndMin))
			whileNum=$(($whileNum+1))
			
			
			# Median Value taken over that hour interval.
			# Example : At least 1 chiller ON from 23:00 –
			# 23:30
			# Median HDR CHWS Temp, Median HDR
			# CHWR Temp, Median HDR CHW Flowrate,
			# Median HDR CWS Temp, Median HDR CWR
			# Temp, Median HDR CW Flowrate value taken
			# over the period 23:00 – 23:30
			
			if [ $stHour -gt $runStartHour ]; then
			
				if [ $endHour -lt $runEndHour ]; then
					tempTrue=1
					break
				elif [ $endHour == $runEndHour ]; then
					if [ $endMin -le $runEndMin ]; then
						tempTrue=1
						break
					fi
				fi
			elif [ $stHour == $runStartHour ]; then
			
				if [ $stMin -ge $runStartMin ]; then
					if [ $endHour -lt $runEndHour ]; then
						tempTrue=1
						break
					elif [ $endHour == $runEndHour ]; then
						if [ $endMin -le $runEndMin ]; then
							tempTrue=1
							break
						fi
					fi
				fi
			fi
		done

		if [ $tempTrue == 1 ]; then
			#echo " $stHour:$stMin ~ $endHour:$endMin || $runStartHour $runStartMin $runEndHour $runEndMin"
			
			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT temp as tempReturn
				FROM 
					$tbTemp
				WHERE name='temp#6' and 
					ts >='$startDay $stHour:$stMin' and 
					ts <'$startDay $endHour:$endMin'and
					siteId = $siteId 
			;"))
			#echo "$stHour:$stMin ~ $endHour:$endMin returnTempDataHDR *$tempData*"
			if [ "$tempData" == "" ]; then
				echo "[ERROR]$stHour:$stMin ~ $endHour:$endMin returnTempDataHDR $tempData"
			else
				echo "$tempData" >> ./buf/returnTempDataHDR.$startDay.$gId
				echo "$tempData" >> ./buf/returnTempDataHDR.$startDay.$gId.$stHour
			fi
		
			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"SELECT temp as tempSupply
				FROM 
					$tbTemp
				WHERE name='temp#5' and 
					ts >='$startDay $stHour:$stMin' and 
					ts <'$startDay $endHour:$endMin'and
					siteId = $siteId
			;"))
			#echo "$stHour:$stMin ~ $endHour:$endMin supplyTempDataHDR *$tempData*"
			if [ "$tempData" == "" ]; then
				echo "[ERROR]$stHour:$stMin ~ $endHour:$endMin supplyTempDataHDR $tempData"
			else
				echo "$tempData" >> ./buf/supplyTempDataHDR.$startDay.$gId
				echo "$tempData" >> ./buf/supplyTempDataHDR.$startDay.$gId.$stHour
			fi

			tempData=($(mysql -h ${host} -D$dbPlatform -ss -e"select IFNULL(Round(tempReturn-tempSupply,2),0) as delta
			from
			(
			SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempSupply
			  FROM 
					$tbTemp
				WHERE name='temp#5' and 
					ts >='$startDay $stHour:$stMin' and 
					ts <'$startDay $endHour:$endMin'and
					siteId = $siteId
			) as a

			INNER join
			(
			SELECT date_format(ts, '%Y-%m-%d %H:%i') as time,temp as tempReturn
				FROM 
					$tbTemp
				WHERE name='temp#6' and 
					ts >='$startDay $stHour:$stMin' and 
					ts <'$startDay $endHour:$endMin'and
					siteId = $siteId
			) as b
			on a.time=b.time;"))
			
			
			#echo "$stHour:$stMin ~ $endHour:$endMin deltaTempDataHDR *$tempData*"
			if [ "$tempData" == "" ]; then
				echo "[ERROR]$stHour:$stMin ~ $endHour:$endMin deltaTempDataHDR $tempData"
			else
				echo "$tempData" >> ./buf/deltaTempDataHDR.$startDay.$gId
				echo "$tempData" >> ./buf/deltaTempDataHDR.$startDay.$gId.$stHour
			fi

			tempTrue=0
		fi
		
		stMin=$(($stMin+1))
	done
	
	stHour=$(($stHour+1))
done

echo "  Run Return Temp Min Median Max"	
if [ -f "./buf/returnTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/returnTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		returnTempMin=NULL
		returnTempMedian=NULL
		returnTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/returnTempDataHDR.$startDay.$gId > ./buf/returnTempDataHDR.$startDay.$gId.Sort
		rm ./buf/returnTempDataHDR.$startDay.$gId
		
		returnTempMin="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort | head -n  1 | tail -n 1)" 
		returnTempMedian="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		returnTempMax="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/returnTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/returnTempDataHDR.$startDay.$gId > ./buf/returnTempDataHDR.$startDay.$gId.Sort
		#rm ./buf/returnTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] return Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] return Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		echo "[DEBUG] return Temp Data HDR Median Num:$medianNum"
		
		returnTempMin="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort  | head -n  $tempFirstQuatileNum | tail -n 1)" 
		returnTempMedian="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		returnTempMax="$(cat ./buf/returnTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		#rm ./buf/returnTempDataHDR.$startDay.$gId.Sort
	fi
else
	returnTempMin=NULL
	returnTempMedian=NULL
	returnTempMax=NULL
fi

echo "  Run Supply Temp Min Median Max"	
if [ -f "./buf/supplyTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/supplyTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		supplyTempMin=NULL
		supplyTempMedian=NULL
		supplyTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/supplyTempDataHDR.$startDay.$gId > ./buf/supplyTempDataHDR.$startDay.$gId.Sort
		rm ./buf/supplyTempDataHDR.$startDay.$gId
		
		supplyTempMin="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort | head -n  1 | tail -n 1)" 
		supplyTempMedian="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		supplyTempMax="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/supplyTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/supplyTempDataHDR.$startDay.$gId > ./buf/supplyTempDataHDR.$startDay.$gId.Sort
		rm ./buf/supplyTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi		
		echo "[DEBUG] supply Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] supply Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"
		
		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		
		supplyTempMin="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		supplyTempMedian="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		supplyTempMax="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/supplyTempDataHDR.$startDay.$gId.Sort
	fi
else
	supplyTempMin=NULL
	supplyTempMedian=NULL
	supplyTempMax=NULL
fi

echo "  Run Cooling Return Temp Min Median Max"	
if [ -f "./buf/coolingReturnTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		coolingReturnTempMin=NULL
		coolingReturnTempMedian=NULL
		coolingReturnTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/coolingReturnTempDataHDR.$startDay.$gId > ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId
		
		coolingReturnTempMin="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort | head -n  1 | tail -n 1)" 
		coolingReturnTempMedian="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingReturnTempMax="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/coolingReturnTempDataHDR.$startDay.$gId > ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] cooling Return Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] cooling Return Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		
		coolingReturnTempMin="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		coolingReturnTempMedian="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		coolingReturnTempMax="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId.Sort
	fi
else
	coolingReturnTempMin=NULL
	coolingReturnTempMedian=NULL
	coolingReturnTempMax=NULL
fi

echo "  Run Cooling Supply Temp Min Median Max"	
if [ -f "./buf/coolingSupplyTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		coolingSupplyTempMin=NULL
		coolingSupplyTempMedian=NULL
		coolingSupplyTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/coolingSupplyTempDataHDR.$startDay.$gId > ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId
		
		coolingSupplyTempMin="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingSupplyTempMedian="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingSupplyTempMax="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/coolingSupplyTempDataHDR.$startDay.$gId > ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] cooling Supply Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] cooling Supply Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		
		coolingSupplyTempMin="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		coolingSupplyTempMedian="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		coolingSupplyTempMax="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId.Sort
	fi
else
	coolingSupplyTempMin=NULL
	coolingSupplyTempMedian=NULL
	coolingSupplyTempMax=NULL
fi

echo "  Run Delta Temp Min Median Max"	
if [ -f "./buf/deltaTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/deltaTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		deltaTempMin=NULL
		deltaTempMedian=NULL
		deltaTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/deltaTempDataHDR.$startDay.$gId > ./buf/deltaTempDataHDR.$startDay.$gId.Sort
		rm ./buf/deltaTempDataHDR.$startDay.$gId
		
		deltaTempMin="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		deltaTempMedian="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		deltaTempMax="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/deltaTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/deltaTempDataHDR.$startDay.$gId > ./buf/deltaTempDataHDR.$startDay.$gId.Sort
		rm ./buf/deltaTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] delta Temp Data HDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] delta Temp Data HDR ThirdQuatile Num:$tempThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		medianNum=$(($tempCountNum/2))
		
		deltaTempMin="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		deltaTempMedian="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		deltaTempMax="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/deltaTempDataHDR.$startDay.$gId.Sort
	fi
else
	deltaTempMin=NULL
	deltaTempMedian=NULL
	deltaTempMax=NULL
fi

echo "  Run Cooling Supply Temp Min Median Max"	
if [ -f "./buf/coolingDeltaTempDataHDR.$startDay.$gId" ]; then

	tempCountNum="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId |wc -l)"

	if [ $tempCountNum == 0 ]; then

		coolingDeltaTempMin=NULL
		coolingDeltaTempMedian=NULL
		coolingDeltaTempMax=NULL
		
	elif [ $tempCountNum == 1 ]; then

		sort -n ./buf/coolingDeltaTempDataHDR.$startDay.$gId > ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingDeltaTempDataHDR.$startDay.$gId
		
		coolingDeltaTempMin="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingDeltaTempMedian="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort | head -n 1 | tail -n 1)" 
		coolingDeltaTempMax="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort  | head -n 1 | tail -n 1)" 
		
		rm ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort
	else

		sort -n ./buf/coolingDeltaTempDataHDR.$startDay.$gId > ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort
		rm ./buf/coolingDeltaTempDataHDR.$startDay.$gId
		
		echo "scale=0;$(($tempCountNum*$tempFirstQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempFirstQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)" 
		if [ $tempFirstQuatileNum == 0 ]; then
			tempFirstQuatileNum=1
			echo "[DEBUG] tempFirstQuatile is 0 "	
		fi
		echo "[DEBUG] coolingDeltaTempDataHDR FirstQuatile Num:$tempFirstQuatileNum"

		echo "scale=0;$(($tempCountNum*$tempThirdQuatile))/100"|bc > ./buf/data.$startDay.$gId
		tempThirdQuatileNum="$(cat ./buf/data.$startDay.$gId | head -n 1 | tail -n 1)"
		echo "[DEBUG] coolingDeltaTempDataHDR ThirdQuatile Num:$tempThirdQuatileNum"

		rm ./buf/data.$startDay.$gId
		
		medianNum=$(($tempCountNum/2))
		
		coolingDeltaTempMin="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort  | head -n $tempFirstQuatileNum | tail -n 1)" 
		coolingDeltaTempMedian="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort  | head -n $medianNum | tail -n 1)" 
		coolingDeltaTempMax="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort | head -n $tempThirdQuatileNum | tail -n 1)" 

		rm ./buf/coolingDeltaTempDataHDR.$startDay.$gId.Sort
	fi
else
	coolingDeltaTempMin=NULL
	coolingDeltaTempMedian=NULL
	coolingDeltaTempMax=NULL
fi

echo "  Run return Temp Data HDR"	
whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/returnTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/returnTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/returnTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/returnTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/returnTempDataHDR.$startDay.$gId.$whileHour
		
		jsonNum=$(($jsonNum+1))
				  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/returnTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#Return Temp Data HDR 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/returnTempDataHDRJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

returnTempDataERROR=0
if [ -f "./buf/returnTempDataHDRJson.$startDay.$gId" ]; then
	returnTempData="$(cat ./buf/returnTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/returnTempDataHDRJson.$startDay.$gId
else
	returnTempDataERROR=1
fi

echo "  Run supply Temp Data HDR"	
whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/supplyTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/supplyTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/supplyTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/supplyTempDataHDR.$startDay.$gId.$whileHour
	
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/supplyTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#supply Temp Data 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/supplyTempDataHDRJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

supplyTempDataERROR=0
if [ -f "./buf/supplyTempDataHDRJson.$startDay.$gId" ]; then
	supplyTempData="$(cat ./buf/supplyTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/supplyTempDataHDRJson.$startDay.$gId
else
	supplyTempDataERROR=1
fi


echo "  Run cooling Return Temp Data HDR"
whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/coolingReturnTempDataHDR.$startDay.$gId.$whileHour

	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingReturnTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#cooling Return Temp Data 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/coolingReturnTempDataHDRJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

coolingReturnTempDataERROR=0
if [ -f "./buf/coolingReturnTempDataHDRJson.$startDay.$gId" ]; then
	coolingReturnTempData="$(cat ./buf/coolingReturnTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/coolingReturnTempDataHDRJson.$startDay.$gId
else
	coolingReturnTempDataERROR=1
fi

echo "  Run cooling Supply Temp Data HDR"
whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/coolingSupplyTempDataHDR.$startDay.$gId.$whileHour
	
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingSupplyTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#cooling Supply Temp Data 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/coolingSupplyTempDataHDRJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

coolingSupplyTempDataERROR=0
if [ -f "./buf/coolingSupplyTempDataHDRJson.$startDay.$gId" ]; then
	coolingSupplyTempData="$(cat ./buf/coolingSupplyTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/coolingSupplyTempDataHDRJson.$startDay.$gId
else
	coolingSupplyTempDataERROR=1
fi

echo "  Run delta Temp Data HDR"

whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/deltaTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/deltaTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/deltaTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/deltaTempDataHDR.$startDay.$gId.$whileHour
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/deltaTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour

		endHour=$(($whileHour+1))

		#delta Temp Data HDR 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/deltaTempDataHDRJson.$startDay.$gId
		
	fi
	whileHour=$(($whileHour+1))
done

deltaTempDataERROR=0
if [ -f "./buf/deltaTempDataHDRJson.$startDay.$gId" ]; then
	deltaTempData="$(cat ./buf/deltaTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/deltaTempDataHDRJson.$startDay.$gId
else
	deltaTempDataERROR=1
fi


echo "  Run Cooling Delta Temp Data HDR"

whileHour=0
jsonNum=0
stHour=0
endHour=0

while :
do
	if [ "$whileHour" == 24 ]; then
		break
	fi

	if [ -f "./buf/coolingDeltaTempDataHDR.$startDay.$gId.$whileHour" ]; then
	
		#echo "./buf/coolingDeltaTempDataHDR.$startDay.$gId.$whileHour"
		
		countNum="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.$whileHour |wc -l)"
		
		calNum=1
		dataTotalTemp=0
		tempData=0

		while :
		do
			if [ $calNum == $countNum ]; then
				break
			fi
			
			tempData="$(cat ./buf/coolingDeltaTempDataHDR.$startDay.$gId.$whileHour | head -n $calNum | tail -n 1)"
			
			#echo "$dataTotalTemp+$tempData"
			echo "scale=3;$dataTotalTemp+$tempData"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
			dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
			
			calNum=$(($calNum+1))
		done
		
		echo "scale=3;$dataTotalTemp/$countNum"|bc > ./buf/dataTotalTemp.$startDay.$gId
			
		dataTotalTemp="$(cat ./buf/dataTotalTemp.$startDay.$gId | head -n 1 | tail -n 1)"
		#echo " $dataTotalTemp"

		rm ./buf/coolingDeltaTempDataHDR.$startDay.$gId.$whileHour
	
	
		jsonNum=$(($jsonNum+1))
					  #>=
		if [ $jsonNum -ge 2 ]; then
			printf ",">> ./buf/coolingDeltaTempDataHDRJson.$startDay.$gId
		fi
		
		stHour=$whileHour
		endHour=$(($whileHour+1))

		#cooling Delta Temp Data 
		printf "\"data%d\": {\"stHours\": %d,\"stMinutes\": %d,\"endHours\": %d,\"endMinutes\": %d,\"data\": %.03f}" $jsonNum $stHour 0 $endHour 0 $dataTotalTemp >> ./buf/coolingDeltaTempDataHDRJson.$startDay.$gId
	fi
	
	whileHour=$(($whileHour+1))
done

coolingDeltaTempDataERROR=0
if [ -f "./buf/coolingDeltaTempDataHDRJson.$startDay.$gId" ]; then
	coolingDeltaTempData="$(cat ./buf/coolingDeltaTempDataHDRJson.$startDay.$gId | head -n 1 | tail -n 1)" 
	rm ./buf/coolingDeltaTempDataHDRJson.$startDay.$gId
else
	coolingDeltaTempDataERROR=1
fi

echo "REPlACE INTO dailyPlantWaterTemp(operationDate,siteId,gatewayId,
	chillerSupplyMin,chillerSupplyMedian,chillerSupplyMax,
	chillerReturnMin,chillerReturnMedian,chillerReturnMax,
	coolingSupplyMin,coolingSupplyMedian,coolingSupplyMax,
	coolingReturnMin,coolingReturnMedian,coolingReturnMax,
	chillerSupplyData,
	chillerReturnData,
	coolingSupplyData,
	coolingReturnData,
	chillerDeltaMin,chillerDeltaMedian,chillerDeltaMax,
	chillerDeltaData,
	coolingDeltaMin,coolingDeltaMedian,coolingDeltaMax,
	coolingDeltaData) 
VALUES('$startDay','$siteId','$gId',
	if($supplyTempMin is NULL,NULL,'$supplyTempMin'),
	if($supplyTempMedian is NULL,NULL,'$supplyTempMedian'),
	if($supplyTempMax is NULL,NULL,'$supplyTempMax'),
	if($returnTempMin is NULL,NULL,'$returnTempMin'),
	if($returnTempMedian is NULL,NULL,'$returnTempMedian'),
	if($returnTempMax is NULL,NULL,'$returnTempMax'),
	if($coolingReturnTempMin is NULL,NULL,'$coolingReturnTempMin'),
	if($coolingReturnTempMedian is NULL,NULL,'$coolingReturnTempMedian'),
	if($coolingReturnTempMax is NULL,NULL,'$coolingReturnTempMax'),
	if($coolingSupplyTempMin is NULL,NULL,'$coolingSupplyTempMin'),
	if($coolingSupplyTempMedian is NULL,NULL,'$coolingSupplyTempMedian'),
	if($coolingSupplyTempMax is NULL,NULL,'$coolingSupplyTempMax'),
	if($supplyTempDataERROR=1,NULL,'{$supplyTempData}'),
	if($returnTempDataERROR=1,NULL,'{$returnTempData}'),
	if($coolingReturnTempDataERROR=1,NULL,'{$coolingReturnTempData}'),
	if($coolingSupplyTempDataERROR=1,NULL,'{$coolingSupplyTempData}'),
	if($deltaTempMin is NULL,NULL,'$deltaTempMin'),
	if($deltaTempMedian is NULL,NULL,'$deltaTempMedian'),
	if($deltaTempMax is NULL,NULL,'$deltaTempMax'),
	if($deltaTempDataERROR=1,NULL,'{$deltaTempData}'),
	if($coolingDeltaTempMin is NULL,NULL,'$coolingDeltaTempMin'),
	if($coolingDeltaTempMedian is NULL,NULL,'$coolingDeltaTempMedian'),
	if($coolingDeltaTempMax is NULL,NULL,'$coolingDeltaTempMax'),
	if($coolingDeltaTempDataERROR=1,NULL,'{$coolingDeltaTempData}')
);
"

mysql -h ${host} -D$dbRPF -ss -e"
REPlACE INTO dailyPlantWaterTemp(operationDate,siteId,gatewayId,
	chillerSupplyMin,chillerSupplyMedian,chillerSupplyMax,
	chillerReturnMin,chillerReturnMedian,chillerReturnMax,
	coolingSupplyMin,coolingSupplyMedian,coolingSupplyMax,
	coolingReturnMin,coolingReturnMedian,coolingReturnMax,
	chillerSupplyData,
	chillerReturnData,
	coolingSupplyData,
	coolingReturnData,
	chillerDeltaMin,chillerDeltaMedian,chillerDeltaMax,
	chillerDeltaData,
	coolingDeltaMin,coolingDeltaMedian,coolingDeltaMax,
	coolingDeltaData) 
VALUES('$startDay','$siteId','$gId',
	if($supplyTempMin is NULL,NULL,'$supplyTempMin'),
	if($supplyTempMedian is NULL,NULL,'$supplyTempMedian'),
	if($supplyTempMax is NULL,NULL,'$supplyTempMax'),
	if($returnTempMin is NULL,NULL,'$returnTempMin'),
	if($returnTempMedian is NULL,NULL,'$returnTempMedian'),
	if($returnTempMax is NULL,NULL,'$returnTempMax'),
	if($coolingReturnTempMin is NULL,NULL,'$coolingReturnTempMin'),
	if($coolingReturnTempMedian is NULL,NULL,'$coolingReturnTempMedian'),
	if($coolingReturnTempMax is NULL,NULL,'$coolingReturnTempMax'),
	if($coolingSupplyTempMin is NULL,NULL,'$coolingSupplyTempMin'),
	if($coolingSupplyTempMedian is NULL,NULL,'$coolingSupplyTempMedian'),
	if($coolingSupplyTempMax is NULL,NULL,'$coolingSupplyTempMax'),
	if($supplyTempDataERROR=1,NULL,'{$supplyTempData}'),
	if($returnTempDataERROR=1,NULL,'{$returnTempData}'),
	if($coolingReturnTempDataERROR=1,NULL,'{$coolingReturnTempData}'),
	if($coolingSupplyTempDataERROR=1,NULL,'{$coolingSupplyTempData}'),
	if($deltaTempMin is NULL,NULL,'$deltaTempMin'),
	if($deltaTempMedian is NULL,NULL,'$deltaTempMedian'),
	if($deltaTempMax is NULL,NULL,'$deltaTempMax'),
	if($deltaTempDataERROR=1,NULL,'{$deltaTempData}'),
	if($coolingDeltaTempMin is NULL,NULL,'$coolingDeltaTempMin'),
	if($coolingDeltaTempMedian is NULL,NULL,'$coolingDeltaTempMedian'),
	if($coolingDeltaTempMax is NULL,NULL,'$coolingDeltaTempMax'),
	if($coolingDeltaTempDataERROR=1,NULL,'{$coolingDeltaTempData}')
);
"
exit 0
