import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os

def connectDB(host,port,username,password):
    try:
        conn = pymysql.connect(
            host = host, 
            port = port,
            # user = username,
            # passwd = password 
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Error]: {str(ex)}")

def hextodec(value):
    logging.debug(value)
    if int(value[0], 16) > 7:
        return int(value, 16) - int('f' * len(value), 16)
    else:
        return int(value, 16)

def main(conn):
    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=20)).replace(second=0)
    et = nowTime
    logging.info(f"---- Searching from {st} to {et} ----")
    value_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT gatewayId,deviceId,name FROM mgmtETL.SigfoxAPI where name like 'ThreeInOne#%'"
        cursor.execute(sql)
        for row in cursor:
            gId = row[0]
            dId = row[1]
            name = row[2]
            with conn.cursor() as data_cursor:
                sqlCommand = f"select APIts,rawdata-> '$.data' as data from rawData.sigfoxAPI where APIts>='{st}' and APIts<'{et}' and rawdata->'$.device.id' = '{dId}' order by APIts asc"
                logging.info(sqlCommand)
                data_cursor.execute(sqlCommand)
                if data_cursor.rowcount == 0:
                    logging.info(f'{row} has no data')
                for data in data_cursor:
                    ts = data[0]
                    rawdata = data[1]
                    rawdata = rawdata[1:-1]
                    
                    if len(rawdata) == 12:
                        temp = hextodec(rawdata[2:6]) 
                        h = hextodec(rawdata[6:8]) 
                        co2 = hextodec(rawdata[8:12]) 
                        temp = ('NULL' if temp is None else (float(temp)/10))
                        h = ('NULL' if h is None else float(h))
                        co2 = ('NULL' if co2 is None else (float(co2)))
                        value_string += f"('{ts}','{gId}','{name}', {temp}, {h}, {co2}), "

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`threeInOne` (ts, gatewayId, name, temp, humidity, co2) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replacement Succeed")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")
    conn.close()
    
if __name__ == '__main__':
    file = __file__
    basename = os.path.basename(file)
    filename = os .path.splitext(basename)[0]
    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
        level = logging.INFO, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")
    conn = connectDB('127.0.0.1',3306,'username','password')
    main(conn)
    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
