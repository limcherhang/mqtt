import pymysql
from datetime import datetime, timedelta

nowTime = datetime.now().replace(microsecond=0)
lastDay = (nowTime-timedelta(days=1)).strftime('%Y-%m-%d 00:00:00')
year = lastDay[:4]

print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:00'))

def sql(string,table,site,name,start,end):
	sqlCommand="""
	Select {} From dataPlatform.{}
	Where siteId={} and name='{}' and ts>='{}' and ts<'{}'
	""".format(string,table,site,name,start,end)
	return sqlCommand
	
def connectDB(host):
	try:
		conn=pymysql.connect(
			host = host, 
			read_default_file = '~/.my.cnf'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None

conn=connectDB('127.0.0.1')
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList 
	Where tableDesc='flow' and gatewayId>0
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		
		with conn.cursor() as cursor:
			
			###searching lastest data
			sqlCommand="""
			Select * From dataPlatform.{} 
			Where siteId={} and name='{}' and ts>='{}' and ts<'{}'
			order by ts desc
			limit 1
			""".format(rows[3],rows[0],rows[1],lastDay,nowTime.strftime('%Y-%m-%d 00:00:00'))
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			
			for data in cursor:
				print("  ",data)
				if data[5] is None:
					waterConsumption = 'NULL'
				else:
					waterConsumption = data[5]
					
				cursor.execute(sql('Max(flowRate)',rows[3],rows[0],rows[1],lastDay,nowTime.strftime('%Y-%m-%d 00:00:00')))
				max=cursor.fetchone()
				if max[0] is None:
					max = 'NULL'
				else:
					max = round(max[0], 2)

				cursor.execute(sql('Min(flowRate)',rows[3],rows[0],rows[1],lastDay,nowTime.strftime('%Y-%m-%d 00:00:00')))
				min=cursor.fetchone()
				if min[0] is None:
					min = 'NULL'
				else:
					min = round(min[0], 2)
				
				cursor.execute(sql('count(*)',rows[3],rows[0],rows[1],lastDay,nowTime.strftime('%Y-%m-%d 00:00:00')))
				number=cursor.fetchone()
				if number[0]==0:
					continue
				else:
					if number[0]==1:
						num=1
					else:
						num=round(number[0]/2)
				with conn.cursor() as cursor:
					sqlCommand="""
					Select flowRate
					From (
						Select * From dataPlatform.{}
						Where siteId={} and name='{}' and ts>='{}' and ts<'{}'
						order by flowRate desc
						limit {}
					) as newtable
					order by flowRate
					limit 1
					""".format(rows[3],rows[0],rows[1],lastDay,nowTime.strftime('%Y-%m-%d 00:00:00'),num)
					#print(sqlCommand)
					cursor.execute(sqlCommand)
					median=cursor.fetchone()
					if median[0] is None:
						median = 'NULL'
					else:
						median = round(median[0], 2)
				
				with conn.cursor() as cursor:
					if data[6]==None:
						total='Null'
					else:
						total=data[6]
					sqlCommand="""
					Replace into `reportPlatform{}`.`{}`(
					`date`,`siteId`,`name`,`waterConsumption`,`total`,`flowMin`,`flowMedian`,`flowMax`
					)values(\'{}\',{},\'{}\',{},{},{},{},{})
					""".format(year,'D'+rows[3],data[0].strftime('%Y-%m-%d'),rows[0],rows[1],waterConsumption,total,min,median,max)
					print(sqlCommand)
					cursor.execute(sqlCommand)
		cnt+=1
	
	print("------ %d rows Fetched ------"%cnt)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")
