import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler

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

def getTotal(conn, sId, name):

    with conn.cursor() as cursor:
        sqlCommand = f"select totalLatest from mgmtETL.GasLog where siteId={sId} and name='{name}'"
        cursor.execute(sqlCommand)
        data = cursor.fetchone()
    
    if data is not None:
        return data[0]
    else:
        return None

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'/home/ecoprog/log/{__file__}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
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
sqlCommand = f"SELECT siteId, name FROM mgmtETL.NameList where tableDesc='gas' #and gatewayId>0 and protocol is Not NULL"
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    sId = rows[0]
    name = rows[1]
    logging.info(f"----- Processing {sId} {name} -----")

    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select gasInm3, gasConsumedInm3, gasInmmBTU, gasConsumedInmmBTU from dataPlatform{st.year}.gas_{st.month:02} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}' order by ts desc limit 1"
        else:
            sqlCommand = f"select gasInm3, gasConsumedInm3, gasInmmBTU, gasConsumedInmmBTU from dataPlatform.gas where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}' order by ts desc limit 1"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"SiteId: {sId} has no data on {date}")
            continue
        else:
            data = data_cursor.fetchone()
            if data is not None:
                gas_m3 = data[0]
                gasConsumption_m3 = data[1]
                gas_mmBTU = data[2]
                gasConsumption_mmBTU = data[3]
            else:
                continue
            
            gasTotal = getTotal(my_conn, sId, name)
            if gasTotal is not None:
                total_m3 = gas_m3 - gasTotal
                total_mmBTU = gas_mmBTU - gasTotal
            else:
                total_m3 = gas_m3
                total_mmBTU = gas_mmBTU
            
            value_string += f"('{date}', {sId}, '{name}', {round(gasConsumption_m3, 3)}, {round(total_m3, 3)}, {round(gasConsumption_mmBTU, 3)}, {round(total_mmBTU, 3)}), "

if value_string != '':
    value_string = value_string[:-2]
    replace_sql = f"replace into `reportPlatform{st.year}`.`Dgas` (`date`, `siteId`, `name`, `gasConsumptionInm3`, `totalInm3`, `gasConsumptionInmmBTU`, `totalInmmBTU`) Values {value_string}"
    with my_conn.cursor() as my_cursor:
        try:
            my_cursor.execute(replace_sql)
            my_conn.commit()
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

my_cursor.close()
my_conn.close()
logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")
