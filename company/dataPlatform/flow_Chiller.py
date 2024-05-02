import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import time
from datetime import datetime, timedelta

def connectDB(host):
    try:
        conn=pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")
    return None

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ---------- Program Started")

st = (nowTime-timedelta(minutes=3)).replace(second=0)
et = nowTime
#st = datetime(2022, 4, 22, 7, 54)
#et = datetime(2022, 4, 22, 7, 58)

conn = connectDB('127.0.0.1')

flows_list = ['flow#5', 'flow#6', 'flow#7', 'flow#8']
powers_list = ['Power#1', 'Power#2', 'Power#3', 'Power#4']

# get HDR Flow
with conn.cursor() as data_cursor:
    sqlCommand = f"select ts, flowRate from dataETL.flow where ts>='{st}' and ts<'{et}' and gatewayId=174 and name='Flow#1'"
    #print(sqlCommand)
    
    data_cursor.execute(sqlCommand)
    if data_cursor.rowcount == 0:
        logging.warning(f"GatewayId: 174 Flow#1 has no data from {st} to {et}")
    else:
        value_string = ''
        for data in data_cursor:
            ts = data[0]
            flow_HDR = data[1]
            logging.debug(f"----- Processing {ts} {flow_HDR} -----")

            power_flag = True
            opChiller_list = []
            for i in range(4):
                power = powers_list[i]
                with conn.cursor() as cursor:
                    #sqlCommand = f"select powerConsumed from dataPlatform.power where ts='{ts}' and siteId=48 and name='{power}'"
                    sqlCommand = f"select round((ch1Watt+ch2Watt+ch3Watt)/1000, 3) from dataETL.power where ts='{ts}' and gatewayId=174 and name='{power}'"
                    logging.debug(sqlCommand)
                    cursor.execute(sqlCommand)

                    if cursor.rowcount == 0:
                        #print(f"SiteId: 48 {power} has no data at {ts}")
                        power_flag = False
                        continue
                    else:
                        data = cursor.fetchone()
                        if data is not None:
                            powerConsumed = data[0]
                            #logging.debug(ts, power, powerConsumed)
                            if powerConsumed > 10:
                                opChiller_list.append(i)
            
            if len(opChiller_list) != 0:
                op_Cnt = len(opChiller_list)
                for i in range(4):
                    if i in opChiller_list:
                        logging.info(f"'{ts}', 48, '{flows_list[i]}', {round(flow_HDR/op_Cnt, 3)}")
                        value_string += f"('{ts}', 48, '{flows_list[i]}', {round(flow_HDR/op_Cnt, 3)}), "
                    else:
                        logging.info(f"'{ts}', 48, '{flows_list[i]}', 0")
                        value_string += f"('{ts}', 48, '{flows_list[i]}', 0), "
            else:
                logging.debug(f"No Chiller operating at {ts}")
                if not power_flag: continue
                for i in range(4):
                    flow = flows_list[i]
                    logging.info(f"'{ts}', 48, '{flow}', {round(flow_HDR/4, 3)}")
                    value_string += f"('{ts}', 48, '{flow}', {round(flow_HDR/4, 3)}), "

        if value_string != '':
            value_string = value_string[:-2]
            with conn.cursor() as cursor:
                replace_sql = f"replace into `dataPlatform`.`flow` (`ts`, `siteId`, `name`, `flowRate`) Values {value_string}"
                try:
                    cursor.execute(replace_sql)
                    conn.commit()
                except Exception as ex:
                    logging.error(f"SQL: {replace_sql}")
                    logging.error(f"[Insert ERROR]: {str(ex)}")

conn.close()
logging.info(f"------ Connection closed ------ took:{round(time.time()-s, 3)}s")