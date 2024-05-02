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
        sqlCommand = f"select powerConsumed from dataPlatform.power where ts='{ts}' and siteId=76 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def getTempData(conn, ts, name):

    with conn.cursor() as data_cursor:
        sqlCommand = f"select temp from dataPlatform.temp where ts='{ts}' and siteId=76 and name='{name}'"
        logging.debug(sqlCommand)

        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()

        if data is not None:
            return data[0]
        else:
            return None

def insertTemp(conn, ts, name, temp):

    with conn.cursor() as cursor:
        replace_sql = f"replace into `dataPlatform`.`temp` (`ts`, `siteId`, `name`, `temp`) Values ('{ts}', 76, '{name}', {round(temp/3, 2)})"
        logging.debug(replace_sql)

        try:
            cursor.execute(replace_sql)
            #conn.commit()
            logging.info(f"Temp Replace Succeed!")
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Temp Replace Error]: {str(ex)}")

def main():

    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=4)).replace(second=0)
    et = (nowTime - timedelta(minutes=1)).replace(second=0)

    logging.info(f"---------- from {st} to {et} ----------")

    conn = connectDB('127.0.0.1')
    #prod_conn = connectDB('192.168.1.62')

    chiller_list = ['chiller#1', 'chiller#2', 'chiller#3', 'chiller#plant']
    power_list = ['power#1', 'power#2', 'power#3', 'power#13']
    supplyTemp_list = ['temp#2', 'temp#6', 'temp#10']
    returnTemp_list = ['temp#1', 'temp#5', 'temp#9']
    hdrFlow = 'flow#1'

    value_string = ''

    for index, name in enumerate(chiller_list):

        with conn.cursor() as data_cursor:
            sqlCommand = f"select ts, flowRate from dataPlatform.flow where ts>='{st}' and ts<'{et}' and siteId=76 and name='{hdrFlow}'"
            logging.debug(sqlCommand)

            data_cursor.execute(sqlCommand)
            if data_cursor.rowcount == 0:
                logging.warning(f"siteId: 76 {hdrFlow} has no data from {st} to {et}")
            for data in data_cursor:
                ts = data[0].replace(second=0)
                flowrate = data[1]

                if index != 3:
                    # get Power data
                    ch1_power = getPowerData(conn, ts, 'power#1')
                    ch2_power = getPowerData(conn, ts, 'power#2')
                    ch3_power = getPowerData(conn, ts, 'power#3')
                    plant_power = getPowerData(conn, ts, 'power#13')

                    # get Temp data
                    supplyTempData = getTempData(conn, ts, supplyTemp_list[index])
                    returnTempData = getTempData(conn, ts, returnTemp_list[index])

                if ch1_power is None or ch2_power is None or ch3_power is None or supplyTempData is None or returnTempData is None:
                    continue

                if name.split('#')[-1] == 'plant':
                    #plant_power = ch1_power + ch2_power
                    if ch1_power >= 10 or ch2_power >= 10 or ch3_power >= 10:
                        op_Flag = 1
                    else:
                        op_Flag = 0
                    
                    # get plant supply Temp data
                    with conn.cursor() as data_cursor:
                        sqlCommand = f"select sum(temp) from dataPlatform.temp where ts='{ts}' and siteId=76 and name in ('temp#2', 'temp#6', 'temp#10')"
                        logging.debug(sqlCommand)

                        data_cursor.execute(sqlCommand)
                        data = data_cursor.fetchone()
                        if data is not None:
                            plant_supplyTempData = data[0]
                            insertTemp(conn, ts, 'temp#13', plant_supplyTempData)
                    
                    # get plant return Temp data
                    with conn.cursor() as data_cursor:
                        sqlCommand = f"select sum(temp) from dataPlatform.temp where ts='{ts}' and siteId=76 and name in ('temp#1', 'temp#5', 'temp#9')"
                        logging.debug(sqlCommand)

                        data_cursor.execute(sqlCommand)
                        data = data_cursor.fetchone()
                        if data is not None:
                            plant_returnTempData = data[0]
                            insertTemp(conn, ts, 'temp#14', plant_returnTempData)
                    
                    coolingCapacityData = (997 * 4.2 * (plant_returnTempData/3 - plant_supplyTempData/3) * flowrate) / (3600 * 3.51685)
                    if coolingCapacityData == 0:
                        efficiencyData = 0
                    else:
                        efficiencyData = plant_power / coolingCapacityData

                else:
                    if index == 0:
                        powerData = ch1_power
                        if powerData >= 10:
                            op_Flag = 1
                        else:
                            op_Flag = 0
                        flowrateData = (0 if plant_power == 0 else flowrate * (ch1_power / plant_power))
                    elif index == 1:
                        powerData = ch2_power
                        if powerData >= 10:
                            op_Flag = 1
                        else:
                            op_Flag = 0
                        flowrateData = (0 if plant_power == 0 else flowrate * (ch2_power / plant_power))
                    elif index == 2:
                        powerData = ch3_power
                        if powerData >= 10:
                            op_Flag = 1
                        else:
                            op_Flag = 0
                        flowrateData = (0 if plant_power == 0 else flowrate * (ch3_power / plant_power))

                    coolingCapacityData = (997 * 4.2 * (returnTempData-supplyTempData) * flowrateData) / (3600 * 3.51685)
                    if coolingCapacityData == 0:
                        efficiencyData = 0
                    else:
                        efficiencyData = powerData / coolingCapacityData

                logging.info(f"'{ts}', 76, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}")
                value_string += f"('{ts}', 76, '{name}', {op_Flag}, {round(coolingCapacityData, 3)}, {round(efficiencyData, 3)}), "

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
        level = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
