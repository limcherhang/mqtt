#!/bin/bash
# Program:
PATH=~/bin:/usr/sbin:$PATH

if [ "${1}" == "" ]; then
        echo "請輸入 bash Run.sh 2020-09-17"
        exit 1
fi

echo "python3 v3API_history.py ${1}"
python3 v3API_history.py ${1}

#dataETL
echo "python3 v3RawToETL_history.py ${1}"
python3 v3RawToETL_history.py ${1}

#dataPlatfrom
echo "python3 v3ETLTodataPlatform_history.py ${1}"
python3 v3ETLTodataPlatform_history.py ${1}

echo "python3 v3car79_history.py ${1}"
python3 v3car79_history.py ${1}

exit 0