import pymysql
from datetime import datetime, timedelta

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

def getMinimumDataTime(gId, ETLName, st, et):
    global conn
    cursor=conn.cursor()
    sqlCommand=f"""
    select ts from dataETL.airQuality 
    where ch1=(select Min(ch1) from dataETL.airQuality where gatewayId={gId} and name='{ETLName}' and ts>='{st}' and ts<'{et}')
    and ts>='{st}' and ts<'{et}'
    """
    #print(sqlCommand)
    cursor.execute(sqlCommand)
    if cursor.rowcount==0:
        return None
    return cursor.fetchone()[0]

nowTime=datetime.now().replace(microsecond=0)
conn=connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand=f"select siteId, name, nameDesc, gatewayId, dataETLName, dataETLValue from mgmtETL.NameList where tableDesc='particle' and protocol is NOT NULL and gatewayId>0"
cursor.execute(sqlCommand)
for rows in cursor:
    range_st = (nowTime-timedelta(minutes=2)).replace(second=0)
    range_et = nowTime+timedelta(minutes=1)
    
    sId=rows[0]
    name=rows[1]
    gId=rows[3]
    ETLName=rows[4]
    ETLValue=int(rows[5])
    print(f"Processing siteId:{sId} {name}...")
    
    while range_st<range_et:
        st=range_st
        et=st+timedelta(minutes=1)
        print(f" from {st} to {et}")

        minidataTime = getMinimumDataTime( gId, ETLName, st, et)
        if minidataTime is None:
            print(f" [ERROR]: gatewayId:{gId} {ETLName} has no data in this minute !")
            range_st+=timedelta(minutes=1)
            continue
        else:
            if minidataTime.second==0:
                ts=minidataTime
            else:
                ts=minidataTime-timedelta(seconds=1)
        
        data_cursor = conn.cursor()
        sqlCommand=f"select * from dataETL.airQuality where gatewayId={gId} and name='{ETLName}' and ts='{ts}'"
        data_cursor.execute(sqlCommand)
        if data_cursor.rowcount==0:
            print(f"[ERROR]: gatewayId:{gId} {ETLName} has no data during the time!")
            range_st+=timedelta(minutes=1)
            continue
        for data in data_cursor:
            ts=data[0].replace(second=0)
            particle=data[3+ETLValue]

            with conn.cursor() as replace_cursor:
                replace_sql=f"""
                replace into `dataPlatform`.`particle` (
                `ts`, `siteId`, `name`, `particle`
                ) Values(
                '{ts}', {sId}, '{name}', {particle}
                )
                """
                print(replace_sql)
                replace_cursor.execute(replace_sql)
        range_st+=timedelta(minutes=1)

conn.commit()
print("----- Replacing Succeed -----")
conn.close()
print("----- Connection Closed -----")
