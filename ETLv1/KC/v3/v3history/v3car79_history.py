import numpy as np
import os
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import pymysql
import time
import sys

def connectDB(host,username,password):
    try:
        conn = pymysql.connect(
            host = host, 
            port = 3306,
            user = username,
            passwd = password 
            #read_default_file = '~/.my.cnf'
        )
        logging.info(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")


def count(conn,st,et):
    value_string = ''
    names = ['Car#7','Car#9']
    for name in names:   
        km_list = [] 
        with conn.cursor() as data_cursor:
            sql =  f"""SELECT ts,mileage,speed FROM dataETL.car 
                        where fuelLevel = 0 and name = '{name}'
                        and ts >= '{st}' and ts < '{et}'
                        order by ts asc 
                    """
            data_cursor.execute(sql)
            logging.info(sql)
            if data_cursor.rowcount == 0:
                logging.info (f"'{st}' to '{et}' has no data"  )
                continue
            else:
                count = 0
                for row in data_cursor:
                    ts = row[0]
                    mileage = row[1]
                    speed = row[2]
                    if km_list == []:
                        km = 0
                        km_list.append(mileage)
                    else:
                        km_list.append(mileage)
                        km_df = np.diff(km_list)
                        km+=km_df[count]
                        count+=1
               
                    value_string += f"('{ts}','{name.lower()}',87,{mileage},null,{km},null,{speed}), "
                    
                        
    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into dataPlatform.car(ts,name,siteId,mileage,fuelLevel,distance,totalConsumption,speed) VALUES {value_string}"       
            try:
                print(replace_sql)
                cursor.execute(replace_sql)
                logging.info(replace_sql)
                
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")

file = __file__
basename = os.path.basename(file)
filename = os .path.splitext(basename)[0]
logging.basicConfig(
    
    handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s=time.time()
date = sys.argv[1]
data =  date.split('-')
nowTime = datetime.now().replace(year=int(data[0]),month=int(data[1]),day=int(data[2]),hour=0,minute=0,second=0,microsecond=0)
conn=connectDB('127.0.0.1','username','password')
logging.info(f"---------- now: {nowTime} ----------")
st = nowTime
et = nowTime+timedelta(days=1)
count(conn,st,et)
conn.commit()  
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
