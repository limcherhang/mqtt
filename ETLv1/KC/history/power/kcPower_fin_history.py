import time
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

def main():
    

    conn = connectDB('127.0.0.1', 'username', 'password')
    num = getlevel(conn)
    for level in range(1,num+1):
        value_string = ''
        with conn.cursor() as cursor:
            sqlCommand = f"SELECT siteId, name, calculation FROM mgmtETL.Calculation WHERE level = {level}"
            logging.debug(sqlCommand)
            cursor.execute(sqlCommand)
            for rows in cursor:
                sId = rows[0]
                names = rows[1]
                result1 = rows[2]
                result2 = rows[2]
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
                ts_list = []
                with conn.cursor() as cursor:
                    sqlCommand = f"""SELECT ts,name, powerConsumed, energyConsumed 
                                    FROM dataPlatform{y}.power{mon}
                                    WHERE siteId = {sId} AND name in ({result_list}) AND ts >= '{st}' and ts < '{et}' order by ts desc """
                    cursor.execute(sqlCommand)
                    logging.info(sqlCommand)
                    
                    if cursor.rowcount == 0:
                        logging.error(f"{row} has no data")
                        continue
                    else:
                        for data in cursor:
                            ts = data[0]
                            ts_list.append(ts)
                            name = data[1]
                            power = data[2]
                            energy = data[3]
                            
                            pattern = fr"(?<!\w){name.lower()}+(?!\d)"
                            result1 = re.sub(pattern, str(power), result1)
                            result2 = re.sub(pattern, str(energy), result2) 
                            
                    try:
                        if 'power' in result1:
                            continue
                        else:
                            powerC = round(eval(result1), 2)
                            energyC = round(eval(result2), 2)
                            value_string += f"('{ts_list[0]}', '{sId}', '{names}', {powerC}, {energyC}), "
                            
                    except ZeroDivisionError:
                        if power == 0:
                            powerC = 0
                        if energy == 0:
                            energyC = 0

        if value_string != '':
            value_string = value_string[:-2]                   
            with conn.cursor() as cursor:
                replace_sql = f"REPLACE INTO dataPlatform2023.power_07(ts, siteId, name, powerConsumed, energyConsumed) VALUES {value_string}"
                try:
                    cursor.execute(replace_sql)
                    print("replace success")
                    logging.info(replace_sql)
                except Exception as ex:
                    logging.error(f"SQL: {replace_sql}")
                    logging.error(f"[Replace ERROR]: {str(ex)}")


    conn.commit()
    logging.info(f"----- Connection Commit -----")
    conn.close()
    logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")

if __name__ == '__main__':
    file = __file__
    basename = os.path.basename(file)
    filename = os.path.splitext(basename)[0]
    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')],
        level=logging.INFO,
        format='%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    try:
        date = sys.argv[1]
        y = (sys.argv[2] if len(sys.argv) > 2 and re.match('^\d{4}', sys.argv[2]) else '')
        pattern = r'^\d{4}-\d{2}-\d{2}$'
        if re.match(pattern, date):
            data =  date.split('-')
            year,month,day = int(data[0]),int(data[1]),int(data[2])
            nowTime = datetime.now().replace(year,month,day,hour=23,minute=59,second=59,microsecond=0)
            mon = (f'_{month:02}' if y != '' else '')
            st = (nowTime - timedelta(hours=1))
            et = nowTime
            logging.info(f"---------- now: {nowTime} ----------")
            main()
        else:
            print("輸入錯誤，請重新輸入，格式:YYYY-MM-DD。")
    except ValueError as Vex:
        print (Vex)
    except IndexError as Iex:
        print(f"請加上日期，ex:python3 {filename}.py YYYY-MM-DD。")
