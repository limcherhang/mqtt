import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler

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

def main():

    conn = connectDB('127.0.0.1')
    prod_conn = connectDB('192.168.6.41')

    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=60)).replace(second=0)
    et = nowTime
    logging.info(f"---- Searching from {st} to {et} ----")

    dev_dict = {
        'Power#1': '40B268', 
        'Power#2': '40B268', 
        'Power#3': '48BEDD', 
        'Power#4': '40E797', 
        'Power#5': '40E0CD', 
        'Power#6': '40BE3E', 
        'Power#7': '4117AC'
    }

    value_string = ''
    for name, dId in dev_dict.items():
        
        sId = (2 if name == 'Power#2' else 1)

        with prod_conn.cursor() as data_cursor:
            sqlCommand = f"select APIts, activeEnergyKwh, activePowerW from rawData.sigfoxAPI where APIts>='{st}' and APIts<'{et}' and deviceId='{dId}' and slaveId={sId} order by APIts asc"
            logging.debug(sqlCommand)
            data_cursor.execute(sqlCommand)

            for data in data_cursor:
                ts = data[0]
                totalPositiveWattHour = ('NULL' if data[1] is None else round(float(data[1])*1000)) # kWH > WH
                ch1Watt = ('NULL' if data[2] is None else round(float(data[2])))

                logging.info(f"'{ts}', 248, '{name}', {ch1Watt}, {totalPositiveWattHour}")
                value_string += f"('{ts}', 248, '{name}', {ch1Watt}, {totalPositiveWattHour}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`power` (`ts`, `gatewayId`, `name`, `ch1Watt`, `totalPositiveWattHour`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replacement Succeed")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

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

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
