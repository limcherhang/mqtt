import pymysql
from datetime import datetime, timedelta
import sys

month = sys.argv[1]
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


conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand=f"""
	SELECT name,sum(energyConsumption),max(total) 
	FROM reportPlatform{year}.Dpower where month(date) = {month} and siteId = 87
	group by name;
	"""
	cursor.execute(sqlCommand)
	for rows in cursor:
		name = rows[0]
		energy = rows[1]
		total = ('null' if rows[2] is None else rows[2])
		with conn.cursor() as cursor:
			sqlCommand="""
			Replace into `reportPlatform{}`.`{}` (
			`month`,`updateDate`,`siteId`,`name`,`energyConsumption`,`total`
			)values({},\'{}\',{},\'{}\',{},{})
			""".format(year,'Mpower',month,(nowTime-timedelta(days=1)).strftime('%Y-%m-%d'),87,name,energy,total)

			print(sqlCommand)
			cursor.execute(sqlCommand)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
