import pymysql
import time
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import numpy as np

def connectDB(host):
    try:
        conn = pymysql.connect(
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
#nowTime = datetime(2022, 2, 25)
logging.info(f"---------- Now: {nowTime} ---------- Program Started !")

st = (nowTime-timedelta(days=1)).replace(hour=0, minute=0, second=0)
et = nowTime.replace(hour=0, minute=0, second=0)
logging.debug(f"---------- fronm {st} to {et} ----------")

date = st.strftime('%Y-%m-%d')
logging.info(f"---------- Processing Date: {date} ----------")


if (datetime.now().replace(hour=0, minute=0, second=0, microsecond=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')
my_cursor = my_conn.cursor()
sqlCommand = f"SELECT siteId, name FROM mgmtETL.NameList where tableDesc='co' and gatewayId>0 and protocol is Not NULL"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    sId = rows[0]
    name = rows[1]
    logging.info(f"----- Processing {sId} {name} -----")

    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select CO from dataPlatform{st.year}.co_{st.month:02} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select CO from dataPlatform.co where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

    if data_cursor.rowcount == 0:
        logging.warning(f"SQL: {sqlCommand}")
        logging.warning(f"SiteId: {sId} has no data on {date}")
        continue
    
    data_list = []
    for data in data_cursor:
        if data[0] is not None: data_list.append(data[0])
    
    if len(data_list) != 0:
        coMin = round(np.percentile(np.array(data_list), 0), 2)
        co25th = round(np.percentile(np.array(data_list), 25), 2)
        coMedian = round(np.percentile(np.array(data_list), 50), 2)
        co75th = round(np.percentile(np.array(data_list), 75), 2)
        coMax = round(np.percentile(np.array(data_list), 100), 2)
    
    value_string += f"('{date}', {sId}, '{name}', {coMin}, {co25th}, {coMedian}, {co75th}, {coMax}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `reportPlatform{st.year}`.`Dco` (`date`, `siteId`, `name`, `coMin`, `co25th`, `coMedian`, `co75th`, `coMax`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

my_conn.commit()
my_cursor.close()
my_conn.close()
logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")
