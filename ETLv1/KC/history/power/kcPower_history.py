import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import os
import re
import sys
def connectDB(host, username, password):
    try:
        conn = pymysql.connect(
            host=host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")

def getlevel(conn):
    with conn.cursor() as cursor:
        sqlCommand = f"SELECT distinct level FROM mgmtETL.Calculation  order by level desc limit 1"
        logging.debug(sqlCommand)
        cursor.execute(sqlCommand)
        if cursor.rowcount == 0:
            logging.warning(f"power has no mapping info")
        for rows in cursor:
            level = rows[0]
    return level

def execute_insert(conn, year,value_string):
    with conn.cursor() as cursor:
        replace_sql = f"REPLACE INTO dataPlatform2023.power_07(ts, siteId, name, powerConsumed, energyConsumed) VALUES {value_string}"
        try:
            cursor.execute(replace_sql)
            print(replace_sql)
            logging.info(replace_sql)
        except Exception as ex:
            logging.error(f"SQL: {replace_sql}")
            logging.error(f"[Replace ERROR]: {str(ex)}")



def main():
    file = __file__
    basename = os.path.basename(file)
    filename = os.path.splitext(basename)[0]
    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')],
        level=logging.INFO,
        format='%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

   
    date = sys.argv[1]
    data =  date.split('-')
    year = int(data[0])
    nowTime = datetime.now().replace(year,month=int(data[1]),day=int(data[2]),hour=0,minute=0,second=0,microsecond=0)

    logging.info(f"---------- now: {nowTime} ----------")
    st = nowTime 
    et = nowTime + timedelta(days=1)
    
    if et > datetime.now():
        et = datetime.now().replace (second=0,microsecond=0)
    logging.info(f"----- Searching from {st} to {et} -----")
    conn = connectDB('127.0.0.1', 'username', 'password')
    num = getlevel(conn)
    for level in range(num+1):
        value_string = ''
        with conn.cursor() as cursor:
            sqlCommand = f"SELECT siteId, name, calculation, tsSource FROM mgmtETL.Calculation WHERE level = {level}"
            logging.debug(sqlCommand)
            cursor.execute(sqlCommand)
            for rows in cursor:
                sId = rows[0]
                names = rows[1]
                result1 = rows[2]
                result2 = rows[2]
                result_0 = rows[2]
                main = rows[3]
                result = []
                result_list = ''
                
                if 'to' in result1.lower():
                    a = ([int(s) for s in re.findall(r'-?\d+\.?\d*', result1)])
                    b = result1[0:result1.find(str(a[0]))]
                    result3 = ''.join(f"{b}{i}+" for i in range(a[0], a[1] + 1))[:-1]
                    result1 = result3
                    result2 = result3

                result = (([str(s) for s in re.findall(r'power#\d+', result1)]))
                
                
                for row in result:
                    result_list += f"'{row}', "
                result_list = result_list[:-2]

                start = st
                #endtime = et
                with conn.cursor() as cursor:

                    sql = f"select ts from dataPlatform2023.power_07 where siteId = {sId} and name = '{main}' and  ts > '{st}' and ts < '{et}' order by ts asc"
                    cursor.execute(sql)

                    for time in cursor:
                        time = time[0]
                        ts_list = []
                        with conn.cursor() as cursor:
                            sqlCommand = f"""SELECT ts,name, powerConsumed, energyConsumed FROM dataPlatform2023.power_07
                                            WHERE siteId = {sId} AND name in ({result_list}) AND ts > '{start}' and ts <= '{time}' 
                                            order by ts desc
                                            """
                            #asc (舊的一筆) #desc(最新一筆)
                            cursor.execute(sqlCommand)
                            logging.info(sqlCommand)
                            
                            if cursor.rowcount == 0:
                                logging.error(f"'{start}' has no data")
                                break
                            else:
                                for data in cursor:
                                    ts = data[0]
                                    ts_list.append(ts)
                                    name = data[1].lower()
                                    power = data[2]
                                    energy = data[3]
                                    pattern = fr"(?<!\w){name}+(?!\d)"
                                    
                                    result1 = re.sub(pattern, str(power), result1)
                                    result2 = re.sub(pattern, str(energy), result2) 
                                    
                            start = time

                            try:
                                if 'power' in result1:
                                    result1 = result_0
                                    result2 = result_0
                                    continue
                                else:
                                    powerC = round(eval(result1), 2)
                                    energyC = round(eval(result2), 2)
                                    value_string += f"('{ts_list[0]}', '{sId}', '{names}', {powerC}, {energyC}), "
                                    result1 = result_0
                                    result2 = result_0
                            except ZeroDivisionError:
                                if power == 0:
                                    powerC = 0
                                if energy == 0:
                                    energyC = 0                   

        if value_string != '':
            value_string = value_string[:-2]
            execute_insert(conn,year,value_string)
    conn.commit()
    logging.info(f"----- Connection Commit -----")
    conn.close()
    logging.info(f"----- Connection Closed ----- ")

if __name__ == '__main__':
    main()
