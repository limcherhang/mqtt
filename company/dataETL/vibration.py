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
sqlCommand="select name, ieee, gatewayId from mgmtETL.Device where name like 'Vibration#%' and gatewayId>0"
cursor.execute(sqlCommand)

for rows in cursor:
    name=rows[0]
    ieee=rows[1]
    gId=rows[2]
    print(f"Processing gatewayId:{gId} {ieee} {name}")
    data_cursor=conn.cursor()
    sqlCommand=f"select receivedSync, xRMS, yRMS, zRMS, xPeak, yPeak, zPeak from iotmgmt.vibration where gatewayId={gId} and ieee='{ieee}' and receivedSync>='{st}' and receivedSync<'{et}'"
    data_cursor.execute(sqlCommand)
    if data_cursor.rowcount==0:
        print(f"[ERROR]: gatewayId:{gId} {ieee} has no data during the time!")
        continue
    for data in data_cursor:
        ts=data[0]
        xRMS=data[1]
        yRMS=data[2]
        zRMS=data[3]
        xPeak=data[4]
        yPeak=data[5]
        zPeak=data[6]
        with conn.cursor() as replace_cursor:
            replace_sql=f"""
            replace into `dataETL`.`vibration` (
            `ts`, `gatewayId`, `name`, 
            `xRMS`, `yRMS`, `zRMS`, 
            `xPeak`, `yPeak`, `zPeak`
            ) Values (
            '{ts}', {gId}, '{name}', 
            {xRMS}, {yRMS}, {zRMS}, 
            {xPeak}, {yPeak}, {zPeak}
            )
            """
            print(replace_sql)
            replace_cursor.execute(replace_sql)

conn.commit()
print(f"----- Replacing Succeed ----- ")
conn.close()
print("----- Connections Closed -----")