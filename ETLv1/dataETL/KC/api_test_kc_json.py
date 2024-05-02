import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import requests
import configparser
import time
from datetime import datetime, timedelta
import json
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

def main():
    logging.debug(f"hi main func")

    global nowTime
    conn = connectDB('127.0.0.1')
    try:
        config = configparser.ConfigParser()
        config.read('api_config.ini')
        username = config['sigfox']['username']
        pwd = config['sigfox']['password']
    except Exception as ex:
        logging.error(f"[Config Error]: {str(ex)}")

    date_from = datetime.now() - timedelta(hours=3)
    logging.info(f"----- Get data from {date_from} to now in limit 4 ----")

    params = {
        "limit": 4
    }
    logging.debug(params)
    value_string = ''
    rawdata_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT gatewayId,deviceId FROM mgmtETL.sigfoxAPI "
        cursor.execute(sql)
        for row in cursor:
            gId = row[0]
            dId = row[1]
            
            logging.info(f"----- Processing {dId} -----")
    
            url = f"https://api.sigfox.com/v2/devices/{dId}/messages"
            resp = requests.get(url, auth=(username, pwd), params=params)
            
            if resp.status_code == requests.codes.ok:
                
                for item in resp.json()['data']:
                    logging.debug(item)
                    if dId != item['device']['id']:
                        continue
                    time_str = item['time']
                    ts = datetime.fromtimestamp(time_str / 1000)

                    rawdata = json.dumps(item)
                    rawdata_string += f"('{nowTime}', '{ts}', {gId}, '{dId}', '{rawdata}'), "
            else:
                logging.error(f"[API ERROR]: Status Code ({resp.status_code}) is not okay(200)!")

    if rawdata_string != '':
        rawdata_string = rawdata_string[:-2]
        with conn.cursor() as cursor:
            replace_sql_2 = f"replace into `rawData`.`sigfoxAPI` (`DBts`, `APIts`, `gatewayId`, `deviceId`, `rawdata`) Values {rawdata_string}"
            try:
                cursor.execute(replace_sql_2)
                conn.commit()
                logging.info("Replace SQL Succeed!")
                logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql_2}")
                logging.error(f"[Replace ERROR]: {str(ex)}")
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

    logging.getLogger('urllib3').setLevel(logging.WARNING)

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")
    
    main()

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
