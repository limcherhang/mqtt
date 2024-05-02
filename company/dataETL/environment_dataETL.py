from os import replace
import pymysql
from datetime import datetime, timedelta
import logging
import time

def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Failed]: {str(ex)}")

logging.basicConfig(
    filename = f"./log/{__file__}_{datetime.now().strftime('%Y-%m-%d')}.log",
    level = logging.ERROR, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.debug(f"---------- Now: {nowTime} ---------- Program Start!")

st = (nowTime-timedelta(minutes=2)).replace(second=0)
et = nowTime
logging.debug(f"----- Processing from {st} to {et} -----")

prod_conn = connectDB('127.0.0.1')

ieees = ['00124b0019309c19','00124b0019309e7b']

value_string = ''
number = 0
for ieee in ieees:
    number += 1
    name = f"Env.#{number}"

    logging.debug(f"----- Processing {name} {ieee} -----")

    with prod_conn.cursor() as prod_cursor:
        sqlCommand = f"\
        SELECT gatewayId, receivedSync, \
        substring(responseData, 7, 4) as moisture, \
        substring(responseData, 11, 4) as temp, \
        substring(responseData, 15, 4) as soilMoisture, \
        substring(responseData, 19, 4) as SoilTemp, \
        substring(responseData, 23, 4) as 'PM2.5', \
        substring(responseData, 27, 4) as Co2, \
        substring(responseData, 31, 4) as O2, \
        substring(responseData, 35, 4) as highIlluminance, \
        substring(responseData, 39, 4) as lowIlluminance, \
        substring(responseData, 43, 4) as PM10, \
        substring(responseData, 47, 4) as highPressure, \
        substring(responseData, 51, 4) as lowPressure, \
        substring(responseData, 55, 4) as noise \
        FROM iotmgmt.zigbeeRawModbus where ieee='{ieee}' and modbusCmd = '01030000000d840f' and receivedSync>='{st}' and receivedSync<'{et}' \
        "
        prod_cursor.execute(sqlCommand)
        for data in prod_cursor:
            logging.debug(data)
            gId = data[0]
            ts = data[1].replace(second=0, microsecond=0)
            moisture = int(data[2], 16)/10
            temp = int(data[3], 16)/10
            soilMoisture = int(data[4], 16)/10
            soilTemp = int(data[5], 16)/10
            pm2dot5 = int(data[6], 16)
            co2 = int(data[7], 16)
            o2 = int(data[8], 16)/10
            illuminance = int(data[9]+data[10], 16)
            pm10 = int(data[11], 16)
            pressure = int(data[12]+data[13], 16)/10000
            noise = int(data[14], 16)/10

            value_string += f"('{ts}', {gId}, '{name}', {moisture}, {temp}, {soilMoisture}, {soilTemp}, {pm2dot5}, {co2}, {o2}, {illuminance}, {pm10}, {round(pressure,2)}, {noise}), "
        else:
            prod_conn.rollback()

if value_string != '':
    value_string = value_string[:-2]

    with prod_conn.cursor() as rd_cursor:
        replace_sql = f"replace into `dataETL`.`environment` (`ts`, `gatewayId`, `name`, `moisture`, `temperature`, `soilMoisture`, `soilTemperature`, `pm2.5`, `co2`, `o2`, `illuminance`, `pm10`, `pressure`, `noise`) Values {value_string}"
        try:
            rd_cursor.execute(replace_sql)
            prod_conn.commit()
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}\n[replace ERROR]: {str(ex)}")

prod_conn.close()
logging.debug(f"----- Connection Closed -----")
