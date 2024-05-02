import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os
def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Error]: {str(ex)}")

def getTotal(conn,st):
    stime = datetime.date(st)
    etime = stime+timedelta(days=1)
    with conn.cursor() as cursor:
        
        sqlCommand=f"select total from dataPlatform.power where ts >= '{stime}' and ts < '{etime}' and name = 'power#14'  and siteId = 87 order by ts asc limit 1"
        cursor.execute(sqlCommand)
        data=cursor.fetchone()
        if data is None:
            total = 0
        else:
            total = data[0]
    return total


def main():

    conn = connectDB('127.0.0.1')
    
    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=20)).replace(second=0)
    et = nowTime
    logging.info(f"---- Searching from {st} to {et} ----")
    value_string = ''
    
    with conn.cursor() as data_cursor:
        sqlCommand = f"select ts,totalNegativeWattHour from dataETL.power where ts>='{st}' and ts<'{et}' and  totalNegativeWattHour is not null and name = 'power#1' and gatewayId = 261 order by ts asc"
        logging.info(sqlCommand)
        data_cursor.execute(sqlCommand)
        if data_cursor.rowcount == 0:
            logging.info(f'Power#1 has no data')
        else:
            total = getTotal(conn,st)
            for data in data_cursor:
                ts = data[0]
                nega = (0 if data[1] is None else (float(data[1])))/1000
                if total == 0:
                    energy = 0
                    total = nega
                else :
                    energy = nega-total

                with conn.cursor() as cursor:
                    sql = f"SELECT energyConsumed FROM dataPlatform.power where siteId = 87 and name = 'power#14' order by ts desc limit 1;"
                    cursor.execute(sql)
                    for en in cursor:
                        energy_last = en[0]
                        w = (energy - energy_last)*1000
                        power = w/1000



                value_string += f"('{ts}',87,'power#14',{w},{power}, {energy}, {nega}), "

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataPlatform`.`power` (`ts`, `siteId`, `name`, `ch1Watt`, `powerConsumed`,`energyConsumed`, `total`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                print(replace_sql)
                conn.commit()
                logging.info(f"Replacement Succeed")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

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

    main()

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
