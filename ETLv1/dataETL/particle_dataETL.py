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
sqlCommand="select siteId, name, ieee, gatewayId from mgmtETL.Device where name like 'AirQuality#%' and gatewayId=159"
cursor.execute(sqlCommand)

value_string = ''
for rows in cursor:
    sId=rows[0]
    name=rows[1]
    ieee=rows[2]
    gId=rows[3]
    print(f"Processing gatewayId:{gId} {ieee}")
    
    data_cusor = conn.cursor()
    sqlCommand=f"select receivedSync, ch1, ch2, ch3, ch4 from iotmgmt.particle where gatewayId='{gId}' and ieee='{ieee}' and receivedSync>='{st}' and receivedSync<='{et}'"
    #print(sqlCommand)
    data_cusor.execute(sqlCommand)
        
    for data in data_cusor:
        ts=data[0]
        ch1=data[1]
        ch2=data[2]
        ch3=data[3]
        ch4=data[4]

        value_string += f"('{ts}', {gId}, '{name}', {ch1}, {ch2}, {ch3}, {ch4}), "

if value_string != '':
    value_string = value_string[:-2]
    with conn.cursor() as replace_cursor:
        replace_sql=f"replace into `dataETL`.`airQuality` (`ts`, `gatewayId`, `name`, `ch1`, `ch2`, `ch3`, `ch4`) Values {value_string}"
        try:
            replace_cursor.execute(replace_sql)
            print(replace_sql)
        except Exception as ex:
            print(f"[Replace ERROR]: {str(ex)}")

conn.commit()
print(f"----- Replacing Succeed -----")
conn.close()
print("----- Connection Closed -----")