from logging import handlers
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

    if supplyTemp is None or returnTemp is None or flow is None:
        return 0

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

    if power is None:
        return 0

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

def process(sId, my_conn, st, et):
    logging.debug(f"----- Hi {sId} -----")

    #prod_cursor = prod_conn.cursor()
    my_cursor = my_conn.cursor()
    #sqlCommand = f"select siteId, name, chillerDesc, gatewayId, CoolingCapacity, Efficiency, power, supplyTemp, returnTemp, flow from mgmtETL.chillerList where siteid={sId} and processETLFlag=1"
    sqlCommand = f"select siteId, name, chillerDesc, gatewayId, flagPower, CoolingCapacity, Efficiency, power, supplyTemp, returnTemp, flow from mgmtETL.chillerList where siteid={sId} and processETLFlag=1"
    my_cursor.execute(sqlCommand)

    if my_cursor.rowcount == 0:
        logging.warning(f"SQL: {sqlCommand}")
        logging.warning(f"There is no process for processETL in SiteId:{sId}")
        return 0
    
    value_string = ''

    for rows in my_cursor:
        #logging.debug(rows)
        sId = rows[0]
        if sId == 47:
            power_limit = 2
        elif sId == 42:
            power_limit = 20
        else:
            power_limit = 10
        name = rows[1]
        gId = rows[3]
        flagPower = rows[4]
        #if rows[5] is not None:
        #    power_limit = rows[5]
        #else:
        #    if sId==47:
        #        power_limit = 2
        #    else:
        #        power_limit = 10
        coolingCapacity_flag = rows[5]
        efficiency_flag = rows[6]
        power = rows[7]
        supplyTemp = rows[8]
        returnTemp = rows[9]
        flow = rows[10]
        
        logging.info(f"------------ Processing SiteId:{sId} {name} ------------")
        
        op_list = []
        data_list = []

        if coolingCapacity_flag is not None:
            bms_conn = connectDB('192.168.1.41')
            if sId == 23 or sId == 24:
                dNo = int(coolingCapacity_flag.split('_')[0])
                obj = int(coolingCapacity_flag.split('_')[1])
                sqlCommand = f"select ts, objectInstance, data from bms.rawData where gatewayId={gId} and deviceNo={dNo:02} and objectInstance={obj} and ts>='{st}' and ts<'{et}'"                
            else:
                serialNum = int(coolingCapacity_flag.split('_')[1])
                sqlCommand = f"select GWts, name, rawData from rawData.BACnet where gatewayId={gId} and name={serialNum} and GWts>='{st}' and GWts<'{et}'"
            
            with bms_conn.cursor() as bms_cursor:
                
                logging.debug(sqlCommand)
                bms_cursor.execute(sqlCommand)

                if bms_cursor.rowcount == 0:
                    logging.warning(f"SQL: {sqlCommand}")
                    logging.warning(f"SiteId: {sId} CoolingCapacity has no data during the minutes")
                else:
                    for data in bms_cursor:
                        logging.debug(data)
                        ts = data[0].replace(second=0)
                        if ts not in op_list: op_list.append(ts)
                        data_list.append(data)

            bms_conn.close()
        else:
            logging.debug(f"GatewayId: {gId} {name} has no RT data")
            getCoolingCapacity(sId, my_conn, supplyTemp, returnTemp, flow, st, et, op_list, data_list)

        if efficiency_flag is not None:
            bms_conn = connectDB('192.168.1.41')
            if sId == 23 or sId == 24:
                dNo = int(efficiency_flag.split('_')[0])
                obj = int(efficiency_flag.split('_')[1])
                sqlCommand = f"select ts, objectInstance, data from bms.rawData where gatewayId={gId} and deviceNo={dNo:02} and objectInstance={obj} and ts>='{st}' and ts<'{et}'"                
            else:
                serialNum = int(efficiency_flag.split('_')[1])
                sqlCommand = f"select GWts, name, rawData from rawData.BACnet where gatewayId={gId} and name={serialNum} and GWts>='{st}' and GWts<'{et}'"
            
            with bms_conn.cursor() as bms_cursor:
                logging.debug(sqlCommand)
                bms_cursor.execute(sqlCommand)

                if bms_cursor.rowcount == 0:
                    logging.warning(f"SQL: {sqlCommand}")
                    logging.warning(f"SiteId: {sId} Efficiency has no data during the minutes")
                else:
                    for data in bms_cursor:
                        logging.debug(data)
                        ts = data[0].replace(second=0)
                        if ts not in op_list: op_list.append(ts)
                        data_list.append(data)

            bms_conn.close()
        else:
            logging.debug(f"GatewayId: {gId} {name} has no efficiency data")
            getEfficiency(sId, my_conn, power, st, et, op_list, data_list)

        for index, op in enumerate(op_list): logging.debug(f"{index} {op}")
        for index, value in enumerate(data_list): logging.debug(f"{index} {value}")        

        for op in op_list:
            logging.debug(op)

            coolingCapacity = 'NULL'
            efficiency = 'NULL'
            opFlag = 'NULL'
            powerConsumd = 'NULL'

            for data in data_list:
                if data[0].replace(second=0) == op:
                    logging.debug(data)
                    
                    if isinstance(data[1], str):
                        if data[1] == 'RT':
                            coolingCapacity = float(data[2])
                        elif data[1].split('#')[0] == 'power':
                            powerConsumd = float(data[2])
                            #efficiency = ('NULL' if coolingCapacity == 'NULL' or coolingCapacity == 0 else round(powerConsumd/coolingCapacity, 3))
                            if coolingCapacity == 0:
                                efficiency = 0
                            elif coolingCapacity == 'NULL':
                                efficiency = 'NULL'
                            else:
                                efficiency = round(powerConsumd/coolingCapacity, 3)
                        else:
                            if coolingCapacity_flag is not None:
                                if int(data[1]) == int(coolingCapacity_flag.split('_')[1]):
                                    coolingCapacity = float(data[2])
                            if efficiency_flag is not None:
                                if int(data[1]) == int(efficiency_flag.split('_')[1]):
                                    efficiency = data[2]
                    else:
                        logging.debug(data[1])
                        if coolingCapacity_flag is not None:
                            if int(data[1]) == int(coolingCapacity_flag.split('_')[1]):
                                coolingCapacity = float(data[2])
                        if efficiency_flag is not None:
                            if int(data[1]) == int(efficiency_flag.split('_')[1]):
                                efficiency = data[2]

            if coolingCapacity == 'NULL' and efficiency == 'NULL':
                continue
            
            #if opFlag == 'NULL':
            if flagPower is not None:
                flagPower_string = ''
                if flagPower[1:-1].find(', ') != -1:
                    for string in flagPower[1:-1].split(', '):
                        string = string.replace("\"","'")
                        flagPower_string += f'{string}, '
                    sqlCommand = f"select round(sum(if(powerConsumed is NULL, 0, powerConsumed)), 2) from dataPlatform.power where siteId={sId} and name in ({flagPower_string[:-2]}) and ts='{op}'"
                else:
                    sqlCommand = f"select powerConsumed from dataPlatform.power where siteId={sId} and name='{flagPower[2:-2]}' and ts='{op}'"

                with my_conn.cursor() as my_cursor:
                    #sqlCommand = f"select powerConsumed from dataPlatform.power where siteid={sId} and name='{power}' and ts='{op}'"
                    logging.debug(sqlCommand)

                    my_cursor.execute(sqlCommand)                    

                    if my_cursor.rowcount == 0:
                        continue
                    else:
                        flagPower_powerConsumd = my_cursor.fetchone()[0]
                        if flagPower_powerConsumd is not None:
                            if flagPower_powerConsumd > power_limit:
                                opFlag = 1
                            else:
                                opFlag = 0
                        else:
                            logging.warning(f"SQL: {sqlCommand}")
                            logging.warning(f"There is no Flag Power data at {op} in SiteId: {sId}")
                            continue

            #logging.info(f"('{op}', {sId}, '{name}', {opFlag}, {powerConsumd}, {coolingCapacity}, {efficiency})")
            logging.info(f"('{op}', {sId}, '{name}', {opFlag}, {coolingCapacity}, {efficiency})")
            #value_string += f"('{op}', {sId}, '{name.replace('CH', 'chiller')}', {opFlag}, {powerConsumd}, {coolingCapacity}, {efficiency}), "
            value_string += f"('{op}', {sId}, '{name.replace('CH', 'chiller')}', {opFlag}, {coolingCapacity}, {efficiency}), "
    if value_string != '':
        value_string = value_string[:-2]
        with my_conn.cursor() as my_cursor:
            #replace_sql = f"replace into `processETL`.`chiller` (`ts`, `siteId`, `name`, `opFlag`, `powerConsumed`, `coolingCapacity`, `efficiency`) Values {value_string}"
            replace_sql = f"replace into `processETL`.`chiller` (`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                my_cursor.execute(replace_sql)
            except Exception as ex:
                logging.debug(f"SQL: {replace_sql} \n[insert ERROR]: {str(ex)}")

    my_conn.commit()
    my_cursor.close()
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
st = (nowTime - timedelta(minutes=4)).replace(second=0)
et = (nowTime - timedelta(minutes=1)).replace(second=0)
#st = datetime(2022, 2, 17)
#et = datetime(2022, 2, 18)


logging.debug(f"---------- from {st} to {et} ----------")

prod_conn = connectDB('127.0.0.1')

threads = []
sIds = []

with prod_conn.cursor() as prod_cursor:
    sqlCommand = f"SELECT siteId FROM mgmtETL.chillerList where processETLFlag=1 group by siteId"
    prod_cursor.execute(sqlCommand)
    
    for rows in prod_cursor:
        sId = rows[0]
        if sId not in sIds: sIds.append(sId)

prod_conn.close()

for index, sId in enumerate(sIds):
    logging.debug(f"----- Processing {sId} -----")
    #prod_conn = connectDB('192.168.1.62')
    #prod_conn = connectDB('127.0.0.1')
    my_conn = connectDB('127.0.0.1')
    threads.append(threading.Thread(target=process, args=(sId, my_conn, st, et)))
    threads[index].start()

for i in range(len(sIds)):
    threads[i].join()


#prod_conn.close()
#my_conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
