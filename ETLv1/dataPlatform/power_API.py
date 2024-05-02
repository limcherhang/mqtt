import pymysql
from datetime import date, datetime, time, timedelta

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

def getTotal(conn, gId, name, st, et):
    with conn.cursor() as cursor:
        sqlCommand=f"select totalPositiveWattHour from dataETL.power where gatewayId={gId} and name='{name}' and ts>='{st}' and ts<'{et}' order by ts asc limit 1"
        #print(sqlCommand)
        cursor.execute(sqlCommand)
        data=cursor.fetchone()
        if data is None:
            total0000=None
        else:
            total0000=data[0]
    return total0000

def chillerPlant(conn, sId, name, gId, st, et):
    global nowTime

    with conn.cursor() as cursor:
        sqlCommand=f"select dataETLCombination from mgmtETL.NameList where siteId={sId} and name='{name}' and gatewayId={gId}"
        cursor.execute(sqlCommand)
        dataETLCombination = cursor.fetchone()[0]
        dataETLCombination = dataETLCombination[1:-1]
        #print(dataETLCombination)
        power_string = ''
        for str in dataETLCombination.split(', '):
            str = str[1:-1]
            power_string += f"'{str}', "
        #power_1 = dataETLCombination.split(', ')[0][1:-1]
        #power_2 = dataETLCombination.split(', ')[1][1:-1]

        #sqlCommand=f"select sum(totalPositiveLatest) from mgmtETL.PMLog where siteId={sId} and name in ('{power_1}', '{power_2}') and gatewayId={gId}"
        sqlCommand=f"select sum(totalPositiveLatest) from mgmtETL.PMLog where siteId={sId} and name in ({power_string[:-2]})"
        #print(sqlCommand)

        cursor.execute(sqlCommand)
        if cursor.rowcount==0:
            print(f" [ERROR]: gatewayId:{gId} {ETLName} has no totalPositiveLatest in PMLog")
            return 0
        latestTotal=cursor.fetchone()[0]

    while st<et:
        ts=st
        st+=timedelta(minutes=1)
        
        ch1Watt = 'NULL'
        ch2Watt = 'NULL'
        ch3Watt = 'NULL'
        powerConsumed = 'NULL'
        energyConsumed = 'NULL'
        total = 'NULL'

        with conn.cursor() as cursor:
            if sId == 24:
                sqlCommand=f"select sum(if(ch1Watt is NULL, 0, ch1Watt)), sum(if(ch2Watt is NULL, 0, ch2Watt)), sum(if(ch3Watt is NULL, 0, ch3Watt)), sum(if(powerConsumed is NULL, 0, powerConsumed)) from dataPlatform.power where siteId={sId} and name in ({power_string[:-2]}) and ts='{ts}'"
                cursor.execute(sqlCommand)
                data=cursor.fetchone()
                
                ch1Watt=data[0]
                ch2Watt=data[1]
                ch3Watt=data[2]
                powerConsumed=data[3]

                if ch1Watt is None and ch2Watt is None and ch3Watt is None and powerConsumed is None:
                    continue
                else:
                    ch1Watt = round(ch1Watt, 1)
                    ch2Watt = round(ch2Watt, 1)
                    ch3Watt = round(ch3Watt, 1)
                    powerConsumed = round(powerConsumed, 2)
            else:
                sqlCommand=f"select sum(if(ch1Watt is NULL, 0, ch1Watt)), sum(if(ch2Watt is NULL, 0, ch2Watt)), sum(if(ch3Watt is NULL, 0, ch3Watt)), sum(if(powerConsumed is NULL, 0, powerConsumed)), sum(if(energyConsumed is NULL, 0, energyConsumed)), sum(if(total is NULL, 0, total)) from dataPlatform.power where siteId={sId} and name in ({power_string[:-2]}) and ts='{ts}'"
                cursor.execute(sqlCommand)
                data=cursor.fetchone()
                
                ch1Watt=data[0]
                ch2Watt=data[1]
                ch3Watt=data[2]
                powerConsumed=data[3]
                energyConsumed=data[4]
                total=data[5]
            
                if ch1Watt is None and ch2Watt is None and ch3Watt is None and powerConsumed is None and energyConsumed is None and total is None:
                    continue
                else:
                    ch1Watt = round(ch1Watt, 1)
                    ch2Watt = round(ch2Watt, 1)
                    ch3Watt = round(ch3Watt, 1)
                    powerConsumed = round(powerConsumed, 2)
                    energyConsumed = round(energyConsumed, 2)
                    total = round(total, 2)
            
        with conn.cursor() as replace_cursor:
            replace_sql=f"""
            replace into `dataPlatform`.`power`(
            `ts`, `siteId`, `name`, 
            `ch1Watt`, `ch2Watt`, `ch3Watt`, `powerConsumed`, `energyConsumed`, `total`
            ) Values('{ts}', {sId}, '{name}', 
            {ch1Watt}, {ch2Watt}, {ch3Watt}, {powerConsumed}, {energyConsumed}, {total}
            )
            """
            print(replace_sql)
            replace_cursor.execute(replace_sql)

nowTime=datetime.now().replace(microsecond=0)
print(f"---------- now: {nowTime} ----------")
programStartTime=nowTime

st = (nowTime-timedelta(minutes=64)).replace(second=0)
et = nowTime

#st = datetime(2022, 5, 5)
#et = datetime(2022, 5, 6)

print(f"----- Searching from {st} to {et} -----")
conn=connectDB('127.0.0.1')

site_cursor = conn.cursor()
sqlCommand="select siteId, name, gatewayId, protocol, dataETLName from mgmtETL.NameList where tableDesc='power' and gatewayId in (170, 247, 248) and protocol is NOT NULL order by siteId, convert(substring_index(name, '#', -1), unsigned integer)"
site_cursor.execute(sqlCommand)

for rows in site_cursor:
    print(rows)
    sId=rows[0]
    name=rows[1]
    gId=rows[2]
    protocol=rows[3]
    ETLName=rows[4]
       
    log_cursor = conn.cursor()
    sqlCommand=f"select totalPositiveLatest from mgmtETL.PMLog where siteId={sId} and name='{ETLName}' and gatewayId={gId}"
    log_cursor.execute(sqlCommand)
    if log_cursor.rowcount==0:
        print(f" [ERROR]: gatewayId:{gId} {ETLName} has no totalPositiveLatest in PMLog")
        continue
    
    latestTotal=log_cursor.fetchone()[0]

    cursor = conn.cursor()
    sqlCommand=f"select ts, ch1Watt, ch2Watt, ch3Watt, totalPositiveWattHour, ch1Current, ch2Current, ch3Current from dataETL.power where gatewayId={gId} and name='{ETLName}' and ts>='{st}' and ts<'{et}'"
    #print(sqlCommand)
    cursor.execute(sqlCommand)
    if cursor.rowcount==0:
        print(f" [ERROR]: gatewayId:{gId} {ETLName} has no data during the time!")
        continue

    for data in cursor:
        print(data)
        ts=data[0]
        ch1Watt=(0 if data[1] is None else data[1])
        ch2Watt=(0 if data[2] is None else data[2])
        ch3Watt=(0 if data[3] is None else data[3])
        powerConsumed=(ch1Watt+ch2Watt+ch3Watt)/1000
        
        # totalPositiveWattHour Exception
        if data[4] is None:    
            totalPositiveWattHour='NULL'
            energyConsumed='NULL'
            total='NULL'
        else:
            totalPositiveWattHour=data[4]
            pre_st = (datetime.now()-timedelta(days=1)).strftime('%Y-%m-%d')
            pre_et = datetime.now().strftime('%Y-%m-%d')

            # determine last day or today
            if st.month<et.month:
                if ts.month==st.month:
                    total0000=getTotal(conn, gId, ETLName, pre_st, pre_et)
                else:
                    total0000=getTotal(conn, gId, ETLName, pre_et, nowTime)
            else:
                if st.day<et.day:
                    if ts.day==st.day:
                        total0000=getTotal(conn, gId, ETLName, pre_st, pre_et)
                    else:
                        total0000=getTotal(conn, gId, ETLName, pre_et, nowTime)
                else:
                    total0000=getTotal(conn, gId, ETLName, pre_et, nowTime)
            
            # total0000 Exception
            if total0000 is None:
                energyConsumed=totalPositiveWattHour/1000
            else:
                energyConsumed=(totalPositiveWattHour-total0000)/1000
            
            # latesTotal Exception
            if latestTotal is None:
                total=totalPositiveWattHour/1000
            else:
                total=(totalPositiveWattHour-latestTotal)/1000
            
        ch1Current=(0 if data[5] is None else data[5])
        ch2Current=(0 if data[6] is None else data[6])
        ch3Current=(0 if data[7] is None else data[7])

        with conn.cursor() as replace_cursor:
            sqlCommand=f"""
            replace into `dataPlatform`.`power`(
            `ts`, `siteId`, `name`, 
            `ch1Watt`, `ch2Watt`, `ch3Watt`,
            `powerConsumed`, 
            `energyConsumed`, 
            `total`, 
            `ch1Current`, `ch2Current`, `ch3Current`
            ) Values('{ts}', {sId}, '{name}', 
            {ch1Watt}, {ch2Watt}, {ch3Watt},
            {powerConsumed}, 
            {energyConsumed}, 
            {total}, 
            {ch1Current}, {ch2Current}, {ch3Current}
            )
            """
            print(sqlCommand)
            replace_cursor.execute(sqlCommand)

conn.commit()
print("----- Replacing Succeed -----")
conn.close()
print(f"----- Connnection Closed ----- took: {(datetime.now().replace(microsecond=0)-programStartTime).seconds}s")