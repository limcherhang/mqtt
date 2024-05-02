#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

min=4
while :
do
	if [ $min == 10 ]; then
		break
	fi
	min2=$(($min+1))
	echo "bash chiller_PB.sh 2023-06-16 16:$min 2023-06-16 16:$min2"
	bash chiller_PB.sh 2023-06-16 17:0$min 2023-06-16 17:0$min2
	min=$(($min+1))
done
# if [ "${1}" == "" ] || [ "${2}" == "" ]; then
        # echo "請輸入日期 和 檔案名稱"
        # exit 1
# fi

# Day=${1} 
# FileName=${2}


# hours=16
# while :
# do

	# if [ $hours == 17 ]; then
		# break
	# fi
	
	# min=0
	# while :
	# do
		# if [ $min == 60 ]; then
			# break
		# fi
		
		# min2=$(($min+1))
		# if [ $min2 == 60 ]; then
		
			# hours2=$(($hours+1))
			# if [ $hours2 != 24 ]; then
				# echo "bash $FileName $Day $hours:$min $Day $hours2:00"
				# bash $FileName $Day $hours:$min $Day $hours2:00
			# fi
		# else	
			# echo "bash $FileName $Day $hours:$min $Day $hours:$min2"
			# bash $FileName $Day $hours:$min $Day $hours:$min
		# fi
		
		# min=$(($min+1))
	# done
	
	# hours=$(($hours+1))
# done

exit 0
