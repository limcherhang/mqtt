import time
import pymysql
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta
import os
import re
def connectDB(host):
    try:
        conn = pymysql.connect(
            host = host,
            read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")

#找到+-*/的位置
def getarray(str):
    cnt = 0
    for j in str:
        if j in numlist :
            index_list.append(cnt)
        cnt+=1
    index_list.sort()

def getlevel():
    with conn.cursor() as cursor:
        sqlCommand = f"SELECT distinct level FROM mgmtETL.Calculation  order by level desc limit 1"
        logging.debug(sqlCommand)
        cursor.execute(sqlCommand)
        if cursor.rowcount == 0:
            logging.warning(f"power has no mapping info")
        for rows in cursor:
            level = rows[0]
    return level

file = __file__
basename = os.path.basename(file)
filename = os .path.splitext(basename)[0]
logging.basicConfig(
    
    handlers = [TimedRotatingFileHandler(f'./log/{filename}.log', when='midnight')], 
    level = logging.INFO, 
    format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
    datefmt = '%Y-%m-%d %H:%M:%S'
)

s=time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ----------")

st=(nowTime-timedelta(minutes=30)).replace(second=0)
et=nowTime
logging.info(f"----- Searching from {st} to {et} -----")

conn=connectDB('127.0.0.1')

numlist = ['+','-','*','/','(',')']

for count in range(getlevel()+1): 
    print(count)
    value_string = ''  
    with conn.cursor() as cursor:
        
        sqlCommand = f"SELECT siteId,name,Calculation from mgmtETL.Calculation where level = {count}"
        logging.debug(sqlCommand)
        cursor.execute(sqlCommand)
        if cursor.rowcount == 0:
            logging.warning(f"power has no mapping info")
        for rows in cursor:
            sId = rows[0]
            name = rows[1]
            result1 = rows[2]
            result2 = rows[2]
            result3 = ''
            begin = 0 
            index_list=[]
            result = []
            
            if 'to'  in result1  or 'To' in result1 or 'TO' in result1:
                a = ([int(s) for s in re.findall(r'-?\d+\.?\d*', result1)])
                b = result1[0:result1.find(str(a[0]))]
                for i in range(a[0],a[1]+1):
                    result3+=(f"{b}{i}+")
                result1 = result3[:-1]
                result2 = result3[:-1]     
            getarray(result1)
            logging.info (result1)  
            for index in index_list:
                if result1[begin:index] != '' and 'power' in result1[begin:index] or 'E' in result1[begin:index]:
                    if begin in index_list :
                        result.append(result1[begin+1:index])
                        begin = index+1
                    else:    
                        result.append(result1[begin:index])
                        begin = index+1
                
            if result1[begin:] != '' and 'power' in result1[begin:] or 'E' in result1[begin:]:
                if begin in index_list :
                    result.append(result1[begin+1:])
                else:
                    result.append(result1[begin:])           
            result.reverse()      
            for row in result :
                with conn.cursor() as cursor:
                    sqlCommand = f"""SELECT ts,powerConsumed,energyConsumed FROM dataPlatform.power 
                                where siteId = {sId} and name = '{row}' and ts>'{st}' and ts <'{et}' """
                    cursor.execute(sqlCommand)
                    logging.info(sqlCommand)
                    if cursor.rowcount == 0:
                        logging.error(f"{row} is no data")  
                        break
                    else:
                        for data in cursor:
                            ts = data[0]             
                            power = data[1]
                            energy = data[2]                                            
                        result1 = result1.replace(row,str(power))
                        result2 = result2.replace(row,str(energy))
                    
            try:
                if 'power' in result1 or 'E' in result1:
                    continue
                else:
                    powerC = round(eval(result1),2)         
                    energyC = round(eval(result2),2) 
                    value_string += f"('{nowTime}','{sId}','{name}',{powerC},{energyC}), "    
            except ZeroDivisionError:
                if power == 0:
                    powerC = 0
                if energy ==0:
                    energyC = 0

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into dataPlatform.power(ts,siteId,name,powerConsumed,energyConsumed) VALUES {value_string}"       
            try:
                print(replace_sql)
                cursor.execute(replace_sql)
                logging.info(replace_sql)
                conn.commit()
                logging.info(f"----- Connection Commit -----") 
                
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")

       
  
          
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
