import pymysql
import time
from datetime import datetime, timedelta

def connectDB(host):
    try:
        conn = pymysql.connect(
            host=host,
            read_default_file='~/.my.cnf'
        )
        return conn
    except Exception as ex:
        print(f"[ERROR]: {str(ex)}")
    return None

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
st = (nowTime - timedelta(minutes=3)).replace(second=0)
et = nowTime

conn = connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand = "select siteId, name, nameDesc, gatewayId, dataETLName from mgmtETL.NameList where tableDesc='wetness' and gatewayId>0"
cursor.execute(sqlCommand)

for rows in cursor:
    sId = rows[0]
    name = rows[1]
    gId = rows[3]
    etlName = rows[4]
    print(f"Processing siteId:{sId} {name}")
    
    with conn.cursor() as data_cursor:
        sqlCommand = f"select ts, wetness from dataETL.wetness where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
        data_cursor.execute(sqlCommand)

        for rows in data_cursor:
            ts = rows[0]
            wetness = rows[1]

            with conn.cursor() as replace_cursor:
                replace_sql = f"replace into `dataPlatform`.`wetness` (`ts`, `siteId`, `name`, `wetness`) Values ('{ts}', {sId}, '{name}', {wetness})"
                print(replace_sql)
                replace_cursor.execute(replace_sql)

conn.commit()
print("----- Replacing Succeed -----")

cursor.close()
conn.close()
print(f"----- Calculation done ! Connection Closed ----- took: {round((time.time()-s), 2)}s")
