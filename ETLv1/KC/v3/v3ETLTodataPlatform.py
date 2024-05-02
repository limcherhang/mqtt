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
        sql2 = f"SELECT ts,mileage,fuelLevel,distance,fuelConsumption FROM dataPlatform.car where name = '{name}' and siteId = 87 and ts >='{stime}' and ts < '{etime}' order by ts desc limit 1 ;"
        cursor.execute(sql2)
        logging.info(sql2)
        if cursor.rowcount==0:
            return None,None,None,None,None
        else:
            for data in cursor:
                ts = data[0]
                mileage = data[1]
                fuel = data[2]
                distance = data[3]
                total = data[4]

            return ts,mileage,fuel,distance,total



def count(conn,st,et):
    value_string = ''
    with conn.cursor() as cursor_0:
        sql = f"SELECT siteId,gatewayId,name,tankCapacity FROM mgmtETL.V3API "
        cursor_0.execute(sql)
        logging.info(sql)
        for car in cursor_0:
            sId = car[0]
            gId = car[1]
            etlName = car[2]
            tank = car[3]
            with conn.cursor() as cursor:
                sqlCommand = f"SELECT name FROM mgmtETL.NameList where siteId = {sId} and gatewayId = {gId} and dataETLName = '{etlName}'"
                cursor.execute(sqlCommand)
                logging.info(sqlCommand)
                for rows in cursor:
                    name = rows[0]
                    with conn.cursor() as data_cursor:
                        sql =  f"""SELECT ts,mileage,fuelLevel,speed FROM dataETL.car 
                                    where fuelLevel != 0 and name = '{etlName}'
                                    and ts >= '{st}' and  ts < '{et}' and gatewayId = {gId}
                                    order by ts asc 
                                """
                        data_cursor.execute(sql)
                        logging.info(sql)
                        if data_cursor.rowcount == 0:
                            logging.info (f"'{st}' to '{et}' has no data"  )
                            continue
                        else:
                            last_ts,last_mileage,last_fuel,last_distance,last_total = getlast(conn,name,st)
                            for row in data_cursor:
                                ts = row[0]
                                mileage = row[1]
                                fuel_level = row[2]
                                speed = row[3]
                                distance = 0
                                total = 0
                                total_fuel = 0

                                if last_ts is None:
                                    value_string += f"('{ts}','{name}',{sId},{mileage},{fuel_level},{distance},{total},{total_fuel},{speed}), "

                                elif ts < last_ts:
                                    continue
                                else :
                                    
                                    km = mileage - last_mileage
                                    last_mileage = mileage
                                    distance =  last_distance + km
                                    last_distance = distance
                                    
                                    fuel = fuel_level - last_fuel
                                    if fuel < 0:
                                        last_fuel = fuel_level
                                        total = last_total + abs(fuel)
                                        total_fuel = (total/100)*tank
                                        last_total = total
                                    else:
                                        last_fuel = fuel_level
                                        total = last_total 
                                        total_fuel = (total/100)*tank
                                        
                                    value_string += f"('{ts}','{name}',{sId},{mileage},{fuel_level},{distance},{total},{total_fuel},{speed}), "
                        

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
st = nowTime-timedelta(minutes=60)
et = nowTime
if datetime.date(et) > datetime.date(st):
    et = datetime.now().replace(hour=0,minute=0,second=0,microsecond=0)
count(conn,st,et)
conn.commit()  
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
