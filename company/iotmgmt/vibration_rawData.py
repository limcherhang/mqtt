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

nowTime=datetime.now().replace(microsecond=0)
st = (nowTime-timedelta(minutes=2)).replace(second=0)
et = nowTime

#prod_conn=connectDB('192.168.1.62')
#testbed_conn=connectDB('127.0.0.1')
conn=connectDB('127.0.0.1')

ieee_list = ['00124b00193099f9', '00124b0019309a18', '00124b0019309c73', '00124b0019309c82', '00124b0019309bd9', '00124b0019309c9a', '00124b0019309c57', '00124b0019309ca2', #CPF
'00124b0019309a9d', '00124b00060cca38', '00124b00192f25ea', '00124b00192f25e6', '00124b0019309be8', '00124b0019309c95', #YWCA
'00124b0019309a58', '00124b00192f1f2e', '00124b00192f1bb2', '00124b00192f1bdd', '00124b00192f25c9', '00124b00192f1bad', '00124b00192f1f13', '00124b00192f1bca', #Chinatown point
'00124b00192f1be5', '00124b00192f1bcc', '00124b00192f1bd8', '00124b00192f1bd1', '00124b00192f1d8b', '00124b00192f1d8f', '00124b00192f1bb7', '00124b00192f1f02', '00124b00192f1bb9', '00124b00192f1bf0', '00124b00192f1d9f', '00124b00192f1bc9', '00124b00192f1be8', '00124b00192f1bc2'] # OFC

for ieee in ieee_list:
    print(f"Pocessing {ieee} ...")
    data_cursor=conn.cursor()
    sqlCommand=f""" \
    select ts, gatewayId, linkQuality, ieee, receivedSync, \
    conv(substring(responseData,7,4),16,10)*0.00390625 as xRMS, \
    conv(substring(responseData,11,4),16,10)*0.00390625 as yRMS, \
    conv(substring(responseData,15,4),16,10)*0.00390625 as zRMS, \
    conv(substring(responseData,19,4),16,10)*0.00390625 as xPeak, \
    conv(substring(responseData,23,4),16,10)*0.00390625 as yPeak, \
    conv(substring(responseData,27,4),16,10)*0.00390625 as zPeak \
    from iotmgmt.zigbeeRawModbus \
    where ieee='{ieee}' and ts>='{st}' and ts<'{et}' \
    """
    data_cursor.execute(sqlCommand)
    if data_cursor.rowcount==0:
        print(f"[ERROR]: {ieee} has no data during the time!")
        continue
    for data in data_cursor:
        print(data)
        ts=data[0]
        gId=data[1]
        linkQuality=('NULL' if data[2] is None else data[2])
        receivedSync=data[4]
        xRMS=data[5]
        yRMS=data[6]
        zRMS=data[7]
        xPeak=data[8]
        yPeak=data[9]
        zPeak=data[10]
        
        with conn.cursor() as replace_cursor:
            insert_sql=f"""
            insert into `iotmgmt`.`vibration` (
            `ts`, `gatewayId`, `linkQuality`, `ieee`, `receivedSync`, 
            `xRMS`, `yRMS`, `zRMS`, 
            `xPeak`, `yPeak`, `zPeak`
            ) Values (
            '{ts}', {gId}, {linkQuality}, '{ieee}', '{receivedSync}', 
            {xRMS}, {yRMS}, {zRMS}, 
            {xPeak}, {yPeak}, {zPeak}
            )
            """
            print(insert_sql)
            replace_cursor.execute(insert_sql)

conn.commit()
print(f"----- Replacing Succeed ----- ")
conn.close()
print("----- Connections Closed -----")