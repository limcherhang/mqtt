import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import time
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
st = (nowTime-timedelta(minutes=4)).replace(second=0)
et = (nowTime-timedelta(minutes=1)).replace(second=0)
logging.debug(f"----- Processing from {st} to {et} -----")


if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1 :
    history_flag = True
else:
    history_flag = False


my_conn = connectDB('127.0.0.1')
name_list = ['temp#130', 'temp#131']
power_list = ['power#1', 'power#2', 'power#3', 'power#4', 'power#5', 'power#6', 'power#7']
supplyTemp_list = ['temp#1', 'temp#5', 'temp#9', 'temp#13', 'temp#17', 'temp#21', 'temp#25']
returnTemp_list = ['temp#2', 'temp#6', 'temp#10', 'temp#14', 'temp#18', 'temp#22', 'temp#26']


value_string = ''
while st <= et:
    ts = st
    st += timedelta(minutes=1)
    logging.debug(ts)

    for name in name_list:
        logging.debug(f"----- Processing {name} -----")
        if name == 'temp#130':
            temp_list = supplyTemp_list.copy()
        elif name == 'temp#131':
            temp_list = returnTemp_list.copy()
        
        #logging.debug(temp_list)
        temp_string = ''
        index_list = []
        for index, power in enumerate(power_list):
        
            with my_conn.cursor() as my_cursor:
                if history_flag:
                    sqlCommand = f"select ts, name, powerConsumed from dataPlatform{ts.year}.power_{ts.month:02} where ts='{ts}' and siteId=55 and name='{power}'"
                else:
                    sqlCommand = f"select ts, name, powerConsumed from dataPlatform.power where ts='{ts}' and siteId=55 and name='{power}'"
                
                my_cursor.execute(sqlCommand)
                
                if my_cursor.rowcount == 0:
                    logging.debug(f"{power} has no data at {ts}")
                    continue
                for data in my_cursor:
                    logging.debug(data)

                    ts = data[0]
                    powerConsumed = data[2]

                    if powerConsumed >= 10:
                        index_list.append(index)
        
        for index, temp in enumerate(temp_list):
            if index not in index_list: continue
            temp_string += f"'{temp_list[index]}', "
        
        if temp_string != '':
            with my_conn.cursor() as my_cursor:
                if history_flag:
                    sqlCommand = f"select round(AVG(temp), 2) from dataPlatform{ts.year}.temp_{ts.month:02} where ts='{ts}' and siteId=55 and name in ({temp_string[:-2]})"
                else:
                    sqlCommand = f"select round(AVG(temp), 2) from dataPlatform.temp where ts='{ts}' and siteId=55 and name in ({temp_string[:-2]})"
                
                logging.debug(sqlCommand)
                my_cursor.execute(sqlCommand)
                data = my_cursor.fetchone()
                
                if data[0] is not None:
                    logging.info(f"'{ts}', 55, '{name}', {data[0]}")
                    value_string += f"('{ts}', 55, '{name}', {data[0]}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataPlatform`.`temp` (`ts`,`siteId`,`name`,`temp`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            my_conn.commit()
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")
        
my_conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
