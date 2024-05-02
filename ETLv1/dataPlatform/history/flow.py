import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
lastDay=nowTime-timedelta(days=1)
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))


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

#st=datetime(2021, 6, 16, 23, 57)
#et=datetime(2021, 6, 17, 0, 0)
#st=(nowTime-timedelta(minutes=3))
#et=nowTime

st = datetime(2023, 5, 15, 00, 0, 0)
stTotal = datetime(2023, 5, 15, 0, 0, 0)
print ("Time st :", st)
et = datetime(2023, 5, 16, 0, 0, 0)
#et = nowTime.strftime('%Y-%m-15 10:18:10') 
print ("Time et :", et)

print("Selecting from %s to %s ..."%(st.strftime('%Y-%m-%d %H:%M:00'),et.strftime('%Y-%m-%d %H:%M:00')))

siteId=[]
name=[]
gId=[]
dataETLName=[]

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc, gatewayId, protocol, dataETLName, dataETLCombination
	From mgmtETL.NameList
	Where tableDesc='flow' and protocol='Combination' and gatewayId>0 and protocol is NOT NULL
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		#print(str.lower(rows[7][2:6])) = flow
		#print(str.lower(rows[7][12:24])) = waterquality
		siteId.append(rows[0])
		name.append(rows[1])
		gId.append(rows[4])
		dataETLName.append(rows[6])
		### previous total0000
		with conn.cursor() as cursor:
			sqlCommand="""
			Select flowTotalPositive From dataETL.flow
			Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
			order by ts asc
			limit 1
			""".format(rows[4],rows[7][2:8],lastDay.strftime('%Y-%m-%d 00:00:00'),nowTime.strftime('%Y-%m-%d 00:00:00'))
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			preTotal0000=cursor.fetchone()
		### current total0000
		with conn.cursor() as cursor:
			sqlCommand="""
			Select flowTotalPositive From dataETL.flow
			Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
			order by ts asc
			limit 1
			""".format(rows[4],rows[7][2:8],nowTime.strftime('%Y-%m-%d 00:00:00'),nowTime.strftime('%Y-%m-%d %H:%M:%S'))
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			curTotal0000=cursor.fetchone()
			
		with conn.cursor() as cursor:
			sqlCommand="""
			Select * From dataETL.{}
			Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
			""".format(str.lower(rows[7][2:6]),rows[4],rows[7][2:8],st,et)
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			n=0
			for data in cursor:
				print("(%d) "%(n+1),data)
				with conn.cursor() as cursor:
					sqlCommand="""
					Select liquidLevel From dataETL.waterQuality 
					Where gatewayId={} and name='{}' and ts='{}'
					""".format(rows[4],rows[7][12:26],data[0])
					#print(sqlCommand)
					cursor.execute(sqlCommand)
					level=cursor.fetchone()
					if level==None:
						liquidLevel='NULL'
					else:
						liquidLevel=level[0]
				
				with conn.cursor() as cursor:
					if st.strftime('%d')<et.strftime('%d'):
						if data[0].strftime('%d')==st.strftime('%d'):
							total0000=preTotal0000[0]
						elif data[0].strftime('%d')==et.strftime('%d'):
							total0000=curTotal0000[0]
					else:
						total0000=curTotal0000[0]
					
					waterConsumed=data[4]-total0000
					
					sqlCommand="""
					Replace into `dataPlatform`.`flow` (
					`ts`,`siteId`,`name`,`flowRate`,`liquidLevel`,`waterConsumed`,`total`
					)values(\'{}\',{},\'{}\',{},{},{},{})
					""".format(data[0],rows[0],rows[1],data[3],liquidLevel,round(waterConsumed,2),'NULL')
					print(sqlCommand)
					cursor.execute(sqlCommand)
				n+=1
			
		cnt+=1
	
	print("------ %d rows Fetched ------"%cnt)
conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print("------ Connection closed ------")