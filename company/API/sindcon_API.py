import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import requests
import configparser
import threading
from datetime import datetime
import time
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

def dataProcess(eui, sn, ts_list, data_list):
    logging.debug(f"hi dataProcess func.")

    value_string = ''
    for ts in ts_list:
        data_string = f"'{ts}', 247, '{sn}', '{eui}'"
        for data in data_list:
            if data[0] != eui or data[1] != sn:
                continue
            elif data[2] != ts:
                continue
            value = float(data[4])

            data_string += f', {value}'
        logging.info(data_string)
        
        value_string += f"('{datetime.now().replace(microsecond=0)}', {data_string}), "

    return value_string

def getUMG96Data(token):
    logging.debug("hi getUMG96 func.")

    global span
    headers = {"Grpc-Metadata-Authorization": token}
    url = f"https://sindconiot.com/api/dc/history/meter"

    logging.info(f"----- 08000000300040cd 5234002 -----")

    params = {
       "devEUI": "08000000300040cd", 
       "sn": "5234002",
       "unit": "hour", 
       "span": span
    }

    value_string = ''
    resp = requests.get(url, headers=headers, params=params)
    if resp.status_code == requests.codes.ok:
        ts_list = []
        data_list = []

        for item in resp.json()['items']:
            data_tuple = ()
            column = item['title']
            logging.info(column)
            for data in item['data']:
                if data['time'] != data['acquisition']:
                    logging.error(f"[API data ERROR]: Difference between time{data['time']} and acquistion{data['acquisition']}")
                    continue
                else:
                    if data['time'] not in ts_list:
                        ts_list.append(data['time'])
                
                data_tuple = ('08000000300040cd', '5234002', data['time'], column, data['value'])
                data_list.append(data_tuple)
        
        value_string += dataProcess('08000000300040cd', '5234002', ts_list, data_list)
    else:
        logging.error(f"[API ERROR at getToken func.]: Status Code ({resp.status_code}) is not okay(200)!")

    if value_string != '':
        conn = connectDB('127.0.0.1')
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `rawData`.`sindconAPI` (`DBts`, `APIts`, `gatewayId`, `SN`, `EUI`, `rawdata1`, `rawdata2`, `rawdata3`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info("Replace SQL Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")
        
        conn.close()

def getToken():
    logging.debug(f"hi getToken func.")

    config = configparser.ConfigParser()
    config.read('api_config.ini')

    username = config['sindcon']['username']
    pwd  =config['sindcon']['password']

    data = {
        "username": username, 
        "password": pwd
    }
    
    url = f"https://sindconiot.com/api/internal/login"
    resp = requests.post(url, json=data)
    if resp.status_code == requests.codes.ok:
        token = resp.json()['jwt']
        return token
    else:
        logging.error(f"[API ERROR at getToken func.]: Status Code ({resp.status_code}) is not okay(200)!")

    return None

def getDevList(token):
    logging.debug(f"hi getDevList func.")

    headers = {"Grpc-Metadata-Authorization": token}

    url = f"https://sindconiot.com/api/app/devlist"
    resp = requests.get(url, headers=headers)
    if resp.status_code == requests.codes.ok:
        dict = {}
        data_list = resp.json()['result']
        for data in data_list:
            devEUI = data['devEUI']
            sn = data['sn']
        
            if devEUI == '' or sn == '': 
                continue
            elif sn == '5234002':
                tUMG96 = threading.Thread(target=getUMG96Data, args=(token, ))
                tUMG96.start()
                tUMG96.join()
                continue
            elif sn == 'TSG Solar':
                continue
            dict[devEUI] = sn
        
        return dict
    else:
        logging.error(f"[API ERROR at getToken func.]: Status Code ({resp.status_code}) is not okay(200)!")

    return None

def getHistoricalData(dict, token):
    logging.debug(f"hi getHistoricalData func.")

    global span
    headers = {"Grpc-Metadata-Authorization": token}
    url = f"https://sindconiot.com/api/dc/history/meter"

    value_string = ''
    for k, v in dict.items():
        logging.info(f"----- {k} {v} -----")

        params = {
           "devEUI": k, 
           "sn": v,
           "unit": "hour", 
           "span": span
        }

        resp = requests.get(url, headers=headers, params=params)
        if resp.status_code == requests.codes.ok:

            ts_list = []
            data_list = []
            for item in resp.json()['items']:
                data_tuple = ()
                column = item['title']
                logging.info(column)
                for data in item['data']:
                    if data['time'] != data['acquisition']:
                        logging.error(f"[API data ERROR]: Difference between time{data['time']} and acquistion{data['acquisition']}")
                        continue
                    else:
                        if data['time'] not in ts_list:
                            ts_list.append(data['time'])
                    
                    data_tuple = (k, v, data['time'], column, data['value'])
                    data_list.append(data_tuple)
            
            value_string += dataProcess(k, v, ts_list, data_list)
        else:
            logging.error(f"[API ERROR at getToken func.]: Status Code ({resp.status_code}) is not okay(200)!")

    return value_string

def main():
    logging.debug(f"hi main func.")
    
    token = getToken()
    if token is None:
        logging.error("token is empty!")
        return
    logging.debug(f"token: {token}")

    dev_dict = getDevList(token)
    if dev_dict is None:
        logging.error("dev_list is empty!")
        return
    logging.debug(dev_dict)
    
    value_string = getHistoricalData(dev_dict, token)

    if value_string != '':
        conn = connectDB('127.0.0.1')
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `rawData`.`sindconAPI` (`DBts`, `APIts`, `gatewayId`, `SN`, `EUI`, `rawdata1`, `rawdata2`) Values {value_string}"
            logging.debug(replace_sql)
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
        level = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )
    
    logging.getLogger('urllib3').setLevel(logging.WARNING)

    if len(sys.argv) == 2:
        try:
            span = int(sys.argv[1])
        except Exception as ex:
            sys.exit(f"[Parameter ERROR]: data type is not 'int' ({str(ex)})")
    else:
        # python3 sindconiot_API.py {0/1/2 ... /N (unit hour)} &
        sys.exit(f"[Parameter ERROR]: parameters are not matched!")

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
