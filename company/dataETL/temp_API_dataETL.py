import pymysql
import requests
import json
import time
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import urllib3

def connectDB(host):
	try:
		conn=pymysql.connect(
			host=host,
			read_default_file='~/.my.cnf'
		)
		logging.debug(f"IP: {host} Connection Succeed")
		return conn
	except Exception as ex:
		logging.error(f"[Connection ERROR]: {str(ex)}")
	return None

logging.basicConfig(
	handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
	level = logging.INFO, 
	format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
	datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ----------")

st = (nowTime - timedelta(minutes=63)).replace(second=0, microsecond=0)
et = nowTime
logging.info(f"----- Searching from {st} to {et} -----")

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

uid_dict = {
    'Temp#1':'000B78FFFE0750AF', 'Temp#3':'000B78FFFE0750B0', # 'Temp#2':'000B78FFFE0750B0'
    'Temp#4':'000B78FFFE0750B2', 'Temp#5':'000B78FFFE0750B3', 'Temp#6':'000B78FFFE0750B4', 
    'Temp#7':'000B78FFFE0750B5', 'Temp#8':'000B78FFFE0750B6', # 'Temp#9':'000B78FFFE0750B7', 
    'Temp#10':'000B78FFFE0750C3', 'Temp#11':'000B78FFFE0750C4', 'Temp#12':'000B78FFFE0750C5', 
    'Temp#13':'000B78FFFE0750C6' # 'Temp#14':'000B78FFFE0750C7'
}

conn = connectDB('127.0.0.1')
value_string = ''
date = datetime.now().strftime('%Y-%m-%d')
for name, ieee in uid_dict.items():

    logging.info(f"----- Processing GatewaId:223 {ieee} {name} -----")

    data_url = f"https://custname.kiwi-alert.com/api/sensor/get-values?UID={ieee}/Temp&fromDate={date}"
    data_resp = requests.get(data_url, auth=('api', 'VKLJdENESRNfoqOTxRz8Jh'), verify=False)
    logging.debug(data_resp.url)

    if data_resp.status_code == requests.codes.ok:
        data_list = json.loads(data_resp.text)
        if len(data_list) > 0:
            for data in data_list:
                APIts = data['DateTimeSGT'].replace('T', ' ').replace('Z', ' ')
                temp = ('NULL' if data['v'] is None else data['v'])
                logging.debug(f"'{APIts}', 223, '{name}', {temp}")
                value_string += f"('{APIts}', 223, '{name}', {temp}), "
        else:
            logging.warning(f"GatewayId:223 {ieee} {name} doesn't have data now")

if value_string != '':
    value_string = value_string[:-2]
    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataETL`.`temp` (`ts`, `gatewayId`, `name`, `temp1`) Values {value_string}"
        try:
            logging.debug(replace_sql)
            cursor.execute(replace_sql)
            conn.commit()
        except Exception as ex:
            logging.debug(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

conn.close()
logging.info(f"------ Connection closed ------ took:{time.time()-s}s")
