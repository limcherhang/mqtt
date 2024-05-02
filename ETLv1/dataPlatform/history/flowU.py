import pymysql
from datetime import datetime, timedelta

nowTime = datetime.now()
lastDay = nowTime-timedelta(days=1)
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

siteId=[]
name=[]
gId=[]
dataETLName=[]
latestTotal=[]
preTotal0000=[]
curTotal0000=[]

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select list.siteId, list.name, list.nameDesc, list.tableDesc, list.gatewayId, list.protocol, list.dataETLName, list.dataETLValue, log.totalLatest
	From mgmtETL.NameList as list, mgmtETL.FlowLog as log
	Where (list.siteid=log.siteId and list.gatewayId=log.gatewayId and list.dataETLName=log.name) and
	dataETLName like %s and Protocol='Name' and list.gatewayId=110
	"""
	cursor.execute(sqlCommand,('FlowU%',))
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		siteId.append(rows[0])
		name.append(rows[1])
		gId.append(rows[4])
		dataETLName.append(rows[6])
		latestTotal.append(rows[8])
		
		with conn.cursor() as cursor:
			sqlCommand="""
			Select netAccumulator From dataETL2023.flowU_04
			Where name='{}' and gatewayId={} and ts>='{}' and ts<'{}'
			order by ts asc
			limit 1
			""".format(rows[6],rows[4],lastDay.strftime('%Y-%m-%d 00:00:00'),nowTime.strftime('%Y-%m-%d 00:00:00'))
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			data=cursor.fetchone()
			if data==None:
				preTotal0000.append('None')
			else:
				preTotal0000.append(data[0])
		with conn.cursor() as cursor:
			sqlCommand="""
			Select netAccumulator From dataETL2023.flowU_04
			Where name='{}' and gatewayId={} and ts>='{}' and ts<'{}'
			order by ts
			limit 1
			""".format(rows[6],rows[4],nowTime.strftime('%Y-%m-%d 00:00:00'),nowTime.strftime('%Y-%m-%d %H:%M:00'))
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			data=cursor.fetchone()
			#print(data)
			if data==None:
				curTotal0000.append('None')
			else:
				curTotal0000.append(data[0])
		cnt+=1
print("List of %s netAccumulator at 00:00:\n"%lastDay.strftime('%m/%d'),preTotal0000)
print("List of %s netAccumulator at 00:00:\n"%nowTime.strftime('%m/%d'),curTotal0000)

st=datetime(2023, 4, 3, 0, 0)
et=datetime(2023, 4, 4, 0, 0)
# st=(nowTime-timedelta(minutes=3))
# et=nowTime
print("------ Searching from %s to %s ------"%(st.strftime('%Y-%m-%d %H:%M:00'),et.strftime('%Y-%m-%d %H:%M:00')))

for i in range(len(dataETLName)):
	
	with conn.cursor() as cursor:
		sqlCommand="""
		Select ts, flowRate, netAccumulator From dataETL2023.flowU_04
		Where gatewayId={} and name='{}' and ts>='{}' and ts<'{}'
		order by ts
		""".format(gId[i],dataETLName[i],st,et)
		cursor.execute(sqlCommand)
		print("GatewayId %d %s - siteId %d %s flowLog:%d"%(gId[i],dataETLName[i],siteId[i],name[i],latestTotal[i]))
		for rows in cursor:
			# if st.strftime('%d')<et.strftime('%d'):
				# if rows[0].strftime('%d')==st.strftime('%d'):
					# total0000=preTotal0000[i]
				# elif rows[0].strftime('%d')==et.strftime('%d'):
					# total0000=curTotal0000[i]
			# else:
				# total0000=curTotal0000[i]
                
			total0000=9941851
			print(rows)
			print(total0000)
            
			with conn.cursor() as cursor:
				
				waterConsumed=rows[2]-total0000
				total=rows[2]-latestTotal[i]
				
				sqlCommand="""
				Replace into `dataPlatform`.`flow`(
				`ts`,`siteId`,`name`,`flowRate`,`liquidLevel`,`waterConsumed`,`total`
				)values(\'{}\',{},\'{}\',{:.4f},{},{},{})
				""".format(rows[0],siteId[i],name[i],rows[1],'NULL',waterConsumed,total)
				print(sqlCommand)
				cursor.execute(sqlCommand)
				
				# sqlCommand1="""
				# Replace into `dataPlatform2023`.`flow_04`(
				# `ts`,`siteId`,`name`,`flowRate`,`liquidLevel`,`waterConsumed`,`total`
				# )values(\'{}\',{},\'{}\',{:.4f},{},{},{})
				# """.format(rows[0],siteId[i],name[i],rows[1],'NULL',waterConsumed,total)
				# print(sqlCommand1)
				# cursor.execute(sqlCommand1)
				
print("------ rows: %d ------"%len(dataETLName))
conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print("------ Connection closed ------")
