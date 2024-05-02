import pymysql
from datetime import datetime, timedelta
import sys
import statistics

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
    global year
    global mon
    cursor = conn.cursor()
    sqlCommand=f"select {string} from dataPlatform{year}.particle_{mon} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
    #print(sqlCommand)
    cursor.execute(sqlCommand)

    return cursor.fetchone()[0]

if len(sys.argv)!=5:
    print(len(sys.argv))
    print("Type Error:參數不夠,含程式名稱需要5個\n 順序: python3 程式名稱 開始月份 開始日期 結束月份 結束日期")
    sys.exit()
else:
	st=datetime(2021, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d 00:00:00')
	et=datetime(2021, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d 00:00:00')
	year=st.strftime('%Y')
	mon=st.strftime('%m')
	date=st.strftime('%Y-%m-%d')
	print("-----程式執行時間不含結束時間-----")

print(f" from {st} to {et}")

#conn=connectDB('192.168.1.62')
conn=connectDB('127.0.0.1')

cursor = conn.cursor()
sqlCommand=f"select siteId, name, nameDesc, tableDesc from mgmtETL.NameList where tableDesc='particle' and gatewayId>0"
cursor.execute(sqlCommand)
for rows in cursor:
    print(rows)
    sId=rows[0]
    name=rows[1]
    table=rows[3]
    data_list=[]
    # calculate Max of particle
    with conn.cursor() as data_cursor:
        particleMax = getData(conn, 'Max(particle)', sId, name, st, et)
        #print(particleMax)
        if particleMax is None:
            print(f"[ERROR]: siteId:{sId} {name} has no Max particle in this day!")
            continue
    # calculate Min of particle
    with conn.cursor() as data_cursor:
        particleMin = getData(conn, 'Min(particle)', sId, name, st, et)
        #print(particleMin)
        if particleMin is None:
            print(f"[ERROR]: siteId:{sId} {name} has no Min particle in this day!")
            continue
    # calculate Median of particle
    with conn.cursor() as data_cursor:
        sqlCommand=f"select particle from dataPlatform{st.year}.particle_{mon} where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
        #print(sqlCommand)
        data_cursor.execute(sqlCommand)
        if data_cursor.rowcount==0:
            print(f"[ERROR]: siteId:{sId} {name} has no data in the day ")
            continue
        for data in data_cursor:
            data_list.append(data[0])
        particleMedian=statistics.median(data_list)
    # insert into Dparticle
    with conn.cursor() as replace_cursor:
        replace_sql=f"""
        replace into `reportPlatform2021`.`Dparticle` (
        `date`, `siteId`, `name`, `particleMin`, `particleMedian`, `particleMax`
        ) Values (
        '{date}', {sId}, '{name}', {particleMin}, {particleMedian}, {particleMax}
        )
        """
        print(replace_sql)
        replace_cursor.execute(replace_sql)

conn.commit()
print("----- Replacing Succeed -----")
conn.close()
print("----- Connection Closed -----")