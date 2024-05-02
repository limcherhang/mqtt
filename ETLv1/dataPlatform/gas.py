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

def getGas(conn, history_flag, gId, etlName, ts):

    if (ts-timedelta(minutes=1)).day < ts.day:
        date_from = (ts-timedelta(minutes=1)).replace(hour=0, minute=0, second=0)
        date_to = (ts-timedelta(minutes=1)).replace(hour=23, minute=59, second=0)
    else:
        date_from = ts.replace(hour=0, minute=0, second=0)
        date_to = ts - timedelta(minutes=1)

    with conn.cursor() as cursor:
        if history_flag:
            sqlCommand = f"select gas from dataETL{ts.year}.gas_{ts.month:02} where gatewayId={gId} and name='{etlName}' and ts>='{date_from}' and ts<='{date_to}' order by ts desc limit 1"
        else:
            sqlCommand = f"select gas from dataETL.gas where gatewayId={gId} and name='{etlName}' and ts>='{date_from}' and ts<='{date_to}' order by ts desc limit 1"
        logging.debug(sqlCommand)

        try:
            cursor.execute(sqlCommand)
        except Exception as ex:
            logging.error(f"[Select ERROR]: {str(ex)}")
            return None
        
        data = cursor.fetchone()
        if data is None:
            return None
        else:
            return data[0]


def getGas0000(conn, history_flag, gId, etlName, ts):

    date_from = ts.replace(hour=0, minute=0, second=0)
    date_to  = ts.replace(hour=23, minute=59, second=0)

    with conn.cursor() as cursor:
        if history_flag:
            sqlCommand = f"select gas from dataETL{ts.year}.gas_{ts.month:02} where gatewayId={gId} and name='{etlName}' and ts>='{date_from}' and ts<='{date_to}' order by ts asc limit 1"
        else:
            sqlCommand = f"select gas from dataETL.gas where gatewayId={gId} and name='{etlName}' and ts>='{date_from}' and ts<='{date_to}' order by ts asc limit 1"
        logging.debug(sqlCommand)

        try:
            cursor.execute(sqlCommand)
        except Exception as ex:
            logging.error(f"[Select ERROR]: {str(ex)}")
            return None
        
        data = cursor.fetchone()
        if data is None:
            return None
        else:
            return data[0]



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
#st = datetime(2023, 3, 15, 0, 1, 0)
#et = datetime(2023, 3, 16)
logging.info(f"----- Processing from {st} to {et} -----")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1 :
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')
my_cursor = my_conn.cursor()
sqlCommand = f"select siteId, name, tableDesc, gatewayId, protocol, dataETLName, dataETLValue from mgmtETL.NameList where tableDesc='gas' and gatewayId>0 and protocol is not NULL"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    sId = rows[0]
    name = rows[1]
    table = rows[2]
    gId = rows[3]
    protocol = rows[4]
    etlName = rows[5]
    etlValue = (rows[6] if rows[6] is None else int(rows[6]))

    logging.debug(f"----- Processing {sId} {name} -----")

    if protocol != 'Name': continue

    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select ts, gas from dataETL{st.year}.gas_{st.month:02} where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select ts, gas from dataETL.gas where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"GatewayId: {gId} {etlName} has no data in the minute")
            continue
        else:
            for data in data_cursor:
                logging.debug(data)
                ts = data[0]
                gas = data[1] * 10
                gas_mmBTU = gas * 0.08348

                try:
                    prev_gas = getGas(my_conn, history_flag, gId, etlName, ts) * 10
                    if prev_gas is not None: 
                        gasLoad = round(gas - prev_gas, 3)
                        gasLoad_mmBTU = gasLoad * 0.08348
                        logging.info(f"-----{ts} {gas} {prev_gas} {gasLoad} -----")
                    else:
                        gasLoad = 'NULL'
                        gasLoad_mmBTU = gasLoad
                    
                    gas0000 = getGas0000(my_conn, history_flag, gId, etlName, ts) * 10
                    if gas0000 is not None:
                        gasConsumed = round(gas - gas0000, 3)
                        gasConsumed_mmBTU = gasConsumed * 0.08348
                        logging.info(f"-----{ts} {gas} {gas0000} {gasConsumed} -----")
                    else:
                        gasConsumed = 'NULL'
                        gasConsumed_mmBTU = gasConsumed
                    
                    
                    value_string += f"('{ts}', {sId}, '{name}', {round(gas, 3)}, {round(gasLoad, 3)}, {round(gasConsumed, 3)}, {round(gas_mmBTU, 3)}, {round(gasLoad_mmBTU, 3)}, {round(gasConsumed_mmBTU, 3)}), "
                except Exception as ex:
                    logging.error(f"[{sId} {name} Calculation ERROR ({st} ~ {et})]: {str(ex)}")
                    continue

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataPlatform`.`gas` (`ts`, `siteId`, `name`, `gasInm3`, `gasLoadInm3`, `gasConsumedInm3`, `gasInmmBTU`, `gasLoadInmmBTU`, `gasConsumedInmmBTU`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            my_conn.commit()
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

my_cursor.close()
my_conn.close()
logging.debug(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
