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

nowTime = datetime.now().replace(microsecond=0)
st = (nowTime-timedelta(minutes=3)).replace(second=0)
et = nowTime

#testbed_conn=connectDB('127.0.0.1')
conn=connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand="select siteId, name, nameDesc, gatewayId, dataETLName from mgmtETL.NameList where tableDesc='vibration' and gatewayId>0"
cursor.execute(sqlCommand)

for rows in cursor:
    print(rows)
    sId=rows[0]
    name=rows[1]
    gId=rows[3]
    ETLName=rows[4]
    print(f"Processing siteId:{sId} {name}")

    data_cursor=conn.cursor()
    sqlCommand=f"select ts, xRMS, yRMS, zRMS from dataETL.vibration where gatewayId={gId} and name='{ETLName}' and ts>='{st}' and ts<'{et}'"
    data_cursor.execute(sqlCommand)
    if data_cursor.rowcount==0:
        print(f"[ERROR]: gatewayId:{gId} {ETLName} has no data during the time!")
        continue
    for data in data_cursor:
        ts=data[0]
        xRMS=data[1]
        yRMS=data[2]
        zRMS=data[3]

        with conn.cursor() as replace_cursor:
            replace_sql=f"""
            replace into `dataPlatform`.`vibration` (
            `ts`, `siteId`, `name`, 
            `xRMS`, `yRMS`, `zRMS`
            ) Values (
            '{ts}', {sId}, '{name}', 
            {xRMS}, {yRMS}, {zRMS}
            )
            """
            print(replace_sql)
            replace_cursor.execute(replace_sql)

conn.commit()
print(f"----- Replacing Succeed ----- ")
conn.close()
print("----- Connections Closed -----")