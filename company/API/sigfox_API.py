import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import requests
import configparser
import time
from datetime import datetime, timedelta

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
    logging.debug(f"hi main func")

    global nowTime

    try:
        config = configparser.ConfigParser()
        config.read('api_config.ini')

        username = config['sigfox']['username']
        pwd = config['sigfox']['password']
    except Exception as ex:
        logging.error(f"[Config Error]: {str(ex)}")

    device_list = ['40B268', '48BEDD', '40E797', '40E0CD', '40BE3E', '4117AC']
    date_from = datetime.now() - timedelta(hours=3)
    logging.info(f"----- Get data from {date_from} to now in limit 4 ----")

    params = {
        "limit": 4
    }
    logging.debug(params)

    value_string = ''
    for index, dId in enumerate(device_list):
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
                data = item['data']
                if len(data) != 24:
                    continue
                header = hextodec(data[0:2])
                slave_Id = hextodec(data[2:4])
                kWh = hextodec(data[4:12]) # activeEnergyKwh
                pf = hextodec(data[12:16]) # Power Factor
                w = hextodec(data[16:24]) # activePowerW

                logging.info(f"'{nowTime}', '{ts}', 248, '{dId}', '{slave_Id}', {kWh}, {pf}, {w}")
                value_string += f"('{nowTime}', '{ts}', 248, '{dId}', '{slave_Id}', {kWh}, {pf}, {w}), "
        else:
            logging.error(f"[API ERROR]: Status Code ({resp.status_code}) is not okay(200)!")

    if value_string != '':
        conn = connectDB('127.0.0.1')
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `rawData`.`sigfoxAPI` (`DBts`, `APIts`, `gatewayId`, `deviceId`, `slaveId`, `activeEnergyKwh`, `powerFactor`, `activePowerW`) Values {value_string}"
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info("Replace SQL Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")

        conn.close()

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
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