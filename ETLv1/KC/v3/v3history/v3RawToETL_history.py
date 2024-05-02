import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os
import json
import sys
def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            port = 3306,
            user = 'username',
            passwd = 'password' 
            #read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Error]: {str(ex)}")


def main():

    conn = connectDB('127.0.0.1')
    date = sys.argv[1]
    data =  date.split('-')
    nowTime = datetime.now().replace(year=int(data[0]),month=int(data[1]),day=int(data[2]),hour=0,minute=0,second=0,microsecond=0)
    st = nowTime
    et = nowTime+timedelta(days=1)
    logging.info(f"---- Searching from {st} to {et} ----")
    value_string = ''
    with conn.cursor() as cursor:
        sql = f"SELECT label,name,gatewayId FROM mgmtETL.V3API "
        cursor.execute(sql)
        for row in cursor:
            label = row[0]
            name = row[1]
            gId = row[2]
            with conn.cursor() as data_cursor:
                sqlCommand = f"select APIts,rawdata from rawData.v3API where APIts>='{st}' and APIts<'{et}' and label = '{label}' and gatewayId = '{gId}'  order by APIts asc"
                logging.info(sqlCommand)
                data_cursor.execute(sqlCommand)
                if data_cursor.rowcount == 0:
                    logging.info(f'{row} has no data')
                for data in data_cursor:
                    ts = data[0]
                    rawdata = json.loads(data[1])
                
                    mileage =rawdata['mileage']
                    latitude = rawdata['latitude']
                    longitude = rawdata['longitude']
                    heading = rawdata['heading']
                    headingValue = rawdata['headingValue']
                    validity = rawdata['validity']
                    event = rawdata['event']
                    speed = rawdata['speed']
                    battery_voltage = rawdata['battery_voltage']
                    service_brake_circuit_1_air_pressure = rawdata['service_brake_circuit_1_air_pressure']
                    fuel_level = rawdata['fuel_level']
                    engine_coolant_temperature = rawdata['engine_coolant_temperature']
                    engine_hours = rawdata['engine_hours']
                    rpm = rawdata['rpm']
                    temperature = rawdata['temperature']
                    sec_temperature = rawdata['sec_temperature']
                    main_power_voltage = rawdata['main_power_voltage']
                    value_string += f"('{ts}','{gId}','{name}',{mileage},{latitude},{longitude},'{heading}',{headingValue},'{validity}','{event}',{speed},{battery_voltage},{service_brake_circuit_1_air_pressure},{fuel_level},{engine_coolant_temperature},{engine_hours},{rpm},{temperature},{sec_temperature},{main_power_voltage}), "
                

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into dataETL.car(ts,gatewayId,name,mileage,latitude,longitude,heading,headingValue,validity,event,speed,batteryVoltage,serviceBrakeCircuit1AirPressure,fuelLevel,engineCoolantTemperature,engineHours,rpm,temperature,secTemperature,mainPowerVoltage) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replacement Succeed")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace Error]: {str(ex)}")

if __name__ == '__main__':
    file = __file__
    basename = os.path.basename(file)
    filename = os .path.splitext(basename)[0]
    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
        level = logging.INFO, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()

    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
