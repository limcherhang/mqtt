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
			read_default_file = '~/.my.cnf'
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
	where siteId={} and name='{}' and ts>='{}' and ts<'{}' and energyConsumed is not NULL 
	{}
	limit 1
	""".format(tablename,id,name,start,end,string)
	print(sqlCommand)
	return sqlCommand

name_list = ['power#14']
conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	SELECT name FROM mgmtETL.Calculation where siteId = 87;
	"""
	cursor.execute(sqlCommand)
	for rows in cursor:
		name_list.append(rows[0])

for name in name_list:
	with conn.cursor() as cursor:
		cursor.execute(sql('power',87,name,startRunTime,endRunTime,'order by ts desc'))
		for data in cursor:
			energyConsumption=('NULL' if data[7] is None else data[7])
			total=('NULL' if data[8] is None else data[8])
			with conn.cursor() as cursor:
				sqlCommand="""
				Replace into `reportPlatform{}`.`{}` (
				`date`,`siteId`,`name`,`energyConsumption`,`total`
				)values(\'{}\',{},\'{}\',{},{})
				""".format(year,'Dpower',(nowTime-timedelta(days=1)).strftime('%Y-%m-%d'),87,name,energyConsumption,total)
				print(sqlCommand)
				cursor.execute(sqlCommand)


conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
