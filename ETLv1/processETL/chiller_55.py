import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
import time
import threading
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

def getCoolingCapacity(sId, my_conn, supplyTemp, returnTemp, flow, st, et, op_list, data_list):
    logging.debug("This is getCoolingCapacity funtion !")

    temporary_list = []
    with my_conn.cursor() as my_cursor:
        sqlCommand = f"select ts, name, temp from dataPlatform.temp where siteId={sId} and name in ('{supplyTemp}', '{returnTemp}') and ts>='{st}' and ts<'{et}'"
        logging.debug(f"temp sql: {sqlCommand}")
        my_cursor.execute(sqlCommand)
        
        if my_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"SiteId: {sId} temp has no data during the minutes")
        else:
            for data in my_cursor:
                logging.debug(data)
                ts = data[0]
                if ts not in op_list: op_list.append(ts)
                temporary_list.append(data)

    with my_conn.cursor() as my_cursor:
        sqlCommand = f"select ts, name, flowRate from dataPlatform.flow where siteId={sId} and name='{flow}' and ts>='{st}' and ts<'{et}'"
        logging.debug(f"flow sql: {sqlCommand}")
        my_cursor.execute(sqlCommand)

        if my_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"SiteId: {sId} flow has no data during the minutes")
        else:
            for data in my_cursor:
                logging.debug(data)
                ts = data[0]
                if ts not in op_list: op_list.append(ts)
                temporary_list.append(data)
    
    for index, op in enumerate(op_list): logging.debug(f"{index} {op}")

    for index, data in enumerate(temporary_list): logging.debug(f"{index} {data}")

    for op in op_list:
        #logging.debug(op)
        data_tuple = (op,)
        supplyTempData = 'NULL'
        returnTempData = 'NULL'
        flowrate = 'NULL'
        for data in temporary_list:
            if data[0] == op:
                logging.debug(data)
                if data[1] == supplyTemp:
                    supplyTempData = data[2]
                if data[1] == returnTemp:
                    returnTempData = data[2]
                if data[1] == flow:
                    flowrate = data[2]
        
        if supplyTempData == 'NULL' or returnTempData == 'NULL' or flowrate == 'NULL':
            continue
        else:
            coolingCapacity = (997 * 4.2 * (returnTempData-supplyTempData) * flowrate)/ (3600 * 3.51685)
            data_tuple += ('RT', round(coolingCapacity,2))
        
        data_list.append(data_tuple)

def getEfficiency(sId, my_conn, power, st, et, op_list, data_list):

    power_string = ''
    if power[1:-1].find(', ') != -1:
        for string in power[1:-1].split(', '):
            string = string.replace("\"","'")
            power_string += f"{string}, "

        sqlCommand = f"select ts, 'power#total', round(sum(if(powerConsumed is NULL, 0, powerConsumed)), 2) from dataPlatform.power where siteId={sId} and name in ({power_string[:-2]}) and ts>='{st}' and ts<'{et}' group by ts"
    else:
        sqlCommand = f"select ts, name, powerConsumed from dataPlatform.power where siteId={sId} and name='{power[2:-2]}' and ts>='{st}' and ts<'{et}'"

    with my_conn.cursor() as my_cursor:
        #sqlCommand = f"select ts, name, powerConsumed from dataPlatform.power where siteId={sId} and name='{power}' and ts>='{st}' and ts<'{et}'"
        logging.debug(f"power sql: {sqlCommand}")
        my_cursor.execute(sqlCommand)
        
        if my_cursor.rowcount == 0:
            logging.warning(f"SQL: {sqlCommand}")
            logging.warning(f"SiteId: {sId} power has no data during the minutes")
        else:
            for data in my_cursor:
                logging.debug(data)
                ts = data[0]
                if ts not in op_list: op_list.append(ts)
                data_list.append(data)

def processPlant(sId, my_conn, st, et):

    power_limit = 10
    name_list = ['HDR#1', 'HDR#2']
    supplyTemp_list = ['temp#29', 'temp#31']
    returnTemp_list = ['temp#30', 'temp#32']
    flow_list = ['flow#15', 'flow#16']
    power = "[\"Power#1\", \"Power#2\", \"Power#3\", \"Power#4\", \"Power#5\", \"Power#6\", \"Power#7\", \"Power#8\", \"Power#9\", \"Power#10\", \"Power#11\", \"Power#12\", \"Power#13\", \"Power#14\", \"Power#15\", \"Power#16\", \"Power#17\", \"Power#18\", \"Power#19\", \"Power#20\", \"Power#21\", \"Power#22\", \"Power#23\", \"Power#24\", \"Power#25\", \"Power#26\", \"Power#27\", \"Power#28\"]"

    op_list = []
    data_list = []

    for index, name in enumerate(name_list):
        logging.debug(f"------------ Processing SiteId:{sId} {name} ------------")
        
        supplyTemp = supplyTemp_list[index]
        returnTemp = returnTemp_list[index]
        flow = flow_list[index]

        getCoolingCapacity(sId, my_conn, supplyTemp, returnTemp, flow, st, et, op_list, data_list)
        
    #for index, op in enumerate(op_list): logging.debug(f"{index} {op}")
    #for index, value in enumerate(data_list): logging.debug(f"{index} {value}") 

    logging.info(f"------------ Processing SiteId:{sId} chiller#Plant ------------")
    value_string = ''
    for op in op_list:
        logging.debug(op)
        
        coolingCapacity = 0
        powerConsumd = None
        efficiency = 'NULL'
        opFlag = 'NULL'

        for data in data_list:
            if data[0].replace(second=0) == op:
                logging.debug(data)
                if data[1] == 'RT':
                    coolingCapacity += float(data[2])

        power_string = ''
        if power[1:-1].find(', ') != -1:
            for string in power[1:-1].split(', '):
                string = string.replace("\"","'")
                power_string += f"{string}, "

        with my_conn.cursor() as my_cursor:
            sqlCommand = f"select round(sum(if(powerConsumed is NULL, 0, powerConsumed)), 2) from dataPlatform.power where siteId={sId} and name in ({power_string[:-2]}) and ts='{op}'"
            logging.debug(f"plant power sql: {sqlCommand}")
            my_cursor.execute(sqlCommand)
            
            if my_cursor.rowcount == 0:
                logging.warning(f"SQL: {sqlCommand}")
                logging.warning(f"SiteId: {sId} power has no data during the minutes")
            else:
                data = my_cursor.fetchone()
                if data is not None:
                    powerConsumd = data[0]
                       
        if coolingCapacity == 0: 
            continue
        elif powerConsumd is None:
            continue
        else:
            efficiency = round(powerConsumd/coolingCapacity, 3)

        if powerConsumd > power_limit:
            opFlag = 1
        else:
            opFlag = 0

        logging.info(f"('{op}', {sId}, 'chiller#Plant', {opFlag}, {coolingCapacity}, {efficiency})")
        value_string += f"('{op}', {sId}, 'chiller#Plant', {opFlag}, {coolingCapacity}, {efficiency}), "

    if value_string != '':
        value_string = value_string[:-2]
        with my_conn.cursor() as my_cursor:
            replace_sql = f"replace into `processETL`.`chiller` (`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                my_cursor.execute(replace_sql)
                my_conn.commit()
            except Exception as ex:
                logging.debug(f"SQL: {replace_sql} \n[insert ERROR]: {str(ex)}")

def process(sId, my_conn, st, et):
    logging.debug(f"----- Hi {sId} -----")

    name_list = ['chiller#8','chiller#9','chiller#10','chiller#11','chiller#12','chiller#13','chiller#14','chiller#15','chiller#16','chiller#17','chiller#18','chiller#19','chiller#20','chiller#21','chiller#22','chiller#23','chiller#24','chiller#25']
    supplyTemp_list = ['temp#79', 'temp#81', 'temp#84', 'temp#87', 'temp#90', 'temp#93', 'temp#96', 'temp#99', 'temp#101', 'temp#104', 'temp#107', 'temp#110', 'temp#113', 'temp#116', 'temp#119', 'temp#121', 'temp#124', 'temp#127']
    returnTemp_list = ['temp#80', 'temp#82', 'temp#85', 'temp#88', 'temp#91', 'temp#94', 'temp#97', 'temp#100', 'temp#102', 'temp#105', 'temp#108', 'temp#111', 'temp#114', 'temp#117', 'temp#120', 'temp#122', 'temp#125', 'temp#128']
    flow_list = ['flow#19', 'flow#20', 'flow#21', 'flow#22', 'flow#23', 'flow#24', 'flow#25', 'flow#26', 'flow#27', 'flow#28', 'flow#29', 'flow#30', 'flow#31', 'flow#32', 'flow#33', 'flow#34', 'flow#35', 'flow#36']
    
    value_string = ''

    for index, name in enumerate(name_list):
        
        supplyTemp = supplyTemp_list[index]
        returnTemp = returnTemp_list[index]
        flow = flow_list[index]
        
        logging.info(f"------------ Processing SiteId:{sId} {name} ------------")
        
        op_list = []
        data_list = []

        getCoolingCapacity(sId, my_conn, supplyTemp, returnTemp, flow, st, et, op_list, data_list)

        for index, op in enumerate(op_list): logging.debug(f"{index} {op}")
        for index, value in enumerate(data_list): logging.debug(f"{index} {value}")        

        for op in op_list:
            logging.debug(op)

            coolingCapacity = 'NULL'
            efficiency = 'NULL'
            opFlag = 'NULL'

            for data in data_list:
                if data[0].replace(second=0) == op:
                    logging.debug(data)
                    
                    if data[1] == 'RT':
                        coolingCapacity = float(data[2])

            if coolingCapacity == 'NULL': continue
            
            logging.info(f"('{op}', {sId}, '{name}', {opFlag}, {coolingCapacity}, {efficiency})")
            value_string += f"('{op}', {sId}, '{name}', {opFlag}, {coolingCapacity}, {efficiency}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with my_conn.cursor() as my_cursor:
            replace_sql = f"replace into `processETL`.`chiller` (`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                my_cursor.execute(replace_sql)
                my_conn.commit()
            except Exception as ex:
                logging.debug(f"SQL: {replace_sql} \n[insert ERROR]: {str(ex)}")

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Started !")
    st = (nowTime - timedelta(minutes=4)).replace(second=0)
    et = (nowTime - timedelta(minutes=1)).replace(second=0)
    #st = datetime(2022, 2, 17)
    #et = datetime(2022, 2, 18)


    logging.debug(f"---------- from {st} to {et} ----------")

    my_conn = connectDB('127.0.0.1')
    process(55, my_conn, st, et)
    processPlant(55, my_conn, st, et)
    my_conn.close()

    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
