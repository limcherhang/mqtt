#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ]; then
        echo "請輸入日期"
        exit 1
fi

Day=${1} 

hours=0
while :
do

	if [ $hours == 24 ]; then
		break
	fi
	
	min=0
	while :
	do
		if [ $min == 60 ]; then
			break
		fi
		
		min2=$(($min+1))
		if [ $min2 == 60 ]; then
		
			hours2=$(($hours+1))
			if [ $hours2 != 24 ]; then
				echo "bash chiller.historyByIotData.sh 133 $Day $hours:$min $Day $hours2:00"
				bash chiller.historyByIotData.sh 133 $Day $hours:$min $Day $hours2:00
			fi
		else	
			echo "bash chiller.historyByIotData.sh 133 $Day $hours:$min $Day $hours:$min2"
			bash chiller.historyByIotData.sh 133 $Day $hours:$min $Day $hours:$min2
		fi
		
		min=$(($min+1))
	done
	
	hours=$(($hours+1))
done

exit 0
