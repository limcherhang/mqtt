# moving real-time data in `iotmgmt` from 1.41 to 6.41
# updated on 2023/1/5 by Carlos

import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import pandas as pd

def connectDB(host, port):
    count = 0 #0425_eric
    while True:
        try:
            conn = pymysql.connect(
                host = host, 
                port = port, 
                read_default_file = '~/.my.cnf'
            )
            logging.info(f"IP: {host} Connection Succeed!")
            return conn
        except Exception as ex:
            logging.error(f"[MySQL Connection Error]: {str(ex)}, reconnect in 5 senconds...")
            #0425_eric
            count+=1
            if count >=10:
                print("reconnect > 10 close!")
                break
                #os._exit(0)

def gpio(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi gpio func")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.gpio where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"no 'gpio' data for gId: {gId} from {st} to {et}")
            return

        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            port = 'NULL' if data[5] is None else data[5]
            value = 'NULL' if data[6] is None else data[6]
            sw1 = 'NULL' if data[7] is None else data[7]
            sw2 = 'NULL' if data[8] is None else data[8]
            sw3 = 'NULL' if data[9] is None else data[9]
            sw4 = 'NULL' if data[10] is None else data[10]
            sw5 = 'NULL' if data[11] is None else data[11]
            pin0 = 'NULL' if data[12] is None else data[12]
            pin1 = 'NULL' if data[13] is None else data[13]
            pin2 = 'NULL' if data[14] is None else data[14]
            pin3 = 'NULL' if data[15] is None else data[15]
            pin4 = 'NULL' if data[16] is None else data[16]
            pin5 = 'NULL' if data[17] is None else data[17]
            pin6 = 'NULL' if data[18] is None else data[18]
            pin7 = 'NULL' if data[19] is None else data[19]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {port}, {value}, {sw1}, {sw2}, {sw3}, {sw4}, {sw5}, {pin0}, {pin1}, {pin2}, {pin3}, {pin4}, {pin5}, {pin6}, {pin7}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`gpio` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"Gpio Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def pm(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi pm func")
    
    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.pm where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"no 'pm' data for gId: {gId} from {st} to {et}")
            return
        
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            randTime = 'NULL' if data[5] is None else data[5]
            ch1Watt = 'NULL' if data[6] is None else data[6]
            ch2Watt = 'NULL' if data[7] is None else data[7]
            ch3Watt = 'NULL' if data[8] is None else data[8]
            totalPositiveWattHour = 'NULL' if data[9] is None else data[9]
            totalNegativeWattHour = 'NULL' if data[10] is None else data[10]
            ch1Current = 'NULL' if data[11] is None else data[11]
            ch2Current = 'NULL' if data[12] is None else data[12]
            ch3Current = 'NULL' if data[13] is None else data[13]
            ch1Voltage = 'NULL' if data[14] is None else data[14]
            ch2Voltage = 'NULL' if data[15] is None else data[15]
            ch3Voltage = 'NULL' if data[16] is None else data[16]
            ch1PowerFactor = 'NULL' if data[17] is None else data[17]
            ch2PowerFactor = 'NULL' if data[18] is None else data[18]
            ch3PowerFactor = 'NULL' if data[19] is None else data[19]
            voltage12 = 'NULL' if data[20] is None else data[20]
            voltage23 = 'NULL' if data[21] is None else data[21]
            voltage31 = 'NULL' if data[22] is None else data[22]
            ch1Hz = 'NULL' if data[23] is None else data[23]
            ch2Hz = 'NULL' if data[24] is None else data[24]
            ch3Hz = 'NULL' if data[25] is None else data[25]
            i1THD = 'NULL' if data[26] is None else data[26]
            i2THD = 'NULL' if data[27] is None else data[27]
            i3THD = 'NULL' if data[28] is None else data[28]
            v1THD = 'NULL' if data[29] is None else data[29]
            v2THD = 'NULL' if data[30] is None else data[30]
            v3THD = 'NULL' if data[31] is None else data[31]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {randTime}, {ch1Watt}, {ch2Watt}, {ch3Watt}, {totalPositiveWattHour}, {totalNegativeWattHour}, {ch1Current}, {ch2Current}, {ch3Current}, {ch1Voltage}, {ch2Voltage}, {ch3Voltage}, {ch1PowerFactor}, {ch2PowerFactor}, {ch3PowerFactor}, {voltage12}, {voltage23}, {voltage31}, {ch1Hz}, {ch2Hz}, {ch3Hz}, {i1THD}, {i2THD}, {i3THD}, {v1THD}, {v2THD}, {v3THD}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`pm` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"PM Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def co2(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi co2 func")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.co2 where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            logging.warning(f"no 'co2' data for gId: {gId} from {st} to {et}")
            return

        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId =  data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            randTime = 'NULL' if data[5] is None else data[5]
            co2ppm = 'NULL' if data[6] is None else data[6]
            temp = 'NULL' if data[7] is None else data[7]
            humidity = 'NULL' if data[8] is None else data[8]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {randTime}, {co2ppm}, {temp}, {humidity}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`co2` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"Co2 Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def zigbeeRawModbus(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi zigbeeRawModbus func")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.zigbeeRawModbus where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'zigbeeRawModbus' data for gId: {gId} from {st} to {et}")
            return
        
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            modbusCmd = 'NULL' if data[5] is None else data[5]
            responseData = 'NULL' if data[6] is None else data[6]
            
            if receivedSync == 'NULL':
                value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', {receivedSync}, '{modbusCmd}', '{responseData}'), "
            else:
                value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', '{modbusCmd}', '{responseData}'), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`zigbeeRawModbus` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"ZigbeeRawModbus Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def ultrasonicFlow2(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi ultrasonicFlow2 func")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.ultrasonicFlow2 where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'ultrasonicFlow2' data for gId: {gId} from {st} to {et}")
            return

        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            flowRate = 'NULL' if data[5] is None else data[5]
            velocity = 'NULL' if data[6] is None else data[6]
            netAccumulator = 'NULL' if data[7] is None else data[7]
            temp1Inlet = 'NULL' if data[8] is None else data[8]
            temp2Outlet = 'NULL' if data[9] is None else data[9]
            errorCode = 'NULL' if data[10] is None else data[10]
            signalQuality = 'NULL' if data[11] is None else data[11]
            upstreamStrength = 'NULL' if data[12] is None else data[12]
            downstreamStrength = 'NULL' if data[13] is None else data[13]
            calcRateMeasTravelTime = 'NULL' if data[14] is None else data[14]
            reynoldsNumber = 'NULL' if data[15] is None else data[15]
            pipeReynoldsFactor = 'NULL' if data[16] is None else data[16]
            totalWorkingTime = 'NULL' if data[17] is None else data[17]
            totalPowerOnOffTime = 'NULL' if data[18] is None else data[18]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {flowRate}, {velocity}, {netAccumulator}, {temp1Inlet}, {temp2Outlet}, '{errorCode}', {signalQuality}, {upstreamStrength}, {downstreamStrength}, {calcRateMeasTravelTime}, {reynoldsNumber}, {pipeReynoldsFactor}, {totalWorkingTime}, {totalPowerOnOffTime}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`ultrasonicFlow2` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"ultrasonicFlow2 Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def waterQuality(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi waterQuality func")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.waterQuality where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'waterQuality' data for gId: {gId} from {st} to {et}")
            return

        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            ieee = 'NULL' if data[2] is None else data[2]
            receivedSync = 'NULL' if data[3] is None else data[3]
            temperature = 'NULL' if data[4] is None else data[4]
            ph = 'NULL' if data[5] is None else data[5]
            oxidationReductionPotential = 'NULL' if data[6] is None else data[6]
            totalDissovedSolids = 'NULL' if data[7] is None else data[7]
            electricConductivity = 'NULL' if data[8] is None else data[8]
            electricResistivity = 'NULL' if data[9] is None else data[9]
            liquidLevel = 'NULL' if data[10] is None else data[10]
            value_string += f"('{ts}', {gatewayId}, '{ieee}', '{receivedSync}', {temperature}, {ph}, {oxidationReductionPotential}, {totalDissovedSolids}, {electricConductivity}, {electricResistivity}, {liquidLevel}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`waterQuality` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"waterQuality Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def dTemperature(gId, from_conn, to_conn, st, et):
    logging.debug(f"Hi dTemperature fumc")
    
    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.dTemperature where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'dTemperature' data for gId: {gId} from {st} to {et}")
            return

        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            temp1 = 'NULL' if data[5] is None else data[5]
            temp2 = 'NULL' if data[6] is None else data[6]
            temp3 = 'NULL' if data[7] is None else data[7]
            temp4 = 'NULL' if data[8] is None else data[8]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {temp1}, {temp2}, {temp3}, {temp4}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`dTemperature` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"dTemperature Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def ain(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi ain func.")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.ain where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'ain' data for gId: {gId} from {st} to {et}")
            return
        
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            randTime = 'NULL' if data[5] is None else data[5]
            ain1 = 'NULL' if data[6] is None else data[6]
            ain2 = 'NULL' if data[7] is None else data[7]
            ain3 = 'NULL' if data[8] is None else data[8]
            ain4 = 'NULL' if data[9] is None else data[9]
            ain5 = 'NULL' if data[10] is None else data[10]
            voltage1 = 'NULL' if data[11] is None else data[11]
            voltage2 = 'NULL' if data[12] is None else data[12]
            voltage3 = 'NULL' if data[13] is None else data[13]
            voltage4 = 'NULL' if data[14] is None else data[14]
            voltage5 = 'NULL' if data[15] is None else data[15]
            value1 = 'NULL' if data[16] is None else data[16]
            value2 = 'NULL' if data[17] is None else data[17]
            value3 = 'NULL' if data[18] is None else data[18]
            value4 = 'NULL' if data[19] is None else data[19]
            value5 = 'NULL' if data[20] is None else data[20]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {randTime}, {ain1}, {ain2}, {ain3}, {ain4}, {ain5}, {voltage1}, {voltage2}, {voltage3}, {voltage4}, {voltage5}, {value1}, {value2}, {value3}, {value4}, {value5}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`ain` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"Ain Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

def flowTMR2RMT(gId, from_conn, to_conn, st, et):
    logging.debug(f"hi flowTMR2RMT func.")

    value_string = ''
    with from_conn.cursor() as data_cursor:
        sqlCommand = f"select * from iotmgmt.flowTMR2RMT where ts>='{st}' and ts<'{et}' and gatewayId={gId} order by ts asc"
        logging.debug(sqlCommand)
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            logging.warning(f"no 'flowTMR2RMT' data for gId: {gId} from {st} to {et}")
            return
        
        for data in data_cursor:
            logging.debug(data)
            ts = data[0]
            gatewayId = data[1]
            linkQuality = 'NULL' if data[2] is None else data[2]
            ieee = 'NULL' if data[3] is None else data[3]
            receivedSync = 'NULL' if data[4] is None else data[4]
            flowInstant = 'NULL' if data[5] is None else data[5]
            flowTotalPositive = 'NULL' if data[6] is None else data[6]
            flowTotalNegative = 'NULL' if data[7] is None else data[7]
            singleRunDay = 'NULL' if data[8] is None else data[8]
            positiveRunDay = 'NULL' if data[9] is None else data[9]
            stopRunDay = 'NULL' if data[10] is None else data[10]
            negativeRunDay = 'NULL' if data[11] is None else data[11]
            magneticRunDay = 'NULL' if data[12] is None else data[12]
            lowPowerRunDay = 'NULL' if data[13] is None else data[13]
            switchTimes = 'NULL' if data[14] is None else data[14]
            value_string += f"('{ts}', {gatewayId}, {linkQuality}, '{ieee}', '{receivedSync}', {flowInstant}, {flowTotalPositive}, {flowTotalNegative}, {singleRunDay}, {positiveRunDay}, {stopRunDay}, {negativeRunDay}, {magneticRunDay}, {lowPowerRunDay}, {switchTimes}), "

    if value_string != '':
        value_string = value_string[:-2]
        with to_conn.cursor() as cursor:
            replace_sql = f"replace into `iotmgmt`.`flowTMR2RMT` Values {value_string}"
            try:
                cursor.execute(replace_sql)
                to_conn.commit()
                logging.info(f"flowTMR2RMT Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[MySQL ERROR]: {str(ex)}")

    return

def main():

    from_conn = connectDB('tc.evercomm.com', 44106)
    to_conn = connectDB('127.0.0.1', 3306)

    et = datetime.now().replace(microsecond=0)
    st = et - timedelta(seconds=30)
    logging.critical(f"----- Processing from {st} to {et} -----")

    clusterIds = pd.read_csv('clusterId.csv')

    for index, rows in clusterIds.iterrows():
        gId = rows['gId']
        code_list = rows['code'].replace(' ','').split(',')

        # code list
        # 8105: 1 > gpio
        # 8150: 2 > pm
        # 8151: 3 > co2
        # 8155: 4 > zigbeeRawModbus
        # 8157: 5 > co2
        # 8158: 6 > ultrasonicFlow2
        # 8162: 7 > waterQuality
        # 8163: 8 > waterQuality
        # 8175: 9 > dTemperature
        # 8200: 10 > ain
        #     : 11 > flowTMR2RMT

        logging.info(f"--- processing GW: {gId} ---")
        for c in code_list:
            if c == '1':
                gpio(gId, from_conn, to_conn, st, et)
            elif c == '2':
                pm(gId, from_conn, to_conn, st, et)
            elif c == '3':
                co2(gId, from_conn, to_conn, st, et)
            elif c == '4':
                zigbeeRawModbus(gId, from_conn, to_conn, st, et)
            elif c == '5':
                co2(gId, from_conn, to_conn, st, et)
            elif c == '6':
                ultrasonicFlow2(gId, from_conn, to_conn, st, et)
            elif c == '7':
                waterQuality(gId, from_conn, to_conn, st, et)
            elif c == '8':
                waterQuality(gId, from_conn, to_conn, st, et)
            elif c == '9':
               dTemperature(gId, from_conn, to_conn, st, et)
            elif c == '10':
                ain(gId, from_conn, to_conn, st, et)
            elif c == '11':
                flowTMR2RMT(gId, from_conn, to_conn, st, et)
            else:
                logging.error(f"[Cluster Id ERROR]: Code:{c} Exception")

    from_conn.close()
    to_conn.close()

if __name__ == '__main__':

    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        vel = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.critical(f"----- Program closes ----- took: {round(time.time() - s, 4)}s")