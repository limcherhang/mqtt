import pymysql
from datetime import datetime, timedelta

nowTime=datetime.now()
print(f"------ Time: {nowTime.strftime('%Y-%m-%d %H:%M:%S')} ------")

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

def sql(string, sId, name, start, end):
	sqlCommand=f"select {string} from dataPlatform.ammonia where siteId={sId} and name=\'{name}\' and ts>=\'{start}\' and ts<\'{end}\'"
	return sqlCommand

st=(nowTime-timedelta(days=1)).strftime('%Y-%m-%d 00:00:00')
year = st[:4]
et=nowTime.strftime('%Y-%m-%d 00:00:00')

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="select siteId, name, nameDesc, tableDesc from mgmtETL.NameList where tableDesc='ammonia' and gatewayId>0"
	
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print(f"{cnt+1} {rows}")
		sId=rows[0]
		name=rows[1]
		with conn.cursor() as cursor:
			sqlCommand=sql('Max(NH3)', sId, name, st, et)
			cursor.execute(sqlCommand)
			NH3Max=cursor.fetchone()
			if NH3Max==None:
				continue
			else:
				NH3Max=NH3Max[0]
		with conn.cursor() as cursor:
			sqlCommand=sql('Min(NH3)', sId, name, st, et)
			cursor.execute(sqlCommand)
			NH3Min=cursor.fetchone()
			if NH3Min==None:
				continue
			else:
				NH3Min=NH3Min[0]
		with conn.cursor() as cursor:
			sqlCommand=sql('count(*)', sId, name, st, et)
			cursor.execute(sqlCommand)
			number=cursor.fetchone()
			if number[0]==0:
				continue
			else:
				num=(1 if number[0]==1 else round(number[0]/2))
		with conn.cursor() as cursor:
			sqlCommand=f" \
			select * \
			from \
				( \
				select * from dataPlatform.ammonia \
				where siteId={sId} and name=\'{name}\' and ts>=\'{st}\' and ts<\'{et}\' \
				order by NH3 desc \
				limit {num} \
				) as nwetable \
			order by NH3 \
			limit 1 \
			"
			cursor.execute(sqlCommand)
			data=cursor.fetchone()
			
			date=data[0].strftime('%Y-%m-%d')
			NH3Median=data[3]
		with conn.cursor() as cursor:
			sqlCommand="""
			replace into `reportPlatform{}`.`Dammonia`(
			`date`,`siteId`,`name`,`NH3Min`,`NH3Median`,`NH3Max`
			) Values(\'{}\',{},\'{}\',{},{},{})
			""".format(year,date,sId,name,NH3Min,NH3Median,NH3Max)
			print(sqlCommand)
			cursor.execute(sqlCommand)
		
		cnt+=1
	print(f"------ Fetching {cnt} rows Succeed ------")

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection close ------")