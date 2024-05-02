#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH


dayNum=6
while :
do	
	if [ $dayNum == 16 ]; then
		break
	fi
	stday=$(date "+%Y-%m-%d" -d "2023-07-$dayNum")
	
	
	
	
	echo "bash Run.sh $stday"
	bash Run.sh $stday
	
	dayNum=$(($dayNum+1))
done

exit 0