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

st = (nowTime-timedelta(minutes=3)).replace(second=0)
et = nowTime
logging.debug(f"----- Processing from {st} to {et} -----")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1 :
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')
my_cursor = my_conn.cursor()
sqlCommand = f"select siteId, name, tableDesc, gatewayId, protocol, dataETLName, dataETLValue from mgmtETL.NameList where tableDesc='humidity' and gatewayId>0 and protocol is NOT NULL"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    sId = rows[0]
    name = rows[1]
    table = rows[2]
    gId = rows[3]
    protocol = rows[4]
    etlName = rows[5]
    etlValue = (rows[6] if rows[6] is None else rows[6])

    logging.debug(f"----- Processing {sId} {name} -----")

    if protocol != 'Name': continue

    string = etlName.split('#')[0]
    if string == 'TwoInOne':
        table = 'twoInOne'
    elif string == 'ThreeInOne':
        table = 'threeInOne'
    elif string == 'AirQuality':
        table = 'airQuality'
    
    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select ts, humidity from dataETL{st.year}.{table}_{st.month:02} where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select ts, humidity from dataETL.{table} where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"GatewayId: {gId} has no data in the minute")
            continue
        
        for data in data_cursor:
            ts = data[0]
            humidity = ('NULL' if data[1] is None else data[1])

            value_string += f"('{ts}', {sId}, '{name}', {humidity}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataPlatform`.`humidity` (`ts`, `siteId`, `name`, `humidity`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

my_conn.commit()
my_cursor.close()
my_conn.close()
logging.debug(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
