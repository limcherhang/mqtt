import requests
import json
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
from pathlib import Path
import sys , os
rootPath = str(Path.cwd())+'/../'
sys.path.append(rootPath)
from utils import myLog
from connection.mysql_connection import MySQLConn
import configparser

def main(conn):
    value_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT a.gatewayId,a.uId,b.name FROM mgmtETL.KiwiAPI a,mgmtETL.DataETL b where a.siteId=b.siteId and a.uId = b.deviceId "
        cursor.execute(sql)
        for row in cursor:
            gId = row[0]
            uId = row[1]
            name = row[2]
            logging.info(f"----- Processing GatewaId:{gId} {uId} {name} -----")
            with conn.cursor() as data_cursor:
                sqlCommand = f"select APIts,rawdata from rawData.kiwiAPI where APIts>='{st}' and APIts<'{et}' and uId='{uId}' and gatewayId = {gId} order by APIts asc"
                logging.debug(sqlCommand)
                data_cursor.execute(sqlCommand)
                for data in data_cursor:
                    ts = data[0]
                    rawdata = json.loads(data[1])
                    temp = ('NULL' if rawdata['v'] is None else rawdata['v'])

                    value_string += f"('{ts}', {gId}, '{name}', {temp}), "

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`temp` (`ts`, `gatewayId`, `name`, `temp1`) Values {value_string}"
            try:
                logging.debug(replace_sql)
                cursor.execute(replace_sql)
                conn.commit()
            except Exception as ex:
                logging.debug(f"SQL: {replace_sql}")
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
    logging.info(f"---- Searching from {st} to {et} ----")
    main(conn)

