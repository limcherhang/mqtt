import pymysql
from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta
import sys


date = sys.argv[1]
data =  date.split('-')
nowTime=datetime.now().replace(year=int(data[0]),month=int(data[1]),day=1,hour=0,minute=0,second=0,microsecond=0)
currentdate = datetime.now().replace(hour=0,minute=0,second=0,microsecond=0)
startRunTime=nowTime
year = nowTime.strftime('%Y')
endRunTime=(startRunTime + relativedelta(months=1))
if endRunTime > currentdate:
	endRunTime = currentdate
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
	from dataPlatform2023.{}_07
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
	SELECT name FROM mgmtETL.Calculation where siteId = 87; #SELECT name FROM mgmtETL.NameList where siteId = 87 and tableDesc='power'; #SELECT name FROM mgmtETL.Calculation where siteId = 87;
	"""
	cursor.execute(sqlCommand)
	for rows in cursor:
		name_list.append(rows[0])

for name in name_list:
	stime = startRunTime
	etime = (startRunTime + timedelta(days=1))

	while etime <= endRunTime:
		with conn.cursor() as cursor:
			cursor.execute(sql('power',87,name,stime,etime,'order by ts desc'))
			for data in cursor:
				ts = data[0]
				energyConsumption=('NULL' if data[7] is None else data[7])
				total=('NULL' if data[8] is None else data[8])
				with conn.cursor() as cursor:
					sqlCommand="""
					Replace into `reportPlatform{}`.`{}` (
					`date`,`siteId`,`name`,`energyConsumption`,`total`
					)values(\'{}\',{},\'{}\',{},{})
					""".format(year,'Dpower',ts.strftime('%Y-%m-%d'),87,name,energyConsumption,total)
					
					cursor.execute(sqlCommand)
		stime = etime
		etime = etime + timedelta(days=1)


conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
