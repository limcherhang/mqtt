#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

dayNum=1

while :
do	
	if [ $dayNum == 16 ]; then
		break
	fi
	stday=$(date "+%Y-%m-%d" -d "2020-11-$dayNum")
	
	dayNum=$(($dayNum+1))
	
	endday=$(date "+%Y-%m-%d" -d "2020-11-$dayNum")
	
	echo "bash RunChillerScriptByDay.sh $stday 00:00 $endday 00:00"
	bash RunChillerScriptByDay.sh $stday 00:00 $endday 00:00
done

exit 0