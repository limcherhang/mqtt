import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import time


def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host, 
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[MySQL Connection Error]: {str(ex)}")

def getPowerData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select powerConsumed from dataPlatform.power where ts='{ts}' and siteId=75 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getPlantPowerData(conn, ts):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select round(sum(powerConsumed), 2) from dataPlatform.power where ts='{ts}' and siteId=75 and name!='power#7' and powerConsumed>1"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getTempData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select temp from dataPlatform.temp where ts='{ts}' and siteId=75 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getFlowData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select flowRate from dataPlatform.flow where ts='{ts}' and siteId=75 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def insertTemp(conn, ts, name, temp):

    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataPlatform`.`temp` (`ts`, `siteId`, `name`, `temp`) Values ('{ts}', 75, '{name}', {temp})"
        logging.debug(replace_sql)

        try:
            cursor.execute(replace_sql)
            conn.commit()
            logging.info(f"Temp Replace Succeed!")
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Temp Replace Error]: {str(ex)}")

def insertPower(conn, ts, name, powerConsumed):

    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataPlatform`.`power` (`ts`, `siteId`, `name`, `powerConsumed`) Values ('{ts}', 75, '{name}', {powerConsumed})"
        logging.debug(replace_sql)

        try:
            cursor.execute(replace_sql)
            conn.commit()
            logging.info(f"Power Replace Succeed!")
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Power Replace Error]: {str(ex)}")

def main():

    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=4)).replace(second=0)
    et = (nowTime - timedelta(minutes=1)).replace(second=0)

    logging.info(f"---------- from {st} to {et} ----------")

    conn = connectDB('127.0.0.1')
    #prod_conn = connectDB('192.168.1.62')

    chiller_list = ['chiller#1', 'chiller#plant']
    power_list = ['power#1']
    chp_power_list = ['power#3', 'power#4']
    cdp_power_list = ['power#5', 'poewr#6']
    ct_power_list = ['power#2']
    supplyTemp_list = ['temp#2']
    returnTemp_list = ['temp#1']
    flow_list = ['flow#1']

    value_string = ''

    while st <= et:
        ts = st
        st += timedelta(minutes=1)

        logging.info(f"----- Processing {ts} -----")

        plant_opFlag = None
        opCnt = 0
        plant_powerData = 0
        plant_supplyTempData = 0
        plant_returnTempData = 0
        plant_flowrateData = 0

        ch1_power = getPowerData(conn, ts, power_list[0])
        if ch1_power is None:
            logging.debug(f"{ch1_power}")
            continue

        for index, name in enumerate(chiller_list):
            logging.debug(name)

            if index != chiller_list.index('chiller#plant'):
                power = power_list[index]
                supplyTemp = supplyTemp_list[index]
                returnTemp = returnTemp_list[index]
                flow = flow_list[index]
            else:
                plant_powerData = getPlantPowerData(conn, ts)
                insertPower(conn, ts, 'power#7', plant_powerData)

                if plant_opFlag is None:
                    plant_opFlag = 0
                    coolingCapacityData = 0
                    efficiencyData = 0
                else:                    
                    plant_supplyTempData = round(plant_supplyTempData/opCnt, 2)
                    plant_returnTempData = round(plant_returnTempData/opCnt, 2)
                    plant_flowrateData = round(plant_flowrateData/opCnt, 2)

                    coolingCapacityData = (997 * 4.2 * (plant_returnTempData - plant_supplyTempData) * plant_flowrateData) / (3600 * 3.51685)
                    if coolingCapacityData == 0:
                        efficiencyData = 0
                    else:
                        efficiencyData = plant_powerData / coolingCapacityData
                
                logging.info(f"'{ts}', 75, '{name}', {plant_opFlag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}")
                value_string += f"('{ts}', 75, '{name}', {plant_opFlag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}), "
                continue
                
            powerData = getPowerData(conn, ts, power)
            supplyTempData = getTempData(conn, ts, supplyTemp)
            returnTempData = getTempData(conn, ts, returnTemp)
            flowrateData = getFlowData(conn, ts, flow)

            if powerData is None or supplyTempData is None or returnTempData is None or flowrateData is None:
                logging.error(f"'{ts}', {powerData}, {supplyTempData}, {returnTempData}, {flowrateData}")
                continue
            
            if powerData >= 10:
                op_Flag = 1
                opCnt += 1

                plant_supplyTempData += supplyTempData
                plant_returnTempData += returnTempData
                plant_flowrateData += flowrateData
                plant_opFlag = 1
            else:
                op_Flag = 0
            
            coolingCapacityData = (997 * 4.2 * (returnTempData - supplyTempData) * flowrateData) / (3600 * 3.51685)
            if coolingCapacityData == 0:
                efficiencyData = 0
            else:
                efficiencyData = powerData / coolingCapacityData

            logging.info(f"'{ts}', 75, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}")
            value_string += f"('{ts}', 75, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}), "

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `processETL`.`chiller` (`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.INFO, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")