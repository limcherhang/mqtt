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

nowTime = datetime.now().replace(second=0, microsecond=0)
st = nowTime-timedelta(minutes=2)
et = nowTime+timedelta(minutes=1)

#prod_conn=connectDB('192.168.1.62')
#testbed_conn=connectDB('127.0.0.1')
conn=connectDB('127.0.0.1')

#cursor = pro_conn.cursor()
#sqlCommand="select siteId, name, ieee, gatewayId from mgmtETL.Device where name like 'Particle#%'"
#cursor.execute(sqlCommand)

ieee_list=['00124b00192f25f5']
#for rows in cursor:
for ieee in ieee_list:
    
    data_cursor = conn.cursor()
    sqlCommand=f" \
    select ts, gatewayId, linkQuality, ieee, receivedSync, \
    conv(substring(responseData,7,8),16,10) as ch1, \
    conv(substring(responseData,15,8),16,10) as ch2, \
    conv(substring(responseData,23,8),16,10) as ch3, \
    conv(substring(responseData,31,8),16,10) as ch4 \
    from iotmgmt.zigbeeRawModbus \
    where ieee='{ieee}' and receivedSync>='{st}' and receivedSync<'{et}' \
    "
    #print(sqlCommand)
    data_cursor.execute(sqlCommand)
    if data_cursor.rowcount==0:
        print(f"[ERROR]: {ieee} has no data in this minute!")
        continue
    
    for data in data_cursor:
        print(data)
        ts=data[0]
        gId=data[1]
        linkQuality=data[2]
        receivedSync=data[4]      
        ch1=data[5]
        ch2=data[6]
        ch3=data[7]
        ch4=data[8]

        with conn.cursor() as replace_cursor:
            insert_sql=f"""
            insert into `iotmgmt`.`particle` (
            `ts`, `gatewayId`, `linkQuality`, `ieee`, `receivedSync`, 
            `ch1`, `ch2`, `ch3`, `ch4`
            ) Values (
            '{receivedSync}', {gId}, {linkQuality}, '{ieee}', '{receivedSync}', 
            {ch1}, {ch2}, {ch3}, {ch4}
            )
            """
            print(insert_sql)
            replace_cursor.execute(insert_sql)


#print(f"----- from {st} to {et} -----")
conn.commit()
print(f"----- Replacing Succeed -----")
conn.close()
print("----- Connections Closed -----")