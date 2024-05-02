import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import time


def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[MySQL Connection Error]: {str(ex)}")

def main():

    conn = connectDB('127.0.0.1')
    #prod_conn = connectDB('192.168.1.62')

    nowTime = datetime.now()
    date_to = (nowTime-timedelta(days=1)).strftime('%Y-%m-%d')
    date_from = nowTime.replace(day=1).strftime('%Y-%m-%d')
    month = nowTime.month
    year = nowTime.year

    logging.debug(f"----- Processing from {date_from} to {date_to} -----")

    cursor = conn.cursor()
    sqlCommand = f"SELECT siteId, name FROM mgmtETL.NameList where tableDesc='flow' and gatewayId>0 and protocol is not NULL order by siteId asc, convert(substring_index(name, '#', -1), unsigned integer)"
    cursor.execute(sqlCommand)
    
    value_string = ''
    for rows in cursor:
        sId = rows[0]
        name = rows[1]
        logging.debug(f"----- process {sId} {name} -----")
    
        waterConsumption = 'NULL'
        flag = True
        total = 'NULL'
        with conn.cursor() as data_cursor:
            sqlCommand = f"select waterConsumption, total from reportPlatform{year}.Dflow where date>='{date_from}' and date<='{date_to}' and siteId={sId} and name='{name}'"
            logging.debug(sqlCommand)

            data_cursor.execute(sqlCommand)

            if data_cursor.rowcount != 0:
                for data in data_cursor:

                    if flag:
                        if data[0] is not None and data[0] >= 0:
                            waterConsumption = data[0]
                            flag = False
                    else:
                        if data[0] is not None and data[0] >= 0:
                            waterConsumption += data[0]
                    
                    if data[1] is not None and data[1] >= 0:
                        total = data[1]
                
                if waterConsumption == 'NULL' and total == 'NULL':
                    continue             

                logging.info(f"{month}, '{date_to}', {sId}, '{name}', {waterConsumption}, {total}")
                value_string += f"({month}, '{date_to}', {sId}, '{name}', {waterConsumption}, {total}), "

    cursor.close()

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `reportPlatform{year}`.`Mflow` (`month`, `updateDate`, `siteId`, `name`, `waterConsumption`, `total`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

    conn.close()

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
