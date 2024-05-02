import pymysql
import subprocess
import sys
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import threading
import time
import struct
import math

def connectDB(host):
    while 1: 
        try:
            conn = pymysql.connect(host=host, read_default_file='~/.my.cnf')
            logging.debug(f"IP: {host} Connection Succeed !")
            return conn
        except:
            logging.error(f"[{host} Connection ERROR]: Waiting 5 seconds and automatically reconnect again")
            time.sleep((5*1000000 - datetime.now().microsecond) / 1000000)

def is_connected(conn, sql, flag):
    s_reconnect = time.time()
    cnt = 0
    while 1:
        cnt += 1
        if cnt % 10 == 1:
            s = 'st'
        elif cnt % 10 == 2:
            s = 'nd'
        else:
            s = 'th'
        try:
            logging.error(f"[{cnt}{s} time]: Connection Lost ! Reconnecting...")
            conn.ping(reconnect=True)
            break
        except:
            logging.error(f"Waiting 5 seconds and automatically reconnect again")
            time.sleep((5*1000000 - datetime.now().microsecond) / 1000000)
    logging.error(f"[Reconnection Succeed]: Took: {round(time.time()-s_reconnect, 2)}s")

    if not flag: return

    with conn.cursor() as cursor:
        try:
            cursor.execute(sql)
            conn.commit()
            logging.info(f"Insert Succeed ! at is_connected func. at {datetime.datetime.now().replace(microsecond=0)}")
        except Exception as ex:
            logging.error(f"SQL: {sql}")
            logging.error(f"[MySQL Insert ERROR]: {str(ex)}")

class zigbee():
    
    def hex2dec(value):
        return int(value, 16) 
    
    def signChecked(value):
        if int(value[0], 16) > 7:
            return int(value, 16) - int('f' * len(value), 16)
        else:
            return int(value, 16)

    def getValue(conn, ieee, ain_list, voltage_list, index=4):
        ainValue_string = ''

        for i in range(index):
            ainValue = 0
            ain = ain_list[i]
            voltage = voltage_list[i]
            with conn.cursor() as cursor:
                sqlCommand = f"\
                    SELECT DISTINCT af.k, af.rg, af.vt, af.it, af.k0, af.k1, af.k2, af.k3, af.k4, af.voltageMin, af.voltageMax, af.valueMin, af.valueMax \
                    FROM iotmgmt.TDevice d \
                    INNER JOIN iotmgmt.TDeviceType dt ON dt.id = d.deviceTypeId \
                    INNER JOIN iotmgmt.TAinFormula af ON af.id = dt.ainFormulaId{i} \
                    WHERE d.ieee = '{ieee}' AND d.deleteFlag = 0; \
                    "
                cursor.execute(sqlCommand)
                
                if cursor.rowcount != 0:
                    for rows in cursor:
                        logging.debug(rows)

                        k = rows[0]
                        rg = rows[1]
                        vt = rows[2]
                        it = rows[3]
                        k0 = rows[4]
                        k1 = rows[5]
                        k2 = rows[6]
                        k3 = rows[7]
                        k4 = rows[8]
                        voltageMin = rows[9]
                        voltageMax = rows[10]
                        valueMin = rows[11]
                        valueMax = rows[12]
                        #公式
                        if k !=0 and rg !=0:
                            if voltage == 0:
                                ainValue = voltage - 273.13 # 0 - 273.13 = -273.13
                            else:
                                R = rg * (3.3 - voltage) / voltage
                                if R <= 0:
                                    ainValue = 'NULL'
                                else:
                                    C = math.log(R / 10000) / k + (1 / 298.13)
                                    ainValue = 1 / C - 273.13
                        elif vt != 0:
                            ainValue = voltage * vt
                        elif it != 0:
                            ainValue = voltage * it
                        elif k0 == 0 and k1 == 0 and k2 == 0 and k3 == 0 and k4 == 0:
                            if voltage <= voltageMin:
                                ainValue = voltageMin
                            elif voltage >= voltageMax:
                                ainValue = voltageMax
                            else:
                                ainValue = (voltage - voltageMin) / (voltageMax - voltageMin) * (valueMax - valueMin) + valueMin
                        else:
                            ainValue = k0 + k1 * ain + k2 * ain ** 2 + k3 * ain ** 3 + k4 * ain ** 4

            ainValue_string += f"{ainValue}, "
        
        return ainValue_string[:-2]

    def sql8105(rawdata):
        try:
            pin0 = zigbee.hex2dec(rawdata[0:2])
            pin1 = zigbee.hex2dec(rawdata[2:4])
            pin2 = zigbee.hex2dec(rawdata[4:6])
            pin3 = zigbee.hex2dec(rawdata[6:8])
            pin4 = zigbee.hex2dec(rawdata[8:10])
            pin5 = zigbee.hex2dec(rawdata[10:12])
            pin6 = zigbee.hex2dec(rawdata[12:14])
            pin7 = zigbee.hex2dec(rawdata[14:16])

            return f"{pin0}, {pin1}, {pin2}, {pin3}, {pin4}, {pin5}, {pin6}, {pin7}"
        except Exception as ex:
            #logging.error(f"[8150 Parsing Error]: {str(ex)}")
            logging.error(f"[8105 Parsing Error]: {str(ex)}")

    def sql8150(rawdata):
        try:
            ch1Watt = zigbee.signChecked(rawdata[0:8])
            ch2Watt = zigbee.signChecked(rawdata[8:16])
            ch3Watt = zigbee.signChecked(rawdata[16:24])
            totalPositiveWattHour = zigbee.signChecked(rawdata[24:32]) * 100
            totalNegativeWattHour = zigbee.signChecked(rawdata[32:40]) * 100
            ch1Current = zigbee.signChecked(rawdata[40:44]) / 10
            ch2Current = zigbee.signChecked(rawdata[44:48]) / 10
            ch3Current = zigbee.signChecked(rawdata[48:52]) / 10
            ch1Voltage = zigbee.signChecked(rawdata[52:56]) / 10
            ch2Voltage = zigbee.signChecked(rawdata[56:60]) / 10
            ch3Voltage = zigbee.signChecked(rawdata[60:64]) / 10
            ch1PowerFactor = zigbee.signChecked(rawdata[64:68]) / 1000
            ch2PowerFactor = zigbee.signChecked(rawdata[68:72]) / 1000
            ch3PowerFactor = zigbee.signChecked(rawdata[72:76]) / 1000
            voltage12 = zigbee.signChecked(rawdata[76:80]) / 10
            voltage23 = zigbee.signChecked(rawdata[80:84]) / 10
            voltage31 = zigbee.signChecked(rawdata[84:88]) / 10
            ch1Hz = zigbee.signChecked(rawdata[88:92]) / 100
            ch2Hz = zigbee.signChecked(rawdata[92:96]) / 100
            ch3Hz = zigbee.signChecked(rawdata[96:100]) / 100
            i1THD = zigbee.signChecked(rawdata[100:104]) / 10
            i2THD = zigbee.signChecked(rawdata[104:108]) / 10
            i3THD = zigbee.signChecked(rawdata[108:112]) / 10
            v1THD = zigbee.signChecked(rawdata[112:116]) / 10
            v2THD = zigbee.signChecked(rawdata[116:120]) / 10
            v3THD = zigbee.signChecked(rawdata[120:124]) / 10

            return f"{ch1Watt}, {ch2Watt}, {ch3Watt}, {totalPositiveWattHour}, {totalNegativeWattHour}, {ch1Current}, {ch2Current}, {ch3Current}, {ch1Voltage}, {ch2Voltage}, {ch3Voltage}, {ch1PowerFactor}, {ch2PowerFactor}, {ch3PowerFactor}, {voltage12}, {voltage23}, {voltage31}, {ch1Hz}, {ch2Hz}, {ch3Hz}, {i1THD}, {i2THD}, {i3THD}, {v1THD}, {v2THD}, {v3THD}"
        except Exception as ex:
            logging.error(f"[8150 Parsing Error]: {str(ex)}")

    def sql8151(rawdata):
        try:
            co2ppm = zigbee.hex2dec(rawdata[0:4]) 
            temp = zigbee.hex2dec(rawdata[4:8]) / 10
            humidity = zigbee.hex2dec(rawdata[8:12]) / 10

            return f"{co2ppm}, {temp}, {humidity}"
        except Exception as ex:
            logging.error(f"[8151 Parsing Error]: {str(ex)}")

    def sql8154(rawdata):
        try:
            voltage = zigbee.hex2dec(rawdata[2:4] + rawdata[0:2]) / 100
            temp = struct.unpack('!f', bytes.fromhex(rawdata[4:12]))[0]
            humid = zigbee.hex2dec(rawdata[14:16] + rawdata[12:14]) / 100
            co2 = zigbee.hex2dec(rawdata[18:20] + rawdata[16:18])

            return f"{voltage}, {temp}, {humid}, {co2}"
        except Exception as ex:
            logging.error(f"[8154 Parsing Error]: {str(ex)}")

    def sql8155(rawdata):
        try:
            modbusCmd = rawdata[0:16]
            repsonseData = rawdata[16:]

            return f"'{modbusCmd}', '{repsonseData}'"
        except Exception as ex:
            logging.error(f"[8155 Parsing Error]: {str(ex)}")

    def sql8156(rawdata):
        try:
            temp1 = struct.unpack('!f', bytes.fromhex(rawdata[0:8]))[0]
            temp2 = struct.unpack('!f', bytes.fromhex(rawdata[8:16]))[0]
            temp3 = struct.unpack('!f', bytes.fromhex(rawdata[16:24]))[0]
            temp4 = struct.unpack('!f', bytes.fromhex(rawdata[24:32]))[0]

            return f"{temp1}, {temp2}, {temp3}, {temp4}"
        except Exception as ex:
            logging.error(f"[8156 Parsing Error]: {str(ex)}")

    def sql8157(rawdata):
        try:
            temp = struct.unpack('!f', bytes.fromhex(rawdata[:8]))[0]
            humidity = struct.unpack('!f', bytes.fromhex(rawdata[8:16]))[0]

            return f"{temp}, {humidity}"
        except Exception as ex:
            logging.error(f"[8157 Parsing Error]: {str(ex)}")

    def sql8158(rawdata):
        try:
            flowRate = struct.unpack('!f', bytes.fromhex(rawdata[0:8]))[0]
            velocity = struct.unpack('!f', bytes.fromhex(rawdata[8:16]))[0]
            netAccumulator = zigbee.hex2dec(rawdata[16:24])
            temp1Inlet = struct.unpack('!f', bytes.fromhex(rawdata[24:32]))[0]
            temp2Outlet = struct.unpack('!f', bytes.fromhex(rawdata[32:40]))[0]
            errorCode = rawdata[40:44]
            signalQuality = zigbee.hex2dec(rawdata[44:48])
            upstreamStrength = zigbee.hex2dec(rawdata[48:52])
            downstreamStrength = zigbee.hex2dec(rawdata[52:56])
            calcRateMeasTravelTime = struct.unpack('!f', bytes.fromhex(rawdata[56:64]))[0]
            reynoldsNumber = struct.unpack('!f', bytes.fromhex(rawdata[64:72]))[0]
            pipeReynoldsFactor = struct.unpack('!f', bytes.fromhex(rawdata[72:80]))[0]
            totalWorkingTime = zigbee.hex2dec(rawdata[80:88])
            totalPowerOnOffTime = zigbee.hex2dec(rawdata[80:96])

            return f"{flowRate}, {velocity}, {netAccumulator}, {temp1Inlet}, {temp2Outlet}, {errorCode}, {signalQuality}, {upstreamStrength}, {downstreamStrength}, {calcRateMeasTravelTime}, {reynoldsNumber}, {pipeReynoldsFactor}, {totalWorkingTime}, {totalPowerOnOffTime}"
        except Exception as ex:
            logging.error(f"[8158 Parsing Error]: {str(ex)}")

    def sql8159(rawdata):
        try:
            Temperature = []
            dcVoltage = []
            dcCurrent = []
            mpptPower = []
            groundResistance = []
            errorCode = ''
            totalCnt = 0

            dailyKWh = zigbee.hex2dec(rawdata[0:8]) / 10
            dailyOperationMinute = zigbee.hex2dec(rawdata[8:16]) / 10
            monthlyKWh = zigbee.hex2dec(rawdata[16:24]) / 10
            lifeTimeKWh = zigbee.hex2dec(rawdata[24:32]) / 10
            lifeTimeHour = zigbee.hex2dec(rawdata[32:40])

            # Temperature handle: data length & data
            tempCnt = zigbee.hex2dec(rawdata[40:42])
            for i in range(tempCnt):
                Temperature.append(zigbee.hex2dec(rawdata[42 + i*4 : 46 + i*4]) / 10)
            totalCnt += tempCnt *4
            
            # dcVoltage handle: data length & data
            dcVoltageCnt = zigbee.hex2dec(rawdata[42+totalCnt : 44+totalCnt])
            for i in range(dcVoltageCnt):
                dcVoltage.append(zigbee.hex2dec(rawdata[44 + totalCnt + i*4 : 48 + totalCnt + i*4]) / 10)
            totalCnt += dcVoltageCnt * 4
            
            # dcCurrent handle: data length & data
            dcCurrentCnt = zigbee.hex2dec(rawdata[44+totalCnt : 46+totalCnt])
            for i in range(dcCurrentCnt):
                dcCurrent.append(zigbee.hex2dec(rawdata[46 + totalCnt + i*4 : 50 + totalCnt + i*4]) / 100)
            totalCnt += dcCurrentCnt * 4

            dcPower = zigbee.hex2dec(rawdata[46 + totalCnt : 54 + totalCnt])

            # mpptPower handle: data length & data
            mpptPowerCnt = zigbee.hex2dec(rawdata[54 + totalCnt : 56 + totalCnt])
            for i in range(mpptPowerCnt):
                mpptPower.append(zigbee.hex2dec(rawdata[56 + totalCnt + i*8 : 64 + totalCnt + i*8]))
            totalCnt += mpptPowerCnt * 8

            acVoltageA = zigbee.hex2dec(rawdata[56 + totalCnt : 60 + totalCnt]) / 10
            acVoltageB = zigbee.hex2dec(rawdata[60 + totalCnt : 64 + totalCnt]) / 10
            acVoltageC = zigbee.hex2dec(rawdata[64 + totalCnt : 68 + totalCnt]) / 10
            acCurrentA = zigbee.hex2dec(rawdata[68 + totalCnt : 72 + totalCnt]) / 10
            acCurrentB = zigbee.hex2dec(rawdata[72 + totalCnt : 76 + totalCnt]) / 10
            acCurrentC = zigbee.hex2dec(rawdata[76 + totalCnt : 80 + totalCnt]) / 10
            apparentPower = zigbee.hex2dec(rawdata[80 + totalCnt : 88 + totalCnt])
            acPower = zigbee.hex2dec(rawdata[88 + totalCnt : 96 + totalCnt])
            reactivePower = zigbee.hex2dec(rawdata[96 + totalCnt : 104 + totalCnt])
            pf = zigbee.hex2dec(rawdata[104 + totalCnt : 108 + totalCnt])
            gridFrequency = zigbee.hex2dec(rawdata[108 + totalCnt : 112 + totalCnt]) / 100

            # groundResistance handle: data length & data
            groundResistanceCnt = zigbee.hex2dec(rawdata[112 + totalCnt : 114 + totalCnt])
            for i in range(groundResistanceCnt):
                groundResistance.append(zigbee.hex2dec(rawdata[114 + totalCnt + i*4 : 118 + totalCnt + i*4]))
            totalCnt += groundResistanceCnt * 4

            leakageCurrent = zigbee.hex2dec(rawdata[114 + totalCnt : 118 + totalCnt])
            operationState = zigbee.hex2dec(rawdata[118 + totalCnt : 122 + totalCnt])

            # errorCode handle: data length & data
            errorCodeCnt = zigbee.hex2dec(rawdata[122 + totalCnt : 124 + totalCnt])
            for i in range(errorCodeCnt):
                code = rawdata[124 + totalCnt + i*4 : 128 + totalCnt + i*4]
                if code != '0000':
                    errorCode += "\"" + code + "\", "
                else:
                    errorCode += "\"0\", "

            return f"{dailyKWh}, {dailyOperationMinute}, {monthlyKWh}, {lifeTimeKWh}, {lifeTimeHour}, '{Temperature}', '{dcVoltage}', '{dcCurrent}', {dcPower}, '{mpptPower}', {acVoltageA}, {acVoltageB}, {acVoltageC}, {acCurrentA}, {acCurrentB}, {acCurrentC}, {apparentPower}, {acPower}, {reactivePower}, {pf}, {gridFrequency}, '{groundResistance}', {leakageCurrent}, {operationState}, '[{errorCode[:-2]}]'"
        except Exception as ex:
            logging.error(f"[8159 Parsing Error]: {str(ex)}")

    def sql8162(rawdata):
        try:
            electricConductivity = zigbee.hex2dec(rawdata[0:8]) / 100
            temperature = zigbee.hex2dec(rawdata[8:12]) / 10
            totalDissovedSolids = zigbee.hex2dec(rawdata[12:20]) / 100
            electricResistivity = zigbee.hex2dec(rawdata[20:28]) / 100

            return f"{temperature}, {totalDissovedSolids}, {electricConductivity}, {electricResistivity}"
        except Exception as ex:
            logging.error(f"[8162 Parsing Error]: {str(ex)}")

    def sql8163(rawdata):
        try:
            ph = zigbee.hex2dec(rawdata[0:4]) / 100
            temperature = zigbee.hex2dec(rawdata[4:8]) / 10
            oxidationReductionPotential = zigbee.hex2dec(rawdata[8:12])

            return f"{temperature}, {ph}, {oxidationReductionPotential}"
        except Exception as ex:
            logging.error(f"[8163 Parsing Error]: {str(ex)}")
    
    def sql8175(rawdata):
        try:
            temp2 = zigbee.hex2dec(rawdata[0:4])
            temp3 = zigbee.hex2dec(rawdata[5:8]) / 100
            if rawdata[4:5] == '0':
                temp3 *= -1
            temp1 = temp2 / 64 - 256 + temp3

            return f"{temp1}, {temp2}, {temp3}"
        except Exception as ex:
            logging.error(f"[8175 Parsing Error]: {str(ex)}")

    def sql8200(conn, ieee, rawdata):
        try:
            idk =zigbee.hex2dec(rawdata[0:4])

            ain1 = zigbee.hex2dec(rawdata[6:8] + rawdata[4:6]) * 4
            ain2 = zigbee.hex2dec(rawdata[10:12] + rawdata[8:10]) * 4
            ain3 = zigbee.hex2dec(rawdata[14:16] + rawdata[12:14]) * 4
            ain4 = zigbee.hex2dec(rawdata[18:20] + rawdata[16:18]) * 4

            voltage1 = float(ain1 / 32768 * 3.3)
            voltage2 = float(ain2 / 32768 * 3.3)
            voltage3 = float(ain3 / 32768 * 3.3)
            voltage4 = float(ain4 / 32768 * 3.3)

            ain_list = [ain1, ain2, ain3, ain4]
            voltage_list = [voltage1, voltage2, voltage3, voltage4]

            ainValue_string = zigbee.getValue(conn, ieee, ain_list, voltage_list)
            
            return f"{ain1}, {ain2}, {ain3}, {ain4}, {voltage1}, {voltage2}, {voltage3}, {voltage4}, {ainValue_string}"
        except Exception as ex:
            logging.error(f"[8200 Parsing Error]: {str(ex)}")

    def sql8201(rawdata):
        try:
            ain1 = zigbee.hex2dec(rawdata[2:4] + rawdata[0:2]) * 4
            ain2 = zigbee.hex2dec(rawdata[6:8] + rawdata[4:6]) * 4
            ain3 = zigbee.hex2dec(rawdata[10:12] + rawdata[8:10]) * 4
            ain4 = zigbee.hex2dec(rawdata[14:16] + rawdata[12:14]) * 4
            voltage1 = zigbee.hex2dec(rawdata[16:20]) / 100
            voltage2 = zigbee.hex2dec(rawdata[20:24]) / 100
            voltage3 = zigbee.hex2dec(rawdata[24:28]) / 100
            voltage4 = zigbee.hex2dec(rawdata[28:32]) / 100

            return f"{ain1}, {ain2}, {ain3}, {ain4}, {voltage1}, {voltage2}, {voltage3}, {voltage4}"
        except Exception as ex:
            logging.error(f"[8201 Parsing Error]: {str(ex)}")

    def main(cId, sql):
        logging.info(f"Current clusterId: {cId}")

        conn = connectDB('127.0.0.1')
        #prodConn_141 = connectDB('192.168.1.41') 

        cnt = 0
        while 1:
            s = time.time()
            et = datetime.now().replace(microsecond=0)
            st = et - timedelta(seconds=10)

            logging.info(f"----- Processing from {st} to {et} -----")

            value_string = ''
            with conn.cursor() as data_cursor:
                sqlCommand = f"select ZBts, gatewayId, ieee, rawdata from rawData.ZB where DBts>='{st}' and DBts<'{et}' and clusterId='{cId}'"
                try:
                    logging.debug(sqlCommand)
                    data_cursor.execute(sqlCommand)
                except pymysql.OperationalError as ex:
                    if ex.args[0] == 2013 or ex.args[0] == 2003:
                        is_connected(conn, sqlCommand, False)
                    continue
                except Exception as ex:
                    logging.error(f"[Select ERROR]: {str(ex)}")
                    continue
            
                if data_cursor.rowcount == 0:
                    logging.warning(f"There is no data from {st} to {et}")
                    conn.rollback()
                else:
                    logging.info(f"data rows: {data_cursor.rowcount}")
                    for data in data_cursor:
                        try:
                            receivedSync = ('NULL' if data[0].year == 1970 else '\'' + datetime.strftime(data[0], '%Y-%m-%d %H:%M:%S') + '\'')
                            gId = data[1]
                            ieee = data[2]
                            rawdata = data[3]

                            if cId == '8105':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8105(rawdata)}), "
                            elif cId == '8150':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8150(rawdata)}), "
                            elif cId == '8151':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8151(rawdata)}), "
                            elif cId == '8154':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8154(rawdata)}), "
                            elif cId == '8155':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8155(rawdata)}), "
                            elif cId == '8156':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8156(rawdata)}), "
                            elif cId == '8157':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8157(rawdata)}), "
                            elif cId == '8158':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8158(rawdata)}), "
                            elif cId == '8159':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8159(rawdata)}), "
                            elif cId == '8162':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8162(rawdata)}), "
                            elif cId == '8163':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8163(rawdata)}), "
                            elif cId == '8175':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8175(rawdata)}), "
                            #elif cId == '8200':
                            #    value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8200(prodConn_141, ieee, rawdata)}), "
                            elif cId == '8201':
                                value_string += f"('{datetime.now().replace(microsecond=0)}', {gId}, '{ieee}', {receivedSync}, {zigbee.sql8201(rawdata)}), "
                            
                        except Exception as ex:
                            logging.error(f"[Parsing ERROR]: {str(ex)}")
                    else:
                        conn.rollback()

            if value_string != '':
                value_string = value_string[:-2]
                with conn.cursor() as cursor:
                    insert_sql = sql + value_string
                    logging.debug(insert_sql)
                    try:
                        cursor.execute(insert_sql)
                        conn.commit()
                        logging.debug(f"Insert Succeed!")
                    except pymysql.OperationalError as ex:
                        if ex.args[0] == 2013 or ex.args[0] == 2003: # 2013: 'lost connection during query', 2003: 'Can't connect to MySQL server'
                            logging.error(f"[MySQL Connection ERROR]: {str(ex)}")
                            is_connected(conn, insert_sql, True)
                        else:
                            logging.error(f"SQL: {insert_sql}")
                            logging.error(f"[MySQL Insert ERROR]: {str(ex)}")
                            conn.rollback()
                    except pymysql.err.InterfaceError as ex:
                        if ex.args[0] == 0:
                            logging.error(f"[MySQL Connection ERROR]: {str(ex)}")
                            is_connected(conn, insert_sql, True)
                    except Exception as ex:
                        logging.error(f"SQL: {insert_sql}")
                        logging.error(f"[Other ERROR]: {str(ex)}")
                        conn.rollback()

            logging.info(f"----- Round Took: {round(time.time()-s, 3)}s")
            try:
                #logging.info(f"---------- Sleep:{(10*1000000 - (datetime.now().microsecond+ (datetime.now().second-nowTime.second)*1000000 )) / 1000000}s")
                #time.sleep((10*1000000 - (datetime.now().microsecond+ (datetime.now().second-nowTime.second)*1000000 )) / 1000000)
                logging.info(f"---------- Sleep: {round(10 - (time.time() - s), 3)}s")
                time.sleep(10 - round(time.time() - s, 3))
            except:
                logging.error(f"SQL: {sqlCommand}")
                logging.error(f"{cId} Execution time is over-time ! (Took: {round(time.time()-s, 3)}s during {st} - {et})")

        conn.close()
        #prodConn_141.close()

if __name__ == '__main__':

    # Checking whether it's running
    processIds = subprocess.check_output(
        f"ps -fC python3 | awk '{{print $9}}'",
        shell = True, 
        encoding = 'utf-8'
    ).split('\n')

    id_cnt = 0
    for id in processIds:
        if id == __file__:
            id_cnt += 1
        if id_cnt>1:
            sys.exit(f"[Program Execution Failed]: {__file__} is running right now !")

    # log file setting
    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.ERROR, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    logging.critical(f"Now: {datetime.now().replace(microsecond=0)} Program Start!")

    clusterIds_list = ['8105' ,'8150' ,'8151' ,'8154' ,'8155' ,'8156' ,'8157' ,'8158' ,'8159' ,'8162' ,'8163' ,'8175', '8201'] # ['8200']
    #clusterIds_list = ['8200']
    for index, cId in enumerate(clusterIds_list):
        
        if cId == '8105':
            insert_sql = f"insert into iotmgmt.gpio (`ts`, `gatewayId`, `ieee`, `receivedSync`, `pin0`, `pin1`, `pin2`, `pin3`, `pin4`, `pin5`, `pin6`, `pin7`) Values "
        elif cId == '8150':
            insert_sql = f"insert into iotmgmt.pm (`ts`, `gatewayId`, `ieee`, `receivedSync`, `ch1Watt`, `ch2Watt`, `ch3Watt`, `totalPositiveWattHour`, `totalNegativeWattHour`, `ch1Current`, `ch2Current`, `ch3Current`, `ch1Voltage`, `ch2Voltage`, `ch3Voltage`, `ch1PowerFactor`, `ch2PowerFactor`, `ch3PowerFactor`, `voltage12`, `voltage23`, `voltage31`, `ch1Hz`, `ch2Hz`, `ch3Hz`, `i1THD`, `i2THD`, `i3THD`, `v1THD`, `v2THD`, `v3THD`) Values "
        elif cId == '8151':
            insert_sql = f"insert into iotmgmt.co2 (`ts`, `gatewayId`, `ieee`, `receivedSync`, `co2ppm`, `temp`, `humidity`) Values "
        elif cId == '8154':
            insert_sql = f"insert into iotmgmt.batTempHumidCo2 (`ts`, `gatewayId`, `ieee`, `receivedSync`, `voltage`, `temp`, `humid`, `co2`) Values "
        elif cId == '8155':
            insert_sql = f"insert into iotmgmt.zigbeeRawModbus (`ts`, `gatewayId`, `ieee`, `receivedSync`, `modbusCmd`, `responseData`) Values "
        elif cId == '8156':
            insert_sql = f"insert into iotmgmt.dTemperature (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temp1`, `temp2`, `temp3`, `temp4`) Values "
        elif cId == '8157':
            insert_sql = f"insert into iotmgmt.co2 (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temp`, `humidity`) Values "
        elif cId == '8158':
            insert_sql = f"insert into iotmgmt.ultrasonicFlow2 (`ts`, `gatewayId`, `ieee`, `receivedSync`, `flowRate`, `velocity`, `netAccumulator`, `temp1Inlet`, `temp2Outlet`, `errorCode`, `signalQuality`, `upstreamStrength`, `downstreamStrength`, `calcRateMeasTravelTime`, `reynoldsNumber`, `pipeReynoldsFactor`, `totalWorkingTime`, `totalPowerOnOffTime`) Values "
        elif cId == '8159':
            insert_sql = f"insert into iotmgmt.solarInverter2 (`ts`, `gatewayId`, `ieee`, `receivedSync`, `dailyKWh`, `dailyOperationMinute`, `monthlyKWh`, `lifeTimeKWh`, `lifeTimeHour`, `Temperature`, `dcVoltage`, `dcCurrent`, `dcPower`, `mpptPower`, `acVoltageA`, `acVoltageB`, `acVoltageC`, `acCurrentA`, `acCurrentB`, `acCurrentC`, `apparentPower`, `acPower`, `reactivePower`, `pf`, `gridFrequency`, `groundResistance`, `leakageCurrent`, `operationState`, `errorCode`) Values "
        elif cId == '8162':
            insert_sql = f"insert into iotmgmt.waterQuality (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temperature`, `totalDissovedSolids`, `electricConductivity`, `electricResistivity`) Values"
        elif cId == '8163':
            insert_sql = f"insert into iotmgmt.waterQuality (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temperature`, `ph`, `oxidationReductionPotential`) Values"
        elif cId == '8175':
            insert_sql = f"insert into iotmgmt.dTemperature (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temp1`, `temp2`, `temp3`) Values "
        #elif cId == '8200':
        #    insert_sql = f"insert into iotmgmt.ain (`ts`, `gatewayId`, `ieee`, `receivedSync`, `ain1`, `ain2`, `ain3`, `ain4`, `voltage1`, `voltage2`, `voltage3`, `voltage4`, `value1`, `value2`, `value3`, `value4`) Values "
        elif cId == '8201':
            insert_sql = f"insert into iotmgmt.ain (`ts`, `gatewayId`, `ieee`, `receivedSync`, `ain1`, `ain2`, `ain3`, `ain4`, `voltage1`, `voltage2`, `voltage3`, `voltage4`) Values "
        #同步執行緒
        tCId =threading.Thread(target=zigbee.main, args=(cId, insert_sql)).start()
