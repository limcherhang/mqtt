import pymysql
import time
import threading
from datetime import date, datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler

def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host, 
            read_default_file = f'~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Failed]: {str(ex)}")

def getData(sId, my_conn, sql_string, flow, table, st, et, op_list, data_list):

    global history_flag

    if history_flag:
        sqlCommand = f"select {sql_string} from dataPlatform{st.year}.{table}_{st.month:02} where siteId={sId} and name='{flow}' and ts>='{st}' and ts<'{et}'"
    else:
        sqlCommand = f"select {sql_string} from dataPlatform.{table} where siteId={sId} and name='{flow}' and ts>='{st}' and ts<'{et}'"
        
    with my_conn.cursor() as prod_cursor:
        logging.debug(sqlCommand)
        prod_cursor.execute(sqlCommand)

        if prod_cursor.rowcount == 0:
            logging.warning(f"SiteId: {sId} {flow} has no data during the minute")
        else:
            for data in prod_cursor:
                #logging.debug(data)
                ts = data[0]
                value = data[2]
                if ts not in op_list: op_list.append(ts)
                if value is not None: data_list.append(data)
    
def main(sId, my_conn, st, et):
    logging.debug(f"Hi {sId}")

    op_list = []
    data_list = []
    if sId == 42:
        name = 'boiler#Plant' # Boiler Name
        flagPower = 'power#4' # Boiler Plant Power
        power_limit = 1 # To determine when boiler is ON
        temp1 = 'temp#5' # Boiler Feedwater In Temperature
        temp2 = 'temp#6' # Boiler Steam Out Temperature
        flow = 'flow#2' # Boiler Feedwater Flowrate
    
    getData(sId, my_conn, "ts, \'flowrate\', flowRate", flow, 'flow', st, et, op_list, data_list)
    getData(sId, my_conn, "ts, \'temp1\', temp", temp1, 'temp', st, et, op_list, data_list)
    getData(sId, my_conn, "ts, \'temp2\', temp", temp2, 'temp', st, et, op_list, data_list)

    #for index, op in enumerate(op_list): logging.debug(op)
    #for index, data in enumerate(data_list): logging.debug(data)

    value_string = ''
    for op in op_list:
        logging.debug(op)
        opFlag = 'NULL'
        RT = 'NULL'
        COP = 'NULL'
        flowRate = None
        InTemp = None
        OutTemp = None
        for data in data_list:
            ts = data[0]
            if ts.replace(second=0) == op:
                logging.debug(data)
                if data[1] == 'flowrate':
                    flowRate = data[2]
                elif data[1] == 'temp1':
                    InTemp = data[2]
                elif data[1] == 'temp2':
                    OutTemp = data[2]
        
        if flowRate is not None and InTemp is not None and OutTemp is not None:
            #logging.debug(f"flowrate: {flowRate}")
            #logging.debug(f"InTemp: {InTemp}")
            #logging.debug(f"OutTemp: {OutTemp}")
            flowRate = flowRate*4.403
            RT = (flowRate*(round(OutTemp-InTemp, 2))*18)/24
            COP = RT*3.517 / 25

            with my_conn.cursor() as prod_cursor:
                if history_flag:
                    sqlCommand = f"select powerConsumed from dataPlatform{st.year}.power_{st.month:02} where siteId={sId} and name='{flagPower}' and ts='{op}'"
                else:
                    sqlCommand = f"select powerConsumed from dataPlatform.power where siteId={sId} and name='{flagPower}' and ts='{op}'"
                prod_cursor.execute(sqlCommand)
                data = prod_cursor.fetchone()
                if data is not None:
                    powerConsumed = data[0]
                else:
                    continue
            if powerConsumed>power_limit:
                opFlag = 1
            else:
                opFlag = 0
        else:
            logging.warning(f"SiteId: {sId} has no enough data to calculate for Boiler at {op.strftime('%Y-%m-%d %H:%M:%S')} !!!")
            continue
        
        if opFlag != 'NULL':
            value_string += f"('{op}', {sId}, '{name}', {opFlag}, {round(RT, 4)}, {round(COP, 4)}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with my_conn.cursor() as my_cursor:
            replace_sql = f"replace into `processETL`.`boiler` (`ts`, `siteId`, `name`, `opFlag`, `RT`, `COP`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                my_cursor.execute(replace_sql)
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")         

    my_conn.commit()
    my_conn.close()

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
    level = logging.ERROR, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- Now: {nowTime} ---------- Program Started !")
st = (nowTime - timedelta(minutes=3)).replace(second=0)
et = nowTime

logging.debug(f"---------- from {st} to {et} ----------")

if (datetime.now() - st).days > 1:
    history_flag = True
else:
    history_flag = False


threads = []
sIds = [42]

for index, sId in enumerate(sIds):
    #prod_conn = connectDB('192.168.1.62')
    my_conn = connectDB('127.0.0.1')
    threads.append(threading.Thread(target=main, args=(sId, my_conn, st, et)))
    threads[index].start()

for index in range(len(sIds)):
    threads[index].join()

logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")
