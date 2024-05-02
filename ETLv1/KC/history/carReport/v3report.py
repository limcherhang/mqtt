import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler
import os
import json
from dateutil.relativedelta import relativedelta
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
    
    nowTime = datetime.now().replace(hour=0,minute=0,second=0,microsecond=0)
    st = nowTime - timedelta(days=1) 
    et = nowTime 
    
    times = nowTime.strftime("%Y-%m")
    year = nowTime.strftime("%Y")
    month = nowTime.strftime("%m")
    
    logging.info(f"---- Searching from {st} to {et} ----")
    value_string = ''
    value_string_2 = ''
    with conn.cursor() as cursor:
        sql = f"SELECT siteId,name,gatewayId FROM mgmtETL.V3API "
        cursor.execute(sql)
        logging.info(sql)
        for rows in cursor:
            sId = rows[0]
            etlname = rows[1]
            gId = rows[2]
            with conn.cursor() as cursor_1:
                sql_1 = f"SELECT name FROM mgmtETL.NameList where siteId = {sId} and dataETLName = '{etlname}' and gatewayId = {gId}"
                cursor_1.execute(sql_1)
                logging.info(sql_1)
                for s in cursor_1:
                    name = s[0]
                    #Daily
                    
                
                    with conn.cursor() as cursor_2:
                        sql_2 = f"SELECT ts,mileage,distance,fuelConsumption,totalFuelConsumption FROM dataPlatform.car where name = '{name}' and ts >= '{st}' and ts < '{et}' and siteId = {sId} order by ts desc limit 1"
                        cursor_2.execute(sql_2)
                        logging.info(sql_2)
                        if cursor_2.rowcount == 0:
                            continue
                        for row in cursor_2:
                            ts = row[0]
                            mileage = row[1]
                            distance = row[2]
                            fuelConsumption = ('null'if row[3] is None else row[3])
                            totalFuelConsumption =('null' if row[4] is None else row[4]) 
    
                            value_string += f"('{datetime.date(ts)}',{sId},'{name}',{mileage},{distance},{fuelConsumption},{totalFuelConsumption}), "    
                   
                    
        if value_string != '':
            value_string = value_string[:-2]
            with conn.cursor() as cursor:
                replace_sql = f"replace into reportPlatform.Dcar(ts,siteId,name,mileage,distance,fuelConsumption,totalFuelConsumption) Values {value_string}"
                logging.debug(replace_sql)
                print(replace_sql)
                try:
                    cursor.execute(replace_sql)
                    conn.commit()
                    
                    logging.info(f"Replacement Succeed")
                except Exception as ex:
                    logging.error(f"SQL: {replace_sql}")
                    logging.error(f"[Replace Error]: {str(ex)}")

        with conn.cursor() as cursor:
            sql = f"select name, max(mileage),sum(distance),sum(fuelConsumption),sum(totalFuelConsumption) from reportPlatform.Dcar where month(ts) = {month} group by name"
            cursor.execute(sql)
            for Mdata in cursor:
                M_name = Mdata[0]
                M_mileage = Mdata[1]
                M_distance = Mdata[2]
                M_fuelConsumption = ('null'if Mdata[3] is None else Mdata[3])
                M_totalFuelConsumption = ('null' if Mdata[4] is None else Mdata[4]) 
                
                value_string_2 += f"('{times}',{sId},'{M_name}',{M_mileage},{M_distance},{M_fuelConsumption},{M_totalFuelConsumption}), "

            if value_string_2 != '':
                value_string_2 = value_string_2[:-2]

                with conn.cursor() as cursor_1:
                    replace_sql = f"replace into reportPlatform.Mcar(ts,siteId,name,mileage,distance,fuelConsumption,totalFuelConsumption) Values {value_string_2}"
                    cursor_1.execute(replace_sql)
                    logging.info (replace_sql)
            
                    conn.commit()
                    conn.close()
if __name__ == '__main__':
    file = __file__
    basename = os.path.basename(file)
    filename = os .path.splitext(basename)[0]
    logging.basicConfig(
        handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
        level = logging.DEBUG, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    nowTime = datetime.now().replace(microsecond=0)
    logging.info(f"---------- Now: {nowTime} ---------- Program Starts!")

    main()
    
    logging.info(f"--------------- Calculation Done --------------- Took: {round(time.time()-s, 3)}s")
