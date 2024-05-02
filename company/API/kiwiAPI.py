import requests
import json

import logging
from datetime import datetime, timedelta
from pathlib import Path
import sys , os
rootPath = str(Path.cwd())+'/../../'
sys.path.append(rootPath)
from utils import myLog
from connection.mysql_connection import MySQLConn
import configparser

def main(conn):
    value_string = ''
    date = datetime.now().strftime('%Y-%m-%d')
    with conn.cursor() as cursor:
        sql = "SELECT a.gatewayId,a.uId,b.username, b.password FROM mgmtETL.KiwiAPI a,mgmtETL.APIList b where a.keyId=b.keyId "
        cursor.execute(sql)
        for row in cursor:
            gId = row[0]
            uId = row[1]
            user = row[2]
            pwd = row[3]
        
            data_url = f"https://custname.kiwi-alert.com/api/sensor/get-values?UID={uId}/Temp&fromDate={date}"
            data_resp = requests.get(data_url, auth=(user, pwd), verify=False)
            logging.debug(data_resp.url)

            if data_resp.status_code == requests.codes.ok:
                data_list = json.loads(data_resp.text)
                if len(data_list) > 0:
                    for data in data_list:
                        APIts = data['DateTimeSGT'].replace('T', ' ').replace('Z', ' ')
                        rawdata = json.dumps(data)
                        
                        value_string += f"('{nowTime}','{APIts}', {gId}, '{uId}', '{rawdata}'), "
                else:
                    logging.warning(f"GatewayId:{gId} {uId} doesn't have data now")

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `rawData`.`kiwiAPI` (`DBts`,`APIts`, `gatewayId`, `uId`, `rawData`) Values {value_string}"
            try:
                logging.debug(replace_sql)
                cursor.execute(replace_sql)
            except Exception as ex:
                logging.error(f"[Replace ERROR]: {str(ex)}")

if __name__ == '__main__':
    file = __file__
    basename = os.path.basename(file)
    filename = os.path.splitext(basename)[0]

    config = configparser.ConfigParser()
    config.read(rootPath+'/config.ini')
    conn = MySQLConn(config['mysql_azure'])
    logger = myLog.get_logger(os.getcwd(), f"{filename}.log",config['mysql_azure'])
    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=63)).replace(second=0, microsecond=0)
    et = nowTime
    main(conn)