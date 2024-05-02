import requests
import os
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import pymysql
import time
import json
import configparser
import sys
def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.info(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")


def getApi(type,action,key,label,start,end):
    value_string = ''
    params = {
        'key': key, 
        'type': type,
        'action':action,
        'label':label,
        'start':start,
        'end':end 
    }
    
    url = f"https://www.v3nity.com/V3Nity4/api"
    resp = requests.get(url, params=params)
    if resp.status_code == requests.codes.ok:
        data_list = resp.json()
        for item in data_list['data']:
           
            ts = item['timestamp']
            ts = datetime.strptime(ts, '%d-%m-%Y %H:%M:%S').strftime('%Y-%m-%d %H:%M:%S')
            raw = json.dumps(item)
            label = item['label']
            value_string += f"('{datetime.now()}','{ts}',262,'{label}','{raw}'), "
    
        if value_string != '':
            
            value_string = value_string[:-2]
            with conn.cursor() as cursor:
                replace_sql = f"replace into rawData.v3API(DBts,APIts,GatewayId,label,rawdata) VALUES {value_string}"       
                try:
                    cursor.execute(replace_sql)
                    logging.info(replace_sql)
                    conn.commit()  
                    logging.info(f"----- Connection Commit -----")  
                except Exception as ex:
                    logging.error(f"SQL: {replace_sql}")
                    logging.error(f"[Replace ERROR]: {str(ex)}")
            
    else:
        logging.error(f"resp.status_code: {resp.status_code}")

file = __file__
basename = os.path.basename(file)
filename = os .path.splitext(basename)[0]
logging.basicConfig(
    
    handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)
try:
    config = configparser.ConfigParser()
    config.read('config.ini')
    key = config['api_key']['key']
    track = config['api_history']['type']
    action = config['api_history']['action']
    
except Exception as ex:
    logging.error(f"[Config Error]: {str(ex)}")

s=time.time()
nowTime = datetime.now().replace(microsecond=0)
date = sys.argv[1]
data =  date.split('-')
nowTime = datetime.now().replace(year=int(data[0]),month=int(data[1]),day=int(data[2]),hour=0,minute=0,second=0,microsecond=0)
st = nowTime.strftime("%Y%m%d000000")
et = (nowTime+timedelta(days=1)).strftime("%Y%m%d000000")
print(st)
print(et)
logging.info(f"---------- now: {nowTime} ----------")
conn=connectDB('127.0.0.1')
with conn.cursor() as cursor:
    sql = f"SELECT label FROM mgmtETL.V3API where siteId = 87"
    cursor.execute(sql)
    for row in cursor:
        label = row[0]
        getApi(track,action,key,label,st,et)
    
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")

