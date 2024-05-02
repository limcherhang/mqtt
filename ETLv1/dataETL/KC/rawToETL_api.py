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

def hextodec(value):
    logging.debug(value)
    if int(value[0], 16) > 7:
        return int(value, 16) - int('f' * len(value), 16)
    else:
        return int(value, 16)

def main():

    conn = connectDB('127.0.0.1')
    
    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=120)).replace(second=0)
    et = nowTime
    logging.info(f"---- Searching from {st} to {et} ----")
    value_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT gatewayId,deviceId,name FROM mgmtETL.sigfoxAPI"
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
                    data = data[1]
                    data = data[1:-1]
                    
                    header = hextodec(data[0:2])
                    if header == 1:
                        kWh = hextodec(data[4:12]) # activeEnergyKwh
                        pf = hextodec(data[12:16]) # Power Factor
                        w = hextodec(data[16:24]) # activePowerW
                        ch1Watt = ('NULL' if w is None else round(float(w)))
                        total = ('NULL' if kWh is None else round(float(kWh)*1000))
                        ch1powerfactor = ('NULL' if pf is None else (float(pf)/1000))
                        value_string += f"('{ts}','{gId}','{name}', {ch1Watt}, {ch1powerfactor}, {total}, null), "
                    #elif header == 4:
                        #kWh = hextodec(data[4:12]) # activeEnergyKwh
                        #total = ('NULL' if kWh is None else round(float(kWh)*1000))
                        #value_string += f"('{ts}','{gId}','{name}', null, null, null ,{total}), "
   
                    
                print(value_string)

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`power` (`ts`, `gatewayId`, `name`, `ch1Watt`, `ch1PowerFactor`, `totalPositiveWattHour`, `totalNegativeWattHour`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
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
