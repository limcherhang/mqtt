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


def getTank(conn,name,gId):
    with conn.cursor() as cursor_0:
        sql = f"SELECT tankCapacity FROM mgmtETL.V3API where gatewayId = {gId} and name = '{name}'"
        cursor_0.execute(sql)
        logging.info(sql)
        for tanks in cursor_0:
            tank = tanks[0]
            return tank

def count(conn,st,et):
    value_string = ''
    with conn.cursor() as cursor:
        sqlCommand = f"SELECT dataETLName,name,siteId,gatewayId FROM mgmtETL.NameList where tableDesc='car'"
        cursor.execute(sqlCommand)
        logging.info(sqlCommand)
        for rows in cursor:
            km_list = []
            fuel_list = []
            ts_list = []
            etlName = rows[0]
            name = rows[1]
            sId = rows[2]
            gId = rows[3]
            km = 0
            result = 0
            tank = getTank(conn,etlName,gId)
            with conn.cursor() as data_cursor:
                sql =  f"""SELECT ts,mileage,fuelLevel,speed FROM dataETL.car 
                            where fuelLevel != 0 and name = '{etlName}'
                            and ts >= '{st}' and ts < '{et}'
                            order by ts asc 
                        """
                data_cursor.execute(sql)
                logging.info(sql)
                if data_cursor.rowcount == 0:
                    logging.info (f"'{st}' to '{et}' has no data"  )
                    continue
                else:
                    for row in data_cursor:
                        ts = row[0]
                        mileage = row[1]
                        fuel_level = row[2]
                        speed = row[3]
                        if ts_list == []:
                            km_list.insert(0,mileage)
                            fuel_list.insert(0,fuel_level)

                        ts_list.append(ts)
                        km_list.append(mileage)
                        fuel_list.append(fuel_level)
                        
                    
                    km_list_df = np.diff(km_list)
                    fuel_list_df = np.diff(fuel_list)
                   
                    for ts in ts_list:
                        index = ts_list.index(ts)
                        if fuel_list_df[index] < 0:
                            km += km_list_df[index]
                            result += fuel_list_df[index]
                                      
                        else:
                            km += km_list_df[index]
                            result += 0

                        total = (result/100)*tank       
                        value_string += f"('{ts}','{name}',{sId},{km_list[index+1]},{fuel_list[index+1]},{km},{abs(result)},{abs(total)},{speed}), "
                        
                        
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
