import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			user='ecoprog',
			password='ECO4prog'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None

startRunTime=(nowTime-timedelta(minutes=3)).strftime('%Y-%m-%d %H:%M:00')
endRunTime=nowTime.strftime('%Y-%m-%d %H:%M:00')
print("Searching from %s to %s"%(startRunTime,endRunTime))

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc, gatewayId, protocol, dataETLName, dataETLValue
	From mgmtETL.NameList
	Where dataETLName like %s and protocol is NOT NULL and gatewayId>0
	"""
	cursor.execute(sqlCommand,('Pressure#%',))
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		
		with conn.cursor() as cursor:
			sqlCommand="""
			Select * From dataETL.pressure 
			Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
			Order by ts desc
			""".format(rows[4],rows[6],startRunTime,endRunTime)
			
			cursor.execute(sqlCommand)
			
			n=0
			for data in cursor:
				print("   (%d)"%(n+1),data)
				with conn.cursor() as cursor:
					sqlCommand="""
					Replace into `dataPlatform`.`{}`(
					`ts`,`siteId`,`name`,`pressure`
					)values(\'{}\',{},\'{}\',{})
					""".format(rows[3],data[0],rows[0],rows[1],data[3])
					print(sqlCommand)
					cursor.execute(sqlCommand)
				n+=1
		cnt+=1
	
	
	print("------ %d rows Fetched ------"%cnt)

conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print("------ Connection Closed ------")