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

ieees = ['00124b00192f22d8']

value_string = ''
number = 0
for ieee in ieees:
    number += 1
    name = f'Wetness#{number}'

    with prod_conn.cursor() as prod_cursor:
        sqlCommand = f"select gatewayId, receivedSync, substring(responseData,7,4), substring(responseData,11,4) from iotmgmt.zigbeeRawModbus where ieee='{ieee}' and modbusCmd='010300000002c40b' and receivedSync>='{st}' and receivedSync<'{et}'"
        logging.debug(sqlCommand)
        prod_cursor.execute(sqlCommand)

        for data in prod_cursor:
            logging.debug(data)
            gId = data[0]
            ts = data[1].replace(second=0)
            
            temp = (int(data[2], 16)-65536)/100 if int(data[2], 16)>61536 else int(data[2], 16)/100
            wetness = int(data[3], 16)/100

            value_string += f"('{ts}', {gId}, '{name}', {temp}, {wetness}), "
        else:
            prod_conn.rollback()

if value_string != '':
    value_string = value_string[:-2]

    with prod_conn.cursor() as rd_cursor:
        replace_sql = f"replace into `dataETL`.`wetness` (`ts`, `gatewayId`, `name`, `temp`, `wetness`) Values {value_string}"
        try:
            rd_cursor.execute(replace_sql)
            prod_conn.commit()
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}\n[replace ERROR]: {str(ex)}")

prod_conn.close()
logging.debug(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
