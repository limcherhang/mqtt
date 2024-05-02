import logging
import pymysql
import numpy as np
from datetime import datetime, timedelta
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
        logging.debug(f"[Connection ERROR]: {str(ex)}")

logging.basicConfig(
    filename = f"/home/ecoprog/log/{__file__}.log", 
    level = logging.ERROR, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- Now: {nowTime} ---------- Program Start!")

st = nowTime-timedelta(days=1)
year = st.year
st = st.strftime('%Y-%m-%d')
date = st
et = nowTime.strftime('%Y-%m-%d')
logging.debug(f"----- Processing {st} to {et} -----")

rd_conn = connectDB('127.0.0.1')
rd_cursor = rd_conn.cursor()

sqlCommand = f"select siteId, name from mgmtETL.NameList where gatewayId>0 and protocol is not NULL and tableDesc='wetness'"
rd_cursor.execute(sqlCommand)

value_string = ''
for rows in rd_cursor:
    logging.debug(rows)
    sId = rows[0]
    name = rows[1]
    data_list = []
    with rd_conn.cursor() as data_cursor:
        sqlCommand = f"select wetness from dataPlatform.wetness where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        for data in data_cursor:
            wetness = data[0]
            if wetness is not None:
                data_list.append(wetness)
    
    if len(data_list) != 0:
        wetnessMin = round(np.percentile(np.array(data_list), 0) ,2)
        wetnessMedian = round(np.percentile(np.array(data_list), 50) ,2)
        wetnessMax = round(np.percentile(np.array(data_list), 100) ,2)

        value_string += f"('{date}', {sId}, '{name}', {wetnessMin}, {wetnessMedian}, {wetnessMax}), "

if value_string != '':
    value_string = value_string[:-2]
    with rd_conn.cursor() as replace_cursor:
        replace_sql = f"replace into `reportPlatform{year}`.`Dwetness` (`date`, `siteId`, `name`, `wetnessMin`, `wetnessMedian`, `wetnessMax`) Values {value_string}"
        try:
            rd_cursor.execute(replace_sql)
            rd_conn.commit()
            logging.debug(f"----- Replace Succeed -----")
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}\n[{sId} replace ERROR]: {str(ex)}")

rd_cursor.close()
rd_conn.close()
logging.info(f"----- Connection Closed ----- took {round(time.time() - s, 2)}s")