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
date = st.strftime('%Y-%m-%d')
logging.info(f"---------- Processing Date: {date} ----------")
logging.debug(f"---------- fronm {st} to {et} ----------")

if (datetime.now().replace(hour=0, minute=0, second=0, microsecond=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')
my_cursor = my_conn.cursor()
sqlCommand = f"select siteId, name from mgmtETL.NameList where tableDesc='quality' and gatewayId>0 and protocol is not NULL"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    logging.debug(rows)
    sId = rows[0]
    name = rows[1]
    logging.info(f"----- Processing {sId} {name} -----")
    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select pH, ORP, TDS, EC from dataPlatform{st.year}.quality_{st.month:02} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select pH, ORP, TDS, EC from dataPlatform.quality where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"SiteId: {sId} has no data on {date}")
            continue
        else:
            ph_list = []
            orp_list = []
            tds_list = []
            ec_list = []
            phMin, phMedian, phMax, orpMin, orpMedian, orpMax, tdsMin, tdsMedian, tdsMax, ecMin, ecMedian, ecMax = 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL', 'NULL'
            for data in data_cursor:
                if data[0] is not None:
                    ph_list.append(data[0])
                if data[1] is not None:
                    orp_list.append(data[1])
                if data[2] is not None:
                    tds_list.append(data[2])
                if data[3] is not None:
                    ec_list.append(data[3])
            
            if len(ph_list) != 0:
                phMin = round(np.percentile(np.array(ph_list), 0), 2)
                phMedian = round(np.percentile(np.array(ph_list), 50), 2)
                phMax = round(np.percentile(np.array(ph_list), 100), 2)
            if len(orp_list) != 0:
                orpMin = round(np.percentile(np.array(orp_list), 0), 2)
                orpMedian = round(np.percentile(np.array(orp_list), 50), 2)
                orpMax = round(np.percentile(np.array(orp_list), 100), 2)
            if len(tds_list) != 0:
                tdsMin = round(np.percentile(np.array(tds_list), 0), 2)
                tdsMedian = round(np.percentile(np.array(tds_list), 50), 2)
                tdsMax = round(np.percentile(np.array(tds_list), 100), 2)
            if len(ec_list) != 0:
                ecMin = round(np.percentile(np.array(ec_list), 0), 2)
                ecMedian = round(np.percentile(np.array(ec_list), 50), 2)
                ecMax = round(np.percentile(np.array(ec_list), 100), 2)

            value_string += f"('{date}', {sId}, '{name}', {phMin}, {phMedian}, {phMax}, {orpMin}, {orpMedian}, {orpMax}, {tdsMin}, {tdsMedian}, {tdsMax}, {ecMin}, {ecMedian}, {ecMax}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cusor:
        replace_sql = f"replace into `reportPlatform{st.year}`.`Dquality` (`date`, `siteId`, `name`, `pHMin`, `pHMedian`, `pHMax`, `ORPMin`, `ORPMedian`, `ORPMax`, `TDSMin`, `TDSMedian`, `TDSMax`, `ECMin`, `ECMedian`, `ECMax`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace Error]: {str(ex)}")

my_conn.commit()
my_cursor.close()
my_conn.close()
logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")