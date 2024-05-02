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
        sqlCommand = f"select powerConsumed from dataPlatform.power where ts='{ts}' and siteId=77 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getPlantPowerData(conn, ts):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select round(sum(powerConsumed), 2) from dataPlatform.power where ts='{ts}' and siteId=77 and name!='power#13' and powerConsumed>1"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getTempData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select temp from dataPlatform.temp where ts='{ts}' and siteId=77 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getFlowData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select flowRate from dataPlatform.flow where ts='{ts}' and siteId=77 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def insertTemp(conn, ts, name, temp):

    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataPlatform`.`temp` (`ts`, `siteId`, `name`, `temp`) Values ('{ts}', 77, '{name}', {temp})"
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
        replace_sql = f"replace into `dataPlatform`.`power` (`ts`, `siteId`, `name`, `powerConsumed`) Values ('{ts}', 77, '{name}', {powerConsumed})"
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

    chiller_list = ['chiller#1', 'chiller#2', 'chiller#3', 'chiller#plant']
    power_list = ['power#1', 'power#2', 'power#3']
    chp_power_list = ['power#7', 'power#8', 'power#9']
    cdp_power_list = ['power#10', 'power#11', 'power#12']
    ct_power_list = ['power#4', 'power#5', 'power#6']
    supplyTemp_list = ['temp#2', 'temp#6', 'temp#10']
    returnTemp_list = ['temp#1', 'temp#5', 'temp#9']
    hdrFlow = 'flow#1'

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

        plant_flowrateData = getFlowData(conn, ts, hdrFlow)
        ch1_power = getPowerData(conn, ts, power_list[0])
        ch2_power = getPowerData(conn, ts, power_list[1])
        ch3_power = getPowerData(conn, ts, power_list[2])

        if ch1_power is None or ch2_power is None or ch3_power is None or plant_flowrateData is None:
            logging.debug(f"{ch1_power}, {ch2_power}, {ch3_power}, {plant_flowrateData}")
            continue
        else:
            total_power = ch1_power + ch2_power + ch3_power

        for index, name in enumerate(chiller_list):
            logging.debug(name)

            if index != chiller_list.index('chiller#plant'):
                if index == 0:
                    powerData = ch1_power
                elif index == 1:
                    powerData = ch2_power
                elif index == 2:
                    powerData = ch3_power
                
                if plant_flowrateData == 0 or total_power == 0:
                    flowrateData = 0
                else:
                    flowrateData = plant_flowrateData * (powerData / total_power)
                
                supplyTempData = getTempData(conn, ts, supplyTemp_list[index])
                returnTempData = getTempData(conn, ts, returnTemp_list[index])
            else:
                #plant_powerData = getPlantPowerData(conn, ts)
                insertPower(conn, ts, 'power#13', plant_powerData)

                if plant_opFlag is None:
                    plant_opFlag = 0
                    coolingCapacityData = 0
                    efficiencyData = 0
                else:
                    plant_supplyTempData = round(plant_supplyTempData/opCnt, 2)
                    plant_returnTempData = round(plant_returnTempData/opCnt, 2)

                    insertTemp(conn, ts, 'temp#14', plant_supplyTempData)
                    insertTemp(conn, ts, 'temp#13', plant_returnTempData)

                    coolingCapacityData = (997 * 4.2 * (plant_returnTempData - plant_supplyTempData) * plant_flowrateData) / (3600 * 3.51685)
                    if coolingCapacityData == 0:
                        efficiencyData = 0
                    else:
                        efficiencyData = plant_powerData / coolingCapacityData

                logging.info(f"'{ts}', 77, '{name}', {plant_opFlag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}")
                value_string += f"('{ts}', 77, '{name}', {plant_opFlag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}), "
                continue

            if powerData is None or supplyTempData is None or returnTempData is None or flowrateData is None:
                logging.debug(f"'{ts}', {powerData}, {supplyTempData}, {returnTempData}, {flowrateData}")
                continue

            if powerData >= 10:
                op_Flag = 1
                opCnt += 1

                chp_power = getPowerData(conn, ts, chp_power_list[index])
                chp_power = 0 if chp_power is None else chp_power
                cdp_power = getPowerData(conn, ts, cdp_power_list[index])
                cdp_power = 0 if cdp_power is None else cdp_power
                ct_power = getPowerData(conn, ts, ct_power_list[index])
                ct_power = 0 if ct_power is None else ct_power
                
                plant_powerData = powerData + chp_power + cdp_power + ct_power
                plant_supplyTempData += supplyTempData
                plant_returnTempData += returnTempData
                plant_opFlag = 1
            else:
                op_Flag =0

            coolingCapacityData = (997 * 4.2 * (returnTempData - supplyTempData) * flowrateData) / (3600 * 3.51685)
            if coolingCapacityData == 0:
                efficiencyData = 0
            else:
                efficiencyData = powerData / coolingCapacityData
            
            logging.info(f"'{ts}', 77, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}")
            value_string += f"('{ts}', 77, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}), "

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
        level = logging.DEBUG, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")