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
logging.info(f"---------- Now: {nowTime} ---------- Program Started!")

st = (nowTime-timedelta(minutes=2)).replace(second=0)
et = nowTime
logging.debug(f"----- Processing from {st} to {et} -----")

conn = connectDB('127.0.0.1')

cursor = conn.cursor()

sqlCommand = f"select siteId, name, tableDesc, gatewayId, protocol, dataETLName, dataETLValue from mgmtETL.NameList where protocol is not NULL and gatewayId>0 and dataETLName like 'Env.#%'"
logging.debug(sqlCommand)
cursor.execute(sqlCommand)

for rows in cursor:
    sId = rows[0]
    name = rows[1]
    table = rows[2]
    if table == 'illuminance':
        column = 'light'
    elif table == 'noise':
        column = 'dB'
    else:
        column = table
    gId = rows[3]
    protocol = rows[4]
    etlName = rows[5]
    etlValue = rows[6]
    
    with conn.cursor() as data_cursor:
        sqlCommand = f"select * from dataETL.environment where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            continue
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            value = data[3+int(etlValue)]

            with conn.cursor() as replace_cursor:
                replace_sql = f"replace into `dataPlatform`.`{table}` (`ts`, `siteId`, `name`, `{column}`) Values ('{ts}', {sId}, '{name}', {value})"
                logging.debug(replace_sql)
                try:
                    replace_cursor.execute(replace_sql)
                except Exception as ex:
                    logging.error(f"SQL: {replace_sql}\n[{sId} replace ERROR]: {str(ex)}")

conn.commit()
cursor.close()
conn.close()
logging.info(f"----- Connection Closed ----- took {round(time.time() - s)}s")
