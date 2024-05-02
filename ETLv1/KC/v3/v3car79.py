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
            read_default_file = '~/.my.cnf'
        )
        logging.info(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")

def getlast(conn,name,st):
    stime = datetime.date(st)
    etime = stime+timedelta(days=1)
    with conn.cursor() as cursor:
        sql2 = f"SELECT mileage,distance FROM dataPlatform.car where name = '{name}' and siteId = 87 and ts >='{stime}' and ts < '{etime}' order by ts desc limit 1 ;"
        cursor.execute(sql2)
        logging.info(sql2)
        if cursor.rowcount == 0 :
            return None,None
        else:
            for data in cursor:
              
                mileage = data[0]
                distance = data[1]

            return mileage,distance

def count(conn,st,et):
    value_string = ''
    names = ['Car#7','Car#9','Car#3','Car#6','Car#11','Car#12','Car#16','Car#22','Car#23']
    for name in names:
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
                last_mileage,last_distance = getlast(conn,name,st)
                for row in data_cursor:
                    ts = row[0]
                    mileage = row[1]
                    speed = row[2]
                    if last_mileage is None or last_distance is None:
                        last_mileage = mileage
                        last_distance = 0
                        distance = last_distance
                    else :
                        km = mileage - last_mileage
                        last_mileage = mileage
                        
                        distance = last_distance + km
                        last_distance = distance

                    value_string += f"('{ts}','{name.lower()}', 87, {mileage},null,{distance},null,null,{speed}), "
                        

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into dataPlatform.car(ts,name,siteId,mileage,fuelLevel,distance,fuelConsumption,totalFuelConsumption,speed) VALUES {value_string}"       
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
nowTime = datetime.now().replace(microsecond=0)
conn=connectDB('127.0.0.1','username','password')
logging.info(f"---------- now: {nowTime} ----------")
st = nowTime-timedelta(minutes=30)
et = nowTime
if datetime.date(et) > datetime.date(st):
    et = datetime.now().replace(hour=0,minute=0,second=0,microsecond=0)
count(conn,st,et)
conn.commit()  
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
