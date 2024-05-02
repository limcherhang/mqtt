import pymysql
import statistics
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

def getData(string, table, sId, name):
    global st
    global et
    with conn.cursor() as data_cursor:
        sqlCommand=f"select {string} from dataPlatform.{table} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        #print(sqlCommand)
        data_cursor.execute(sqlCommand)
        data = data_cursor.fetchone()[0]
        if data is None:
            return None

    return round(data,2)

nowTime = datetime.now().replace(microsecond=0)
st = (nowTime-timedelta(days=1)).strftime('%Y-%m-%d')
year = st[:4]
et = nowTime.strftime('%Y-%m-%d')
#print(f" from {st} to {et}")

conn = connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand = "select siteId, name, tableDesc from mgmtETL.NameList where gatewayId>0 and tableDesc='pressure'"
cursor.execute(sqlCommand)

for rows in cursor:
    sId = rows[0]
    name = rows[1]
    table = rows[2]

    pressureMin = getData('min(pressure)', table, sId, name)
    pressureMax = getData('max(pressure)', table, sId, name)

    data_list = []
    with conn.cursor() as data_cursor:
        sqlCommand = f"select pressure from dataPlatform.{table} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        data_cursor.execute(sqlCommand)
        
        if data_cursor.rowcount == 0:
            continue

        for data in data_cursor:
            data_list.append(data[0])
    pressureMedian = statistics.median(data_list)

    with conn.cursor() as replace_cursor:
        replace_sql = f"""
        replace into `reportPlatform{year}`.`Dpressure`(
        `date`, `siteId`, `name`, `pressureMin`, `pressureMedian`, `pressureMax`
        ) Values('{st}', {sId}, '{name}', {pressureMin}, {pressureMedian}, {pressureMax})
        """
        print(replace_sql)
        replace_cursor.execute(replace_sql)

conn.commit()
print("----- Replacing Succeed -----")
cursor.close()
conn.close()
print("----- Calculation done ! Connection Closed -----")