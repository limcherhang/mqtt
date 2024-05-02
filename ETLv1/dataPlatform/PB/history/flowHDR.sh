#!/bin/bash
#!/bin/bash
# Program: 時間區間 一次一筆，請勿超過1分鐘
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

dbMgmt="iotmgmt"
dbdataETL="dataETL"
dbdataPlatform="dataPlatform"

startRunTime="${1} ${2}"
endRunTime="${3} ${4}"

PowerName=("power#1" "power#2" "power#3" "power#4")
FlowName=("flow#2" "flow#3" "flow#4" "flow#5")
flowConut=0

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
		flowConut=$(($flowConut+1))
	fi

	whileNum=$(($whileNum+1))
done

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
		echo "replace INTO dataPlatform.flow (ts, siteId,name, flowRate) 
			SELECT ts, 10,'${FlowName[$whileNum]}',round(flowRate/$flowConut,2)
					FROM 
						dataPlatform.flow
					WHERE 
						name='flow#1' and  siteId=10 and
						ts >='$startRunTime' and 
						ts < '$endRunTime';"
						
		mysql -h ${host} -ss -e"replace INTO dataPlatform.flow (ts, siteId,name, flowRate) 
			SELECT ts, 10,'${FlowName[$whileNum]}',round(flowRate/$flowConut,2)
					FROM 
						dataPlatform.flow
					WHERE 
						name='flow#1' and  siteId=10 and
						ts >='$startRunTime' and 
						ts < '$endRunTime';"
			
	else
		echo "replace INTO dataPlatform.flow (ts, siteId,name, flowRate) 
			SELECT ts, 10,'${FlowName[$whileNum]}',0
					FROM 
						dataPlatform.flow
					WHERE 
						name='flow#1' and  siteId=10 and
						ts >='$startRunTime' and 
						ts < '$endRunTime';"
						
		mysql -h ${host} -ss -e"replace INTO dataPlatform.flow (ts, siteId,name, flowRate) 
			SELECT ts, 10,'${FlowName[$whileNum]}',0
					FROM 
						dataPlatform.flow
					WHERE 
						name='flow#1' and  siteId=10 and
						ts >='$startRunTime' and 
						ts < '$endRunTime';"
			
	fi

	whileNum=$(($whileNum+1))
done
	
exit 0
