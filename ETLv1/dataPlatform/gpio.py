import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			read_default_file='~/.my.cnf'
		)
		print("------ Connection Succeed ------\n")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None

startRunTime=(nowTime-timedelta(minutes=4)).strftime('%Y-%m-%d %H:%M:00')
endRunTime=nowTime.strftime('%Y-%m-%d %H:%M:00')

print("Searching from %s to %s"%(startRunTime,endRunTime))

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc, gatewayId, protocol, dataETLName, dataETLValue
	From mgmtETL.NameList
	Where name like %s and protocol is NOT NULL and gatewayId>0
	"""
	cursor.execute(sqlCommand,('gpio#%',))
	
	cnt=0
	for rows in cursor:
		print("%d"%(cnt+1),rows)
		protocol = rows[5]
		with conn.cursor() as cursor:
			if protocol.lower() == "value":
				sqlCommand="""
				Select * From dataETL.gpio 
				Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
				""".format(rows[4],rows[6],startRunTime,endRunTime)
				print(sqlCommand)
				cursor.execute(sqlCommand)
		
				n=0
				for data in cursor:
					print("   (%d)"%(n+1),data)
			
					with conn.cursor() as cursor:
						sqlCommand="""
						Replace into `dataPlatform`.`{}`(
						`ts`,`siteId`,`name`,`status`
						)values(\'{}\',{},\'{}\',{})
						""".format(rows[3],data[0],rows[0],rows[1],data[3+int(rows[7])])
						print(sqlCommand)
						cursor.execute(sqlCommand)
					n+=1
		cnt+=1
	print("------ %d rows Fetched ------"%cnt)

conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print("------ Connection Closed ------")