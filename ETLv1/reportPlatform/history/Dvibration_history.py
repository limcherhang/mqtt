import pymysql
from datetime import datetime, time, timedelta
import sys
import statistics

def connectDB(host):
    try:
        conn=pymysql.connect(
            host=host,
            read_default_file='~/.my.cnf'
        )
        return conn
    except Exception as ex:
        raise f"[ERROR]: {str(ex)}"
    return None

def getMax(conn, string, sId, name, st, et):
    cursor = conn.cursor()
    max_sql=f"select Max({string}) from dataPlatform.vibration where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #print(max_sql)
    cursor.execute(max_sql)
    if cursor.rowcount==0:
        print(f"[Error]: siteId:{sId} {name} {string} has no Max data")
        return 'NULL'
    else:
        max=cursor.fetchone()[0]
        if max is None:
            return 'NULL'
        else:
            return max

def getMin(conn, string, sId, name, st, et):
    cursor = conn.cursor()
    min_sql=f"select Min({string}) from dataPlatform.vibration where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #print(min_sql)
    cursor.execute(min_sql)
    if cursor.rowcount==0:
        print(f"[Error]: siteId:{sId} {name} {string} has no Min data")
        return 'NULL'
    else:
        min=cursor.fetchone()[0]
        if min is None:
            return 'NULL'
        else:
            return min

def getMedian(conn, string, sId, name, st, et):
    data_list=[]
    cursor = conn.cursor()
    sqlCommand=f"select {string} from dataPlatform.vibration where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #print(sqlCommand)
    cursor.execute(sqlCommand)
    if cursor.rowcount==0:
        print(f"[Error]: siteId:{sId} {name} has no {string} data in the day")
        return None
    for data in cursor:
        data_list.append(data[0])
    median=statistics.median(data_list)
    return median

if len(sys.argv)!=5:
    print(len(sys.argv))
    print("Type Error:參數不夠,含程式名稱需要5個\n 順序: python3 程式名稱 開始月份 開始日期 結束月份 結束日期")
    sys.exit()
else:
    st=datetime(2021, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d 00:00:00')
    #et=datetime(2021, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d 00:00:00')
    et=st+timedelta(days=1)
    date=st.strftime('%Y-%m-%d')
    print("-----程式執行時間不含結束時間-----")

print(f" from {st} to {et}")

conn=connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand="select siteId, name, nameDesc, tableDesc from mgmtETL.NameList where tableDesc='vibration' and gatewayId>0"
cursor.execute(sqlCommand)

cnt=0
for rows in cursor:
    print(f"{(cnt+1)} {rows}")
    cnt+=1
    sId=rows[0]
    name=rows[1]
    table=rows[3]
    #get Maximum data of xRMS, yRMS and zRMS
    xRMSMax = getMax(conn, 'xRMS', sId, name , st, et)
    yRMSMax = getMax(conn, 'yRMS', sId, name , st, et)
    zRMSMax = getMax(conn, 'zRMS', sId, name , st, et)
    #get Minimum data of xRMS, yRMS and zRMS
    xRMSMin = getMin(conn, 'xRMS', sId, name , st, et)
    yRMSMin = getMin(conn, 'yRMS', sId, name , st, et)
    zRMSMin = getMin(conn, 'zRMS', sId, name , st, et)
    #get Median data of xRMS, yRMS and zRMS
    xRMSMedian = getMedian(conn, 'xRMS', sId, name , st, et)
    yRMSMedian = getMedian(conn, 'yRMS', sId, name , st, et)
    zRMSMedian = getMedian(conn, 'zRMS', sId, name , st, et)
    #print(xRMSMedian)
    #print(yRMSMedian)
    #print(zRMSMedian)
    if xRMSMedian is None and yRMSMedian is None and zRMSMedian is None:
        continue
    with conn.cursor() as replace_cursor:

        replace_sql=f"""
        replace into `reportPlatform2021`.`Dvibration`(
        `date`, `siteId`, `name`, 
        `xRMSMin`, `xRMSMedian`, `xRMSMax`, 
        `yRMSMin`, `yRMSMedian`, `yRMSMax`, 
        `zRMSMin`, `zRMSMedian`, `zRMSMax`
        ) Values (
        '{date}', {sId}, '{name}', 
        {xRMSMin}, {xRMSMedian}, {xRMSMax}, 
        {yRMSMin}, {yRMSMedian}, {yRMSMax}, 
        {zRMSMin}, {zRMSMedian}, {zRMSMax}
        )
        """
        print(replace_sql)
        replace_cursor.execute(replace_sql)
 
conn.commit()
print(f"----- Replacing Succeed ----- {cnt} rows affected")
conn.close()
print("----- Connection Closed -----")