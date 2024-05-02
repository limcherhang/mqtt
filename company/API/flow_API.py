import pymysql
from datetime import datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler
import time

def connectDB(host):
    try:
        conn = pymysql.connect(host=host, read_default_file='~/.my.cnf')
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Failed]: {str(ex)}")

def cal_flowrate(conn, gId, meterId, ts, total):
    global history_flag

    with conn.cursor() as cursor:
        if history_flag:
            sqlCommand = f"select GWts, Raw from rawData{st.year}.RESTAPI_{st.month:02} where GWts<'{ts}' and gatewayId={gId} and meterId='{meterId}' order by GWts desc limit 1"
        else:
            sqlCommand = f"select GWts, Raw from rawData.RESTAPI where GWts<'{ts}' and gatewayId={gId} and meterId='{meterId}' order by GWts desc limit 1"
        cursor.execute(sqlCommand)

        if cursor.rowcount == 0:
            flowrate = 0
        else:
            data = cursor.fetchone()
            if data is not None:
                pre_ts = data[0]
                pre_total = float(data[1])
                flowrate = round(total-pre_total, 3)/round((ts - pre_ts).seconds/3600, 2)    

    return flowrate

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'/home/ecoprog/DATA/API/log/{__file__}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"------------ Now: {nowTime} ------------ Program Started !")

st = (nowTime-timedelta(minutes=18)).replace(second=0)
et = nowTime
#st = datetime(2022, 4, 12)
#et = datetime(2022, 4, 13)
logging.info(f"---------- Processing from {st} to {et} ----------")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')

meterIds = {'Flow#1':'CT L8', 'Flow#2':'CT L50'}

value_string = ''
for name, meterId in meterIds.items():
    ieee = f"182_{name}"
    logging.debug(f"----- Processing {name} {ieee} -----")

    with my_conn.cursor() as my_cursor:
        if history_flag:
            sqlCommand = f"select GWts, gatewayId, Raw from rawData{st.year}.RESTAPI_{st.month:02} where DBts>='{st}' and DBts<'{et}' and meterId='{meterId}'"
        else:
            sqlCommand = f"select GWts, gatewayId, Raw from rawData.RESTAPI where DBts>='{st}' and DBts<'{et}' and meterId='{meterId}'"
        my_cursor.execute(sqlCommand)

        if my_cursor.rowcount == 0:
            logging.warning(f"{meterId} has no data from {st} to {et}")
            continue
        else:
            for data in my_cursor:
                ts = data[0]
                gId = data[1]
                flowTotalPositive = float(data[2])
                flowInstant = cal_flowrate(my_conn, gId, meterId, ts, flowTotalPositive)

                logging.info(f"{ts}, {gId}, {ieee}, {flowInstant}, {flowTotalPositive}")
                value_string += f"('{ts}', 182, '{ieee}', '{ts}', {flowInstant}, {flowTotalPositive}), "


if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        insert_sql = f"insert into `iotmgmt`.`flowTMR2RMT` (`ts`, `gatewayId`, `ieee`, `receivedSync`, `flowInstant`, `flowTotalPositive`) Values {value_string}"
        try:
            my_cursor.execute(insert_sql)
            my_conn.commit()
        except Exception as ex:
            logging.error(f"SQL: {insert_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")
        finally:
            my_conn.close()
        
logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")