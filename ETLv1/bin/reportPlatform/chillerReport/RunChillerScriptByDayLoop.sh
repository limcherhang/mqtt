#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

dayNum=2

while :
do	
	if [ $dayNum == 5 ]; then
		break
	fi
	stday=$(date "+%Y-%m-%d" -d "2020-10-$dayNum")
	
	dayNum=$(($dayNum+1))
	
	endday=$(date "+%Y-%m-%d" -d "2020-10-$dayNum")
	
	echo "bash RunChillerScriptByDay.sh $stday 00:00 $endday 00:00"
	bash RunChillerScriptByDay.sh $stday 00:00 $endday 00:00
done

exit 0