from curses import raw
from urllib import response
import pymysql
import time
import struct
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta

def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host, 
            read_default_file = f'~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
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
#et = datetime.now()
logging.info(f"---------- Processing from {st} to {et} ----------")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

#prod_conn = connectDB('192.168.1.62')
my_conn = connectDB('127.0.0.1')

my_cursor = my_conn.cursor()
sqlCommand = f"SELECT name, ieee, gatewayId FROM mgmtETL.Device where gatewayId=164 and name like 'Gas#%'"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    name = rows[0]
    ieee = rows[1]
    gId = rows[2]

    logging.debug(f"----- Processing {gId} {ieee} -----")
    if name.split('#')[-1] == '1':
        modbuscmd = '030300080002442b'
    elif name.split('#')[-1] == '2':
        modbuscmd = '040300080002459c'
    else:
        modbuscmd = '01030008000245c9'
    
    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select receivedSync, responseData from iotdata{st.year}.zigbeeRawModbus_{st.month:02} where gatewayId={gId} and ieee='{ieee}' and receivedSync>='{st}' and receivedSync<'{et}' and modbusCmd='{modbuscmd}'"
        else:
            sqlCommand = f"select receivedSync, responseData from iotmgmt.zigbeeRawModbus where gatewayId={gId} and ieee='{ieee}' and receivedSync>='{st}' and receivedSync<'{et}' and modbusCmd='{modbuscmd}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"GatewayId: {gId} {ieee} has no data during the minute")
            continue
        else:
            for data in data_cursor:
                logging.debug(data)
                ts = data[0].replace(second=0)
                responseData = data[1][6:-4]
                #s1 = responseData[:4]
                #s2 = responseData[-4:]
                #rawdata = s1+s2
                gas = struct.unpack('!f', bytes.fromhex(responseData))[0]
                #gas = gasRaw * 0.8348 # remove on 18th Oct
                logging.info(f"('{ts}', {gId}, '{name}', {round(gas, 3)})")
                value_string += f"('{ts}', {gId}, '{name}', {round(gas, 3)}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataETL`.`gas` (`ts`, `gatewayId`, `name`, `gas`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")


my_conn.commit()
my_cursor.close()
my_conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
