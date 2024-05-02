import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:00'))

startRunTime=(nowTime-timedelta(days=1)).strftime('%Y-%m-%d 00:00:00')
year = startRunTime[:4]
endRunTime=nowTime.strftime('%Y-%m-%d 00:00:00')
st_m = (nowTime-timedelta(days=1)).strftime('_%m')
end_m = nowTime.strftime('_%m')
print("startRunTime: ",startRunTime)
print("endRunTime: ",endRunTime)

def connectDB():
    try:
        conn=pymysql.connect(
            host='127.0.0.1',
            #port=3306,
            # user='username',
            # password='password'
            read_default_file = '~/.my.cnf'
        )
        print("------ Connection Succeed ------")
        return conn
    except Exception as ex:
        print("------ Connection Failed ------\n",str(ex))
    return None

def sql(year,tablename,mon,id,name,time,string):
    sqlCommand="""
    Select * 
    from dataPlatform{}.{}{} 
    where siteId={} and name='{}' and ts<'{}' and energyConsumed is not NULL and total is not NULL
    {}
    limit 1
    """.format(year,tablename,mon,id,name,time,string)
    print(sqlCommand)
    return sqlCommand

conn=connectDB()

with conn.cursor() as cursor:
    sqlCommand="""
    Select siteId, name, nameDesc, tableDesc
    From mgmtETL.NameList
    Where tableDesc='power' and gatewayId>0 and siteId = 87
    """
    cursor.execute(sqlCommand)
    
    cnt=0
    for rows in cursor:
        print("%d "%(cnt+1),rows)
        sId=rows[0]
        name=rows[1]
        table=rows[3]
        with conn.cursor() as cursor:
            cursor.execute(sql(year,table,st_m,sId,name,startRunTime,'order by ts desc'))
            first=cursor.fetchone()
            cursor.execute(sql(year,table,end_m,sId,name,endRunTime,'order by ts desc'))
            last=cursor.fetchone()
            
            energyConsumption=last[8]-first[8]
            total=('NULL' if last[8] is None else last[8])
            with conn.cursor() as cursor:
                sqlCommand="""
                Replace into `reportPlatform{}`.`{}` (
                `date`,`siteId`,`name`,`energyConsumption`,`total`
                )values(\'{}\',{},\'{}\',{},{})
                """.format(year,'D'+rows[3],(nowTime-timedelta(days=1)).strftime('%Y-%m-%d'),last[1],last[2],energyConsumption,total)
                print(sqlCommand)
                cursor.execute(sqlCommand)
                
        cnt+=1
    
    print("------ Fetching %d rows Succeed ------"%cnt)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
