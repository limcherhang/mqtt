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

name=["pressure#2", "pressure#3", "pressure#4", "pressure#5"]
devEUI=["24e124710c408878" ,"24e124710c408261" ,"24e124710c408409" ,"24e124710c408901"]
value_string=''
count=0
for rows in name:
    with conn.cursor() as cursor:
        #sqlCommand =f""""REPLACE INTO dataPlatform.pirTrigger (ts, siteId, name, pirTrigger) SELECT 
        sqlCommand =f"""SELECT 
                        ts,
                        '85',
                        '{rows}',
                        data->'$.pressure' as pressure
                        FROM rawData.mqttIAQ 
                        where 
                        data->'$.devEUI' ='{devEUI[count]}' and 
                        ts >= '{st}' and 
                        ts < '{et}' and data->'$.pressure' is not NULL;
                    """
        cursor.execute(sqlCommand)
        logging.info(sqlCommand)
        count +=1
        for row in cursor:
                    ts = row[0]
                    siteId = row[1]
                    name = row[2]
                    pressure = row[3]
                    value_string+=f"('{ts}',85,'{name}',{pressure}), "

if value_string != '':
    value_string=value_string[:-2]
    with conn2.cursor() as cursor2:
        sql2 = f" REPLACE INTO dataPlatform.pressure (ts, siteId, name, pressure) Values {value_string}"
        cursor2.execute(sql2)
        logging.info(sql2)
        logging.info("replace succeed")

conn.commit()
conn2.commit()
logging.info(f"----- Replacing Succeed ----- ")
conn.close()
conn2.close()
logging.info("----- Connections Closed -----")