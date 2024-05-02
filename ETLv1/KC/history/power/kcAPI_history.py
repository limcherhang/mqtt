#python3 kcAPI_history.py 2023-07-01 12( 從 7/1 12點以前的 100筆，如果未輸入or輸入0 則是 從 7/2 00:00:00 開始往回抓)
import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import requests
import configparser
import time
from datetime import datetime, timedelta
import json
import os
import re
import sys
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

    if hr == 0:
        time_end = nowTime + timedelta(days=1)
    else:
        time_end = nowTime
    
    times = int(datetime.timestamp(time_end))*1000
    print(times)
    logging.info(f"----- Get data from {nowTime} in limit 100 ----")
    params = {
        "before":times,
        "limit": 100
    }
    logging.debug(params)
    
    rawdata_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT gatewayId,deviceId FROM mgmtETL.SigfoxAPI "
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
                    rawdata_string += f"('{datetime.now()}', '{ts}', {gId}, '{dId}', '{rawdata}'), "
            else:
                logging.error(f"[API ERROR]: Status Code ({resp.status_code}) is not okay(200)!")
            
    if rawdata_string != '':
        rawdata_string = rawdata_string[:-2]
        with conn.cursor() as cursor:
            replace_sql_2 = f"replace into `rawData`.`sigfoxAPI` (`DBts`, `APIts`, `gatewayId`, `deviceId`, `rawdata`) Values {rawdata_string}"
            try:
                cursor.execute(replace_sql_2)
                conn.commit()
                print("Replace SQL Succeed!")
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
    try:
        date = sys.argv[1]
        hr = (int(sys.argv[2]) if len(sys.argv) > 2 and int(sys.argv[2])>=0 and int(sys.argv[2])<=12  else 0)
        pattern = r'^\d{4}-\d{2}-\d{2}$'
        if re.match(pattern, date):
            data =  date.split('-')
            year,month,day = int(data[0]),int(data[1]),int(data[2])
            nowTime = datetime.now().replace(year,month,day,hour=hr,minute=0,second=0,microsecond=0)
            logging.info(f"---------- now: {nowTime} ----------")
            main()
        else:
            print("輸入錯誤，請重新輸入，格式:YYYY-MM-DD。")
    except ValueError as Vex:
        print (Vex)
    except IndexError as Iex:
        print(f"請加上日期，ex:python3 {filename}.py YYYY-MM-DD。")
    
    

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")