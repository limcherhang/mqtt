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

def getTotal(conn,st,name):
    stime = datetime.date(st)
    etime = stime+timedelta(days=1)
    with conn.cursor() as cursor:
        
        sqlCommand=f"select total from dataPlatform.power where ts >= '{stime}' and ts < '{etime}' and name = '{name}'  and siteId = 87 order by ts asc limit 1"
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
    names = ['Power#1','Power#14']
    with conn.cursor() as data_cursor:
        sqlCommand = f"select ts,ch1Watt,totalPositiveWattHour,totalNegativeWattHour from dataETL.power where ts>='{st}' and ts<'{et}' and  totalNegativeWattHour is not null and name = 'Power#1' and gatewayId = 261 order by ts asc"
        logging.info(sqlCommand)
        data_cursor.execute(sqlCommand)
        if data_cursor.rowcount == 0:
            logging.info(f'Power#1 has no data')
        else:
           
            for data in data_cursor:
                ts = data[0]
                ch1watt = (0 if data[1] is None else(float(data[1])))
                posi = nega = (0 if data[2] is None else (float(data[2])))/1000
                nega = (0 if data[3] is None else (float(data[3])))/1000
                for name in names:
                    total = getTotal(conn,st,name)
                    if name == 'Power#1':
                        if total == 0:
                            energy = 0
                            total = posi
                        else :
                            energy = posi-total
                        if ch1watt < 0 :
                            watt = 0
                        else:
                            watt = ch1watt

                        power = watt/1000
                        value_string += f"('{ts}',87,'{name.lower()}',{watt}, {abs(power)}, {energy}, {posi}), "
                    elif name == 'Power#14':
                        if total == 0:
                            energy = 0
                            total = nega
                        else :
                            energy = nega-total
                        if ch1watt > 0:
                            watt = 0
                        else:
                            watt = ch1watt

                        power = watt/1000    
                        value_string += f"('{ts}',87,'{name.lower()}',{abs(watt)}, {abs(power)}, {energy}, {nega}), "

               

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
