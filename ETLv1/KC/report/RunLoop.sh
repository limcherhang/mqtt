#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH


dayNum=6
while :
do	
	if [ $dayNum == 32 ]; then
		break
	fi
	stday=$(date "+%Y-%m-%d" -d "2023-07-$dayNum")

	echo "python3 Dpower_history.py $stday 2023"
	python3 Dpower_history.py  $stday 2023
	
	dayNum=$(($dayNum+1))
done

exit 0