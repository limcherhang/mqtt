import pymysql
from datetime import datetime, timedelta
import logging
from logging.handlers import TimedRotatingFileHandler
import time

def connectDB(host):
    try:
        conn = pymysql.connect(host=host, read_default_file='~/.my.cnf')
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[Connection Failed]: {str(ex)}")

def cal_powerConsumed(conn, gId, meterId, ts, total):
    global history_flag

    with conn.cursor() as cursor:
        if history_flag:
            sqlCommand = f"select GWts from rawData{ts.year}.RESTAPI_{ts.month:02} where GWts<'{ts}' and gatewayId={gId} and meterId='{meterId}' order by GWts desc limit 1"
        else:
            sqlCommand = f"select GWts from rawData.RESTAPI where GWts<'{ts}' and gatewayId={gId} and meterId='{meterId}' order by GWts desc limit 1"
        cursor.execute(sqlCommand)

        if cursor.rowcount == 0:
            powerConsumed = 0
        else:
            data = cursor.fetchone()
            if data is not None:
                pre_ts = data[0]
                
                powerConsumed = total/round((ts - pre_ts).seconds/3600, 2)

    return powerConsumed*1000

logging.basicConfig(
    handlers = [TimedRotatingFileHandler(f'/home/ecoprog/DATA/API/log/{__file__}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"------------ Now: {nowTime} ------------ Program Started !")

st = (nowTime-timedelta(minutes=18)).replace(second=0)
et = nowTime
#st = datetime(2022, 4, 12)
#et = datetime(2022, 4, 13)
logging.info(f"---------- Processing from {st} to {et} ----------")

if (datetime.now().replace(hour=0, minute=0, second=0) - st).days > 1:
    history_flag = True
else:
    history_flag = False

my_conn = connectDB('127.0.0.1')

meterIds = {
    'Power#1':3359, 'Power#2':3358, 'Power#3':3357, 'Power#4':3356, 'Power#5':104, 'Power#6':107, 'Power#7':1716, 'Power#8':2, 'Power#9':4, 'Power#10':5, 
    'Power#11':6, 'Power#12':8, 'Power#13':9, 'Power#14':108, 'Power#15':110, 'Power#16':194, 'Power#17':193, 'Power#18':195, 'Power#20':197, 
    'Power#21':103, 'Power#22':102, 'Power#23':1, 'Power#24':3, 'Power#25':7, 'Power#26':105, 'Power#27':179, 'Power#28':70, 'Power#29':192, 'Power#30':241, 
    'Power#31':2990, 'Power#32':2992, 'Power#33':3023, 'Power#34':64, 'Power#35':196, 'Power#36':100, 'Power#37':67, 'Power#38':3257, 'Power#39':52, 'Power#40':127, 
    'Power#41':3360, 'Power#42':2991, 'Power#43':69, 'Power#44':378, 'Power#45':71, 'Power#46':254, 'Power#47':1690, 'Power#48':1691, 'Power#49':2989, 'Power#50':215, 
    'Power#51':343, 'Power#52':669, 'Power#53':258, 'Power#54':66, 'Power#55':68, 'Power#56':1689, 'Power#57':48, 'Power#58':40, 'Power#59':42, 'Power#60':44, 
    'Power#61':46, 'Power#62':3361
}

value_string = ''
for name, meterId in meterIds.items():
    ieee = f"170_{name}"
    logging.debug(f"----- Processing {name} {ieee} -----")

    with my_conn.cursor() as my_cursor:
        if history_flag:
            sqlCommand = f"select GWts, gatewayId, Cumulative, Raw from rawData{st.year}.RESTAPI_{st.month:02} where DBts>='{st}' and DBts<'{et}' and meterId='{meterId}' group by GWts"
        else:
            sqlCommand = f"select GWts, gatewayId, Cumulative, Raw from rawData.RESTAPI where DBts>='{st}' and DBts<'{et}' and meterId='{meterId}' group by GWts"
        logging.debug(sqlCommand)
        my_cursor.execute(sqlCommand)

        if my_cursor.rowcount == 0:
            logging.warning(f"{meterId} has no data from {st} to {et}")
            continue
        else:
            for data in my_cursor:
                ts = data[0]
                gId = data[1]
                totalPositiveWattHour = ('NULL' if data[2] is None else float(data[2])*1000)
                total = ('NULL' if data[3] is None else float(data[3]))
                
                if totalPositiveWattHour == 'NULL' and total == 'NULL':
                    continue
                elif total != 'NULL':
                    ch1Watt = cal_powerConsumed(my_conn, gId, meterId, ts, total)
                    ch1Watt = round(ch1Watt,0)

                logging.info(f"({ts}, {gId}, {ieee}, {ch1Watt}, {totalPositiveWattHour})")
                value_string += f"('{ts}', 170, '{ieee}', '{ts}', {ch1Watt}, {totalPositiveWattHour}), "

if value_string != '':
    value_string = value_string[:-2]
    with my_conn.cursor() as my_cursor:
        insert_sql = f"insert into `iotmgmt`.`pm` (`ts`, `gatewayId`, `ieee`, `receivedSync`, `ch1Watt`, `totalPositiveWattHour`) Values {value_string}"
        try:
            my_cursor.execute(insert_sql)
            my_conn.commit()
        except Exception as ex:
            logging.error(f"SQL: {insert_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")
        finally:
            my_conn.close()

logging.info(f"------------ Connection Closed ------------ took: {round((time.time() - s), 3)}s")