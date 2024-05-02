import pymysql
from datetime import datetime, timedelta
import re
import sys
import os


file = __file__
basename = os.path.basename(file)
filename = os.path.splitext(basename)[0]
try:
    date = sys.argv[1]
    y = (sys.argv[2] if len(sys.argv) > 2 and re.match('^\d{4}', sys.argv[2]) else '')
    pattern = r'^\d{4}-\d{2}-\d{2}$'
    if re.match(pattern, date):
        data =  date.split('-')
        year,month,day = int(data[0]),int(data[1]),int(data[2])
        nowTime = datetime.now().replace(year,month,day)
        
        startRunTime=(nowTime-timedelta(days=1)).strftime('%Y-%m-%d 23:59:59')
        endRunTime=nowTime.strftime('%Y-%m-%d 23:59:59') 

        st_m = (nowTime-timedelta(days=1)).strftime('%m')
        st_m = (f'_{st_m}' if y != '' else '')
        end_m = nowTime.strftime('%m') 
        end_m = (f'_{end_m}' if y != '' else '')
        print("startRunTime: ",startRunTime)
        print("endRunTime: ",endRunTime)
    else:
        print("輸入錯誤，請重新輸入，格式:YYYY-MM-DD。")
except ValueError as Vex:
    print (Vex)
except IndexError as Iex:
    print(f"請加上日期，ex:python3 {filename}.py YYYY-MM-DD。")

def connectDB():
    try:
        conn=pymysql.connect(
            host='127.0.0.1',
            # user='eco',
            # password='ECO4ever'
            read_default_file = '~/.my.cnf'
        )
        print("------ Connection Succeed ------")
        return conn
    except Exception as ex:
        print("------ Connection Failed ------\n",str(ex))
    return None


def sql(tablename,id,name,mon,time,string):
    
    
    sqlCommand="""
    Select *
    from dataPlatform{}.{}{} 
    where siteId={} and name='{}' and ts<='{}'  and energyConsumed is not NULL and total is not NULL
    {}
    limit 1
    """.format(y,tablename,mon,id,name,time,string)
      
    return sqlCommand

conn = connectDB()


with conn.cursor() as cursor:
    sqlCommand="""
    Select siteId, name, nameDesc, tableDesc
    From mgmtETL.NameList
    Where tableDesc='power' and gatewayId > 0 and siteId = 87
    """
    cursor.execute(sqlCommand)
    cnt=0
    count = 0
    for rows in cursor:
        
        sId=rows[0]
        name=rows[1]
        table=rows[3]
        
        with conn.cursor() as cursor:
            cursor.execute(sql(table,sId,name,st_m,startRunTime,'order by ts desc'))
            first=cursor.fetchone()
            cursor.execute(sql(table,sId,name,end_m,endRunTime,'order by ts desc'))
            last=cursor.fetchone()
        
            energyConsumption = last[8] - first[8]

            total = last[8]

        with conn.cursor() as cursor:
            sqlCommand="""
            Replace into `reportPlatform{}`.`{}` (
            `date`,`siteId`,`name`,`energyConsumption`,`total`
            )values(\'{}\',{},\'{}\',{},{})
            """.format(year,'D'+rows[3],last[0],last[1],last[2],abs(energyConsumption),total)
            
            cursor.execute(sqlCommand)
        
       


conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")

