import pymysql
from datetime import datetime, timedelta

nowTime = datetime.now()
print(f"------ Time: {nowTime.strftime('%Y-%m-%d %H:%M:%S')} ------")

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

startRunTime=(nowTime-timedelta(minutes=3)).strftime('%Y-%m-%d %H:%M:00')
endRunTime=nowTime.strftime('%Y-%m-%d %H:%M:00')
print(f"Searching from {startRunTime} to {endRunTime}")

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommad=f" \
	select siteId, name, nameDesc, tableDesc, gatewayId, protocol, dataETLName \
	from mgmtETL.NameList \
	where name like 'ammonia#%' and protocol is NOT NULL and gatewayId>0 \
	"
	cnt=0
	cursor.execute(sqlCommad)
	
	for rows in cursor:
		print(f"{cnt+1} {rows}")
		sId=rows[0]
		name=rows[1]
		nameDesc=rows[2]
		table=rows[3]
		gId=rows[4]
		dataETLName=rows[6]
		
		with conn.cursor() as cursor:
			sqlCommad=f" \
			select ts, NH3 \
			from dataETL.ammonia \
			where gatewayId={gId} and name=\'{dataETLName}\' and ts>\'{startRunTime}\' and ts<\'{endRunTime}' \
			order by ts desc \
			"
			#print(sqlCommad)
			cursor.execute(sqlCommad)
			
			n=0
			for data in cursor:
				print(f"({ (n+1)}) {data}")
				ts=data[0]
				NH3=data[1]
				
				with conn.cursor() as cursor:
					sqlCommad=""" 
					replace into `dataPlatform`.`ammonia`( 
					`ts`,`siteId`,`name`,`NH3` 
					) Values(\'{}\',{},\'{}\',{}) 
					""".format(ts, sId, name, NH3)
					print(sqlCommad)
					cursor.execute(sqlCommad)
				n+=1

		cnt+1
	
	print(f"------ {cnt} rows Fetched ------")

conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print("------ Connection Closed ------")