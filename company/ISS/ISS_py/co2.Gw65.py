import pymysql
from datetime import datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler
import time
import os
def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            port = 44206, 
            user = 'eco',
            passwd = 'ECO4ever' 
            #read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")
    return None

def connectDB_2(host):
    try:
        conn = pymysql.connect(
            host = host,
            port = 3306, 
            #user = 'eco',
            #passwd = 'ECO4ever' 
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")
    return None

file = __file__
basename = os.path.basename(file)
filename = os .path.splitext(basename)[0]
logging.basicConfig(
	#handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
    handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
	level = logging.INFO, 
	format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
	datefmt = '%Y-%m-%d %H:%M:%S'
)

nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ----------")
st=(nowTime-timedelta(minutes=10)).replace(second=0)
et=nowTime
logging.info(f"----- Searching from {st} to {et} -----")

conn=connectDB('sg.evercomm.com')
conn2 = connectDB_2('127.0.0.1')

name=['co2#2','co2#3',"co2#4","co2#5" ,"co2#6" ,"co2#7" ,"co2#8" ,"co2#9"]
devEUI=["24e124710c409721" ,"24e124710c341712" ,"24e124710c408617" ,"24e124710c341912" ,"24e124710c340839", "24e124710c341766", "24e124710c341272", "24e124710c340856"]

value_string=''
count=0
for rows in name:
    with conn.cursor() as cursor:
        #sqlCommand =f"""REPLACE INTO dataPlatform.co2 (ts, siteId, name, co2) SELECT 
        #            ts,
        #            '65',
        #            '{rows}',
        #            data->'$.co2' as co2
        #            FROM rawData.mqttIAQ 
        #            where 
        #            data->'$.devEUI' ='{devEUI[count]}' and 
        #            ts >= "{st}" and 
        #            ts < '{et}'and data->'$.co2' is not NULL;
        #            """
        #logging.info(sqlCommand)
        sql = f"""  SELECT 
                    ts,
                    '65',
                    '{rows}',
                    data->'$.co2' as co2
                    FROM rawData.mqttIAQ 
                    where 
                    data->'$.devEUI' ='{devEUI[count]}' and 
                    ts >= "{st}" and 
                    ts < '{et}'and data->'$.co2' is not NULL;
                    """
        cursor.execute(sql)
        count +=1
        for row in cursor:
            ts = row[0]
            siteId = row[1]
            name = row[2]
            co2 = row[3]
            value_string+=f"('{ts}',65,'{name}',{co2}), "


if value_string != '':
    value_string=value_string[:-2]
    with conn2.cursor() as cursor2:
        sql2 = f" REPLACE INTO dataPlatform.co2 (ts, siteId, name, co2) Values {value_string}"
        cursor2.execute(sql2)
        logging.info(sql2)
        logging.info("replace succeed")
conn.commit()
conn2.commit()
logging.info(f"----- Replacing Succeed ----- ")
conn.close()
conn2.close()
logging.info("----- Connections Closed -----")