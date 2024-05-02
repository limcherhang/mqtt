import pymysql
import time
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta

def connectDB(host):
    try:
        conn=pymysql.connect(
            host=host,
            read_default_file='~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")
    
logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
    level = logging.ERROR, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s',
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- Now: {nowTime} ---------- Program Start!")

st = (nowTime-timedelta(minutes=64)).replace(second=0)
et = nowTime
logging.debug(f"----- Processing from {st} to {et} -----")

conn = connectDB('127.0.0.1')
cursor = conn.cursor()
sqlCommand = f"select siteId, name, gatewayId, dataETLName, dataETLValue from mgmtETL.NameList where tableDesc='temp' and gatewayId in (223, 261) and protocol is not NULL"
cursor.execute(sqlCommand)

value_string = ''
for rows in cursor:
    sId = rows[0]
    name = rows[1]
    gId = rows[2]
    etlName = rows[3]
    etlValue = ('null' if rows[4] is None else (int(rows[4])))
    
    logging.info(f"----- Processing {sId} {name} -----")

    with conn.cursor() as data_cursor:
        sqlCommand = f"select * from dataETL.temp where ts>='{st}' and ts<'{et}' and gatewayId={gId} and name='{name}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"GatewayId:{gId} {etlName} doesn't have data from {st} to {et}")
            continue
        else:
            for data in data_cursor:
                ts = data[0]
                temp = data[3 + etlValue]
                logging.debug(f"'{ts}', {sId}, '{name}', {temp}")
                value_string += f"('{ts}', {sId}, '{name}', {temp}), "

if value_string != '':
    value_string = value_string[:-2]
    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataPlatform`.`temp` (`ts`, `siteId`, `name`, `temp`) Values {value_string}"
        try:
            cursor.execute(replace_sql)
            conn.commit()
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

cursor.close()
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
