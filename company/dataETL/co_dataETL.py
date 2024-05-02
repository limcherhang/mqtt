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

st = (nowTime-timedelta(minutes=2)).replace(second=0)
et = nowTime
#st = datetime(2022, 3, 8)
#et = datetime(2022, 3, 9)

logging.debug(f"----- Processing from {st} to {et} -----")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1 :
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')

my_cursor = my_conn.cursor()
sqlCommand = f"SELECT name, ieee, gatewayId FROM mgmtETL.Device where name like 'AirQuality#%' and gatewayId=181"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    name = rows[0]
    ieee = rows[1]
    gId = rows[2]

    if ieee != '00124b0019309bf5': continue

    logging.debug(f"----- Processing {gId} {ieee} -----")

    with my_conn.cursor() as data_cursor:
        if history_flag:
            #                                                    #iotdata
            sqlCommand = f"select receivedSync, responseData from iotmgmt{st.year}.zigbeeRawModbus_{st.month:02} where gatewayId=181 and ieee='{ieee}' and modbusCmd='010300000001840a' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select receivedSync, responseData from iotmgmt.zigbeeRawModbus where gatewayId=181 and ieee='{ieee}' and modbusCmd='010300000001840a' and ts>='{st}' and ts<'{et}'"
        
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"GatewayId: {gId} has no data in the minute")
            continue
        else:
            for data in data_cursor:
                logging.debug(data)
                ts = data[0]
                rawData = data[1][6:-4]
                co = int(rawData, 16)
                #logging.debug(f"{ts} {rawData}")
                value_string += f"('{ts}', {gId}, '{name}', {co}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataETL`.`airQuality` (`ts`, `gatewayId`, `name`, `CO`) Values {value_string}"
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
