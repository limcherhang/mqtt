import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:00'))

startRunTime=(nowTime-timedelta(days=1)).strftime('%Y-%m-%d 00:00:00')
year = startRunTime[:4]
endRunTime=nowTime.strftime('%Y-%m-%d 00:00:00')

print("startRunTime: ",startRunTime)
print("endRunTime: ",endRunTime)


def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			#host='192.168.1.62',
			user='ecoprog',
			password='ECO4prog'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None


def sql(tablename,id,name,start,end,string):
	sqlCommand="""
	Select * 
	from dataPlatform.{} 
	where siteId={} and name='{}' and ts>='{}' and ts<'{}' and energyConsumed is not NULL and total is not NULL
	{}
	limit 1
	""".format(tablename,id,name,start,end,string)
	
	return sqlCommand

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc='power' and gatewayId>0
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		sId=rows[0]
		name=rows[1]
		table=rows[3]
		with conn.cursor() as cursor:
			cursor.execute(sql(table,sId,name,startRunTime,endRunTime,'order by ts desc'))
			#last=cursor.fetchone()
			#cursor.execute(sql(rows[3],rows[0],rows[1],startRunTime,endRunTime,'order by ts asc'))
			#first=cursor.fetchone()
			
			for data in cursor:
				print(data)
				energyConsumption=('NULL' if data[7] is None else data[7])
				total=('NULL' if data[8] is None else data[8])
				with conn.cursor() as cursor:
					sqlCommand="""
					Replace into `reportPlatform{}`.`{}` (
					`date`,`siteId`,`name`,`energyConsumption`,`total`
					)values(\'{}\',{},\'{}\',{},{})
					""".format(year,'D'+rows[3],(nowTime-timedelta(days=1)).strftime('%Y-%m-%d'),data[1],data[2],energyConsumption,total)
					print(sqlCommand)
					cursor.execute(sqlCommand)
			
		cnt+=1
	
	print("------ Fetching %d rows Succeed ------"%cnt)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
