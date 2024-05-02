import pymysql
import time
import struct
import logging
from logging.handlers import TimedRotatingFileHandler
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
        logging.error(f"[Connection ERROR]: {str(ex)}")

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
    level = logging.ERROR, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- Now: {nowTime} ---------- Program Start!")

st = (nowTime-timedelta(minutes=2)).replace(second=0)
et = nowTime
#st = datetime(2022, 3, 4)
#et = nowTime
logging.info(f"---------- Processing from {st} to {et} ----------")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

ieees = ['00124b0019309e9b', '00124b0019309e96', '00124b00192f25b9', '00124b0019309dc8', '00124b00192f2589', '00124b00192f25b9', '00124b0019309dc8']#有兩個重複 #00124b0019309bf5 #00124b00192f25f5

my_conn = connectDB('127.0.0.1')

my_cursor = my_conn.cursor()
sqlCommand = f"SELECT name, ieee, gatewayId FROM mgmtETL.Device where name like 'AirQuality#%' and gatewayId>0" 
my_cursor.execute(sqlCommand)

value_string = ''
for rows in my_cursor:
    name = rows[0]
    ieee = rows[1]
    gId = rows[2]
    logging.info(f"----- Processing {gId} {ieee} -----")
    
    data_list = []
    op_list = []

    if ieee not in ieees: continue

    with my_conn.cursor() as data_cursor:
        if history_flag:
            sqlCommand = f"select receivedSync, responseData from iotdata{st.year}.zigbeeRawModbus_{st.month:02} where gatewayId={gId} and ieee='{ieee}' and modbusCmd='09030000000c4487' and ts>='{st}' and ts<'{et}'"
        else:
            sqlCommand = f"select receivedSync, responseData from iotmgmt.zigbeeRawModbus where gatewayId={gId} and ieee='{ieee}' and modbusCmd='09030000000c4487' and ts>='{st}' and ts<'{et}'"
        
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        for data in data_cursor:
            t = ()
            #logging.debug(data)
            if data[0] is None: 
                logging.warning(f"SQL: {sqlCommand}") 
                logging.warning(f"GatewayId: {gId} {ieee} has NULL receivedSync in the minute")
                continue
            ts = data[0]
            if data[0].replace(second=0) not in op_list: 
                op_list.append(data[0].replace(second=0))
            if len(data[1]) != 58: 
                continue
            rawData = data[1][6:-4]
            ion = int(rawData[0:4], 16)
            pm2dot5 = int(rawData[4:8], 16)
            pm10 = int(rawData[8:12], 16)
            ch2o = int(rawData[12:16], 16)
            temp = int(rawData[16:20], 16)
            humidity = int(rawData[20:24], 16)
            co2 = int(rawData[24:28], 16)
            voc = int(rawData[28:32], 16)
            #eco = int(rawData[32:36], 16)
            #r = int(rawData[36:44], 16)
            NegPos_flag = int(rawData[44:48], 16)

            t = (ts, ion, pm2dot5, pm10, ch2o, temp, humidity, co2, voc, NegPos_flag)
            data_list.append(t)

    for op in op_list:
        logging.debug(op)
        negativeIon = 'NULL'
        positiveIon = 'NULL'
        for data in data_list:
            if data[0].replace(second=0) == op:
                logging.debug(data)
                if data[9] == 0:
                    negativeIon = data[1]
                elif data[9] == 1:
                    positiveIon = data[1]
                pm2dot5 = data[2]
                pm10 = data[3]
                ch2o = round(data[4]/100, 3)
                temp = round(data[5]/10 ,2)
                humidity = round(data[6]/10, 2)
                co2 = data[7]
                voc = data[8] * 0.01
        value_string += f"('{op}', {gId}, '{name}', {pm2dot5}, {pm10}, {negativeIon}, {positiveIon}, {temp}, {humidity}, {ch2o}, {voc}, {co2}), "        
        logging.debug(f"'{op}', {gId}, '{name}', {negativeIon}, {positiveIon}, {pm2dot5}, {pm10}, {ch2o}, {temp}, {humidity}, {co2}, {voc}")

#replace into 首先嘗試插入數據到表中， 1. 如果發現表中已經有此行數據（根據主鍵或者唯一索引判斷）則先刪除此行數據，然後插入新的數據。 2. 否則，直接插入新數據。
if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        replace_sql = f"replace into `dataETL`.`airQuality` (`ts`, `gatewayId`, `name`, `ch1`, `ch2`, `negativeIon`, `positiveIon`, `temp`, `humidity`, `CH2O`, `VOC`, `co2`) Values {value_string}"
        try:
            my_cursor.execute(replace_sql)
            logging.debug(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")

my_conn.commit()
my_conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time() - s, 3)}s")
