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
    prod_conn = connectDB('127.0.0.1')

    nowTime = datetime.now()
    date_to = nowTime.strftime('%Y-%m-%d')
    if nowTime.day == 1:
        date_from = (nowTime - timedelta(days=1)).replace(day=1).strftime('%Y-%m-%d')
    else:
        date_from = nowTime.replace(day=1).strftime('%Y-%m-%d')
    month = (nowTime - timedelta(days=1)).month
    year = (nowTime - timedelta(days=1)).year

    logging.info(f"----- Processing from {date_from} to {date_to} -----")

    cursor = prod_conn.cursor()
    sqlCommand = f"SELECT siteId, name FROM mgmtETL.NameList where tableDesc='power' and gatewayId>0 and protocol='Name' order by siteId asc, convert(substring_index(name, '#', -1), unsigned integer)"
    cursor.execute(sqlCommand)
    
    value_string = ''
    for rows in cursor:
        sId = rows[0]
        name = rows[1]
        logging.debug(f"----- process {sId} {name} -----")
    
        energyConsumption = 'NULL'
        total = 'NULL'
        
        with prod_conn.cursor() as data_cursor:
            sqlCommand = f"SELECT total FROM dataPlatform{year}.power_{month:02} where ts>='{date_from}' and siteId={sId} and name='{name}' order by ts asc limit 1"
            logging.debug(f"from: {sqlCommand}")
            data_cursor.execute(sqlCommand)

            data = data_cursor.fetchone()
            if data is not None:
                if data[0] is not None:
                    dataAtDateFrom = data[0]
                else:
                    dataAtDateFrom = 'NULL'
            else:
                dataAtDateFrom = 'NULL'

        with prod_conn.cursor() as data_cursor:
            sqlCommand = f"SELECT total FROM dataPlatform{year}.power_{month:02} where ts<'{date_to}' and siteId={sId} and name='{name}' order by ts desc limit 1"
            logging.debug(f"to: {sqlCommand}")
            data_cursor.execute(sqlCommand)

            data = data_cursor.fetchone()
            if data is not None:
                if data[0] is not None:
                    dataAtDateTo = data[0]
                else:
                    dataAtDateTo = 'NULL'
            else:
                dataAtDateTo = 'NULL'

        logging.debug(dataAtDateFrom)
        logging.debug(dataAtDateTo)

        if dataAtDateFrom != 'NULL' and dataAtDateTo != 'NULL':
            if dataAtDateFrom >= 0 and dataAtDateTo >= 0:
                energyConsumption = round(dataAtDateTo - dataAtDateFrom, 3)
                total = dataAtDateTo
            else:
                continue
        else:
            continue

        logging.info(f"{month}, '{(nowTime-timedelta(days=1)).strftime('%Y-%m-%d')}', {sId}, '{name}', {energyConsumption}, {total}")
        value_string += f"({month}, '{(nowTime-timedelta(days=1)).strftime('%Y-%m-%d')}', {sId}, '{name}', {energyConsumption}, {total}), "

    cursor.close()

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `reportPlatform{year}`.`Mpower` (`month`, `updateDate`, `siteId`, `name`, `energyConsumption`, `total`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

    conn.close()
    prod_conn.close()

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.INFO, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.critical(f"----- Program Closes ----- took: {round(time.time()-s, 3)}s")