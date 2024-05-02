import pymysql
import numpy as np
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

def getData(conn, string, sId, name, st, et):
    cursor = conn.cursor()
    sqlCommand=f"select {string} from dataPlatform.particle where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #print(sqlCommand)
    cursor.execute(sqlCommand)

    return cursor.fetchone()[0]


nowTime = datetime.now().replace(microsecond=0)
st = (nowTime-timedelta(days=1)).replace(hour=0, minute=0, second=0)
year = st.year
et = nowTime.strftime('%Y-%m-%d')

print(f"from {st} to {et}")

#testbed_conn=connectDB('127.0.0.1')
conn=connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand=f"select siteId, name, nameDesc, tableDesc from mgmtETL.NameList where tableDesc='particle' and gatewayId>0"
cursor.execute(sqlCommand)

for rows in cursor:
    sId=rows[0]
    name=rows[1]
    table=rows[3]
    print(f"----- Processing {sId} {name} -----")
    data_list=[]
    # calculate Max of particle
    #with conn.cursor() as data_cursor:
    #    particleMax = getData(conn, 'Max(particle)', sId, name, st, et)
    #    #print(particleMax)
    #    if particleMax is None:
    #        print(f"[ERROR]: siteId:{sId} {name} has no Max particle in this day!")
    #        continue
    ## calculate Min of particle
    #with conn.cursor() as data_cursor:
    #    particleMin = getData(conn, 'Min(particle)', sId, name, st, et)
    #    #print(particleMin)
    #    if particleMin is None:
    #        print(f"[ERROR]: siteId:{sId} {name} has no Min particle in this day!")
    #        continue
    ## calculate Median of particle
    #with conn.cursor() as data_cursor:
    #    sqlCommand=f"select particle from dataPlatform.particle where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #    #print(sqlCommand)
    #    data_cursor.execute(sqlCommand)
    #    if data_cursor.rowcount==0:
    #        print(f"[ERROR]: siteId:{sId} {name} has no data in the day ")
    #        continue
    #    for data in data_cursor:
    #        data_list.append(data[0])
    #    particleMedian=statistics.median(data_list)
    ## insert into Dparticle
    #with conn.cursor() as replace_cursor:
    #    replace_sql=f"""
    #    replace into `reportPlatform{year}`.`Dparticle` (
    #    `date`, `siteId`, `name`, `particleMin`, `particleMedian`, `particleMax`
    #    ) Values (
    #    '{st}', {sId}, '{name}', {particleMin}, {particleMedian}, {particleMax}
    #    )
    #    """
    #    print(replace_sql)
    #    replace_cursor.execute(replace_sql)

    with conn.cursor() as data_cursor:
        sqlCommand = f"select particle from dataPlatform.particle where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        data_cursor.execute(sqlCommand)

        if data_cursor.rowcount == 0:
            print(f"SiteId: {sId} has no data in the day")
            continue
        else:
            for data in data_cursor:
                if data[0] is not None: data_list.append(data[0])

    if len(data_list) != 0:
        particleMin = round(np.percentile(np.array(data_list), 0) ,2)
        particle25th = round(np.percentile(np.array(data_list), 25) ,2)
        particleMedian = round(np.percentile(np.array(data_list), 50) ,2)
        particle75th = round(np.percentile(np.array(data_list), 75) ,2)
        particleMax = round(np.percentile(np.array(data_list), 100) ,2)

    with conn.cursor() as cursor:
        replace_sql = f"replace into `reportPlatform{year}`.`Dparticle` (`date`, `siteId`, `name`, `particleMin`, `particle25th`, `particleMedian`, `particle75th`, `particleMax`) Values ('{st.strftime('%Y-%m-%d')}', {sId}, '{name}', {particleMin}, {particle25th}, {particleMedian}, {particle75th}, {particleMax})"
        print(replace_sql)
        cursor.execute(replace_sql)

conn.commit()
print("----- Replacing Succeed -----")
conn.close()
print("----- Connection Closed -----")