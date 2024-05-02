#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

host="127.0.0.1"
dbMgmt="iotmgmt"

IEEE=("TAG10" "TAG11" "TAG12" "TAG13" "TAG14" "TAG15" "TAG16" "TAG17" "TAG18" "TAG19" "TAG20" "TAG21" "TAG22" "TAG23" "TAG31" "TAG32")

NAME=("gpio#4" "gpio#5" "gpio#6" "gpio#7" "gpio#8" "gpio#9" "gpio#10" "gpio#11" "gpio#12" "gpio#13" "gpio#14" "gpio#15" "gpio#16" "gpio#17" "gpio#18" "gpio#19")

startRunTime=$(date "+%Y-%m-%d %H:%M:%S" --date="-25 seconds")
endRunTime=$(date "+%Y-%m-%d %H:%M:%S" --date="-10 seconds")

whileNum=0
while :
do
	
	if [ "${IEEE[$whileNum]}" == "" ]; then
	 break
	fi
	
	echo "IEEE ${IEEE[$whileNum]} NAME ${NAME[$whileNum]}"
	
	data=($(mysql -h ${host} -ss -e"SELECT receivedSync,pin0 
	FROM 
		iotmgmt.gpio 
	where 
		gatewayId=300 and 
		ieee ='${IEEE[$whileNum]} ' and
		ts >='$startRunTime' and 
		ts <'$endRunTime'
	"))

	
	dataNum=0
	while :
	do
		
		if [ "${data[$dataNum]}" == "" ]; then
		 break
		fi
		
		ts1=${data[$dataNum]}
		dataNum=$(($dataNum+1))
		
		ts2=${data[$dataNum]}
		dataNum=$(($dataNum+1))

		gpio=${data[$dataNum]}
		dataNum=$(($dataNum+1))
			
		
		echo "replace into dataPlatform.gpio (ts,siteId,name,status) 
			VALUES('$ts1 $ts2','46','${NAME[$whileNum]}','$gpio');"
			
		
		mysql -h ${host} -D$dbMgmt -ss -e"replace into dataPlatform.gpio (ts,siteId,name,status) 
		VALUES('$ts1 $ts2','46','${NAME[$whileNum]}','$gpio');"
		

	done
	
	whileNum=$(($whileNum+1))
done

exit 0	

