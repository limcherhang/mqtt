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

def getFlowTotal(conn, gId, ETLName, st, et):
    cursor = conn.cursor()
    sqlCommand=f"select flowTotalPositive from dataETL.flow where gatewayId={gId} and name='{ETLName}' and ts>='{st}' and ts<'{et}' order by ts asc limit 1"
    cursor.execute(sqlCommand)
    #print(sqlCommand)
    if cursor.rowcount==0:
        print(f"[ERROR]: gatewayId:{gId} {ETLName} has no 'flowTotalPositive' during the time!")
        return 0
    return cursor.fetchone()[0]

nowTime = datetime.now().replace(microsecond=0)
lastDay = (nowTime-timedelta(days=1)).strftime('%Y-%m-%d')
st = (nowTime-timedelta(minutes=18)).replace(second=0)
et = nowTime

conn=connectDB('127.0.0.1')
cursor = conn.cursor()
sqlCommand="""
select siteId, name, nameDesc, tableDesc, gatewayId, dataETLName 
from mgmtETL.NameList 
where gatewayId=182 and protocol='Name' and dataETLName like 'Flow#%'
"""
cursor.execute(sqlCommand)
cnt=0
for rows in cursor:
    print(rows)
    sId=rows[0]
    name=rows[1]
    gId=rows[4]
    dataETLName=rows[5]

    cursor = conn.cursor()
    sqlCommand=f"select ts, flowRate, flowTotalPositive from dataETL.flow where gatewayId={gId} and name='{dataETLName}' and ts>='{st}' and ts<'{et}'"

    cursor.execute(sqlCommand)
    if cursor.rowcount==0:
        print(f"[ERROR]: gatewayId:{gId} {dataETLName} has no data during the time!")
        cnt+=1
        continue

    preTotal0000=getFlowTotal(conn, gId, dataETLName, lastDay, nowTime.strftime('%Y-%m-%d'))
    curTotal0000=getFlowTotal(conn, gId, dataETLName, nowTime.strftime('%Y-%m-%d'), nowTime)

    n=0
    for data in cursor:
        print(f"({n+1}) {data}")
        ts=data[0]
        flowRate=round(data[1],2)
        flowTotalPositive=('NULL' if data[2] is None else data[2])
        liquidLevel='NULL'
        total='NULL'

        with conn.cursor() as replace_cursor:
            if st.day<et.day:
                if ts.day==st.day:
                    total0000=preTotal0000
                else:
                    total0000=curTotal0000
            else:
                total0000=curTotal0000
            
            if flowTotalPositive is None:
                waterConsumed='NULL'
            elif total0000 is None:
                waterConsumed=flowTotalPositive
            else:
                waterConsumed=flowTotalPositive-total0000

            replace_sql=f"""
            replace into `dataPlatform`.`flow` (
            `ts`, `siteId`, `name`, `flowRate`, `liquidLevel`, `waterConsumed`, `total`
            ) Values(
            '{ts}', {sId}, '{name}', {flowRate}, {liquidLevel}, {waterConsumed}, {total}
            )
            """
            print(replace_sql)
            replace_cursor.execute(replace_sql)
        n+=1
    cnt+=1
print(f"----- {cnt} rows Fetched -----")
conn.commit()
print("----- Replacing Succeed -----")
conn.close()
print("----- Connection Closed -----")