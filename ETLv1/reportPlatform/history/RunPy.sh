#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

st=7
end=8
while :
do
	echo "python3 Dflow_history.py 7 $st 7 $end"
	python3 /home/ecoprog/reportPlatform2021/history/Dflow_history.py 7 $st 7 $end
	st=$(($st+1))
	
    
	end=$(($end+1))
	
	if [ $st == 10 ]; then
		break
	fi
done

exit 0
