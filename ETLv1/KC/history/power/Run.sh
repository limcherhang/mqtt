#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ]; then
        echo "請輸入 bash Run.sh 2020-09-17"
        exit 1
fi

#echo "python3 kcAPI_history.py ${1}"
#python3 kcAPI_history.py ${1} 0
#python3 kcAPI_history.py ${1} 12

#dataETL
#echo "python3 kcRawToETL_history.py ${1}"
#python3 kcRawToETL_history.py ${1}

#echo "python3 kcPower1_history.py ${1}"
#python3 kcPower1_history.py ${1}

#dataPlatfrom
#echo "python3 kcETLTodataPlatform_history.py ${1}"
#python3 kcETLTodataPlatform_history.py ${1}

#power 1 and 14 dataPlatfrom
#echo "python3 kcPower14+1_history.py ${1}"
#python3 kcPower14+1_history.py ${1}

#power 1 and 14 dataPlatfrom
#echo "python3 kcPower14+1_history.py ${1}"
#python3 kcPower14+1_history.py ${1}

#power 10 ~ 18 dataPlatfrom
echo "python3 kcPower_history.py ${1}"
python3 kcPower_history.py ${1}

#power 10 ~ 18 dataPlatfrom 最後一筆 補上
echo "python3 kcPower_fin_history.py ${1} 2023"
python3 kcPower_fin_history.py  ${1} 2023

#power 1 ~ 18 reportPlatfrom
#python3 kcReportpower_month.py 2023-08-01

# 7/17 7/18 資料會異常
# 7/17 14:00  power#1 change to 7/18 07:40 power#1
# 7/17 15:40  power#5 data coming in power#5 rawData 有
# 7/06 08:25  Power#5 error ~ 7/17 17:40

# 7/16

exit 0