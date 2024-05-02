import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler

def connectDB(host,port,username,password):
    try:
        conn = pymysql.connect(
            host = host, 
            port = port,
            user = username,
            passwd = password,
            #read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Error]: {str(ex)}")

def UMG96_handle(conn, prod_conn, st, et):
    logging.debug(f"hi UMG96_handle func.")

    value_string = ''
    with prod_conn.cursor() as data_cursor:
        sqlCommand = f"select APIts, rawdata1,rawdata4 from rawData.sindconAPI where APIts>='{st}' and APIts<'{et}' and SN='5234002' order by APIts asc"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            wh = round(float(data[1]) * 1000, 1)
            w = round(float(data[2]), 0)
                
                
            logging.info(f"'{ts}', 247, 'Power#1', {w}, {wh}")
            value_string += f"('{ts}', 247, 'Power#1', {w}, {wh}), "
    
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

def main():

    conn = connectDB('127.0.0.1',3306,'ecoprog','ECO4ever8118')
    prod_conn = connectDB('sg.evercomm.com',44106,'eco','ECO4ever')

    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=60)).replace(second=0)
    et = nowTime
    logging.info(f"---- Searching from {st} to {et} ----")

    dev_dict = {
        'Power#1': '5234002', 
        'Power#2': '2711172109', 
        'Power#3': '1711000226', 
        'Power#4': '2711172104', 
        'Power#5': '175568', 
        'Power#6': '3511140622', 
        'Power#7': '1751678', 
        'Power#8': '1887665', 
        'Power#9': '181818180', 
        'Power#10': '91818188', 
        'Power#11': '9769876'
    }

    value_string = ''
    for name, sn in dev_dict.items():

        logging.info(f"----- Prcoessing GatewayId:247 {name} {sn} -----")
        if sn == '5234002':
            UMG96_handle(conn, prod_conn, st, et)
            continue

        with prod_conn.cursor() as data_cursor:
            sqlCommand = f"select APIts, rawdata1, rawdata2 from rawData.sindconAPI where APIts>='{st}' and APIts<'{et}' and SN='{sn}' order by APIts asc"
            logging.debug(sqlCommand)

            data_cursor.execute(sqlCommand)

            for data in data_cursor:
                logging.debug(data)
                ts = data[0]
                wh = round(float(data[1]) * 1000, 1)
                w = round(float(data[2]) * 1000, 1)
                
                logging.info(f"'{ts}', 247, '{name}', {w}, {wh}")
                value_string += f"('{ts}', 247, '{name}', {w}, {wh}), "
    
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
        level = logging.DEBUG, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
