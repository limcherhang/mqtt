import json
from datetime import datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler
from pathlib import Path
import sys , os
rootPath = str(Path.cwd())+'/../'
sys.path.append(rootPath)
from utils import myLog
from connection.mysql_connection import MySQLConn
import configparser

def hextodec(value):
    logging.debug(value)
    if int(value[0], 16) > 7:
        return int(value, 16) - int('f' * len(value), 16)
    else:
        return int(value, 16)

def main(conn):
    value_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT a.gatewayId,a.deviceId,b.name FROM mgmtETL.SigfoxAPI a,mgmtETL.DataETL b where a.siteId=b.siteId and a.deviceId = b.deviceId  and name like 'Power#%'"
        cursor.execute(sql)
        for row in cursor:
            gId = row[0]
            dId = row[1]
            name = row[2]
            Ntotal = 'null'
            with conn.cursor() as data_cursor:
                sqlCommand = f"select APIts, rawdata from rawData.sigfoxAPI where APIts>='{st}' and APIts<'{et}' and deviceId='{dId}' and gatewayId='{gId}' order by APIts asc"
                logging.debug(sqlCommand)
                data_cursor.execute(sqlCommand)

                for data in data_cursor:
                    ts = data[0]
                    rawdata = json.loads(data[1])
                    data = rawdata['data']
                    header = hextodec(data[0:2])
                    
                    if header == 1:
                        sId = hextodec(data[2:4])
                        kWh = hextodec(data[4:12]) # activeEnergyKwh
                        pf = hextodec(data[12:16]) # Power Factor
                        w = hextodec(data[16:24]) # activePowerW
                    elif header ==4:
                        NkWh = hextodec(data[4:12]) # activeEnergyKwh
                        Ntotal = ('NULL' if NkWh is None else round(float(NkWh)*1000))
                        
                    if gId == 248 and sId == 2 and dId == '40B268':
                        name = 'Power#2'
                    elif gId == 248 and sId == 1 and dId == '40B268':
                        name = 'Power#1'

                    totalPositiveWattHour = ('NULL' if kWh is None else round(float(kWh)*1000)) # kWH > WH
                    ch1Watt = ('NULL' if w is None else round(float(w)))

                    logging.info(f"'{ts}', {gId}, '{name}', {ch1Watt}, {totalPositiveWattHour}")
                    value_string += f"('{ts}',  {gId}, '{name}', {ch1Watt}, {totalPositiveWattHour},{Ntotal}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`power` (`ts`, `gatewayId`, `name`, `ch1Watt`, `total`,`totalNegative`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                
                logging.info(f"Replacement Succeed")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

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
