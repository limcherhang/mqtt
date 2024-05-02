import pymysql
import time
from datetime import datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler

def connectDB(host):
	try:
		conn=pymysql.connect(
			host=host,
			read_default_file='~/.my.cnf'
		)
		logging.debug(f"IP: {host} Connection Succeed")
		return conn
	except Exception as ex:
		logging.error(f"[Connection ERROR]: {str(ex)}")
	return None

logging.basicConfig(
	handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
	level = logging.ERROR, 
	format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
	datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ----------")

st = (nowTime - timedelta(minutes=3)).replace(second=0)
et = nowTime

conn = connectDB('127.0.0.1')

value_string = ''
cursor = conn.cursor()
sqlCommand = f"SELECT siteId, name, ieee FROM mgmtETL.Device where deviceType=3 and deviceLogic=1"
cursor.execute(sqlCommand)

for rows in cursor:
    sId = rows[0]
    name = rows[1]
    ieee = rows[2]
    
    logging.info(f"----- Processing {name} {ieee} -----")

    with conn.cursor() as data_cursor:
        sqlCommand = f"select gatewayId, receivedSync, temp, humidity from iotmgmt.co2 where receivedSync>='{st}' and receivedSync<'{et}' and ieee='{ieee}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"IEEE: {ieee} doesn't have data from {st} to {et}")
            continue
        else:
            for data in data_cursor:
                logging.debug(data)
                gId = data[0]
                ts = data[1].replace(second=0)
                temp = ('NULL' if data[2] is None else data[2])
                temp = round((temp * 10 / 65535 * 175) - 45, 2)
                humidity = ('NULL' if data[3] is None else data[3])
                humidity = round((humidity * 10 / 65535 * 100), 2)

                value_string += f"('{ts}', {gId}, '{name}', {temp}, {humidity}), "

if value_string != '':
    value_string = value_string[:-2]
    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataETL`.`twoInOne` (`ts`, `gatewayId`, `name`, `temp`, `humidity`) Values {value_string}"
        try:
            logging.debug(replace_sql)
            cursor.execute(replace_sql)
            conn.commit()
        except Exception as ex:
            logging.debug(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

cursor.close()
conn.close()
logging.info(f"------ Connection closed ------ took:{round(time.time()-s, 3)}s")
