import pymysql
import numpy as np
from datetime import datetime, timedelta

nowTime=datetime.now()
print(f"------ Time: {nowTime.strftime('%Y-%m-%d %H:%M:%S')} ------")

def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			user='ecoetl',
			password='ECO4etl'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None

st=(nowTime-timedelta(days=1)).replace(hour=0, minute=0, second=0)
year = st.year
et=nowTime.strftime('%Y-%m-%d 00:00:00')

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="select siteId, name, nameDesc, tableDesc from mgmtETL.NameList where tableDesc='co2' and gatewayId>0"
	
	cursor.execute(sqlCommand)

	for rows in cursor:
		sId=rows[0]
		name=rows[1]
		print(f"----- Processing {sId} {name} -----")
		data_list = []
		#with conn.cursor() as cursor:
		#	sqlCommand=sql('Max(co2)', sId, name, st, et)
		#	cursor.execute(sqlCommand)
		#	co2Max=cursor.fetchone()
		#	if co2Max==None:
		#		continue
		#	else:
		#		co2Max=co2Max[0]
		#with conn.cursor() as cursor:
		#	sqlCommand=sql('Min(co2)', sId, name, st, et)
		#	cursor.execute(sqlCommand)
		#	co2Min=cursor.fetchone()
		#	if co2Min==None:
		#		continue
		#	else:
		#		co2Min=co2Min[0]
		#with conn.cursor() as cursor:
		#	sqlCommand=sql('count(*)', sId, name, st, et)
		#	cursor.execute(sqlCommand)
		#	number=cursor.fetchone()
		#	if number[0]==0:
		#		continue
		#	else:
		#		num=(1 if number[0]==1 else round(number[0]/2))
		#with conn.cursor() as cursor:
		#	sqlCommand=f" \
		#	select * \
		#	from \
		#		( \
		#		select * from dataPlatform.co2 \
		#		where siteId={sId} and name=\'{name}\' and ts>=\'{st}\' and ts<\'{et}\' \
		#		order by co2 desc \
		#		limit {num} \
		#		) as nwetable \
		#	order by co2 \
		#	limit 1 \
		#	"
		#	cursor.execute(sqlCommand)
		#	data=cursor.fetchone()
		#	
		#	date=data[0].strftime('%Y-%m-%d')
		#	co2Median=data[3]
		#with conn.cursor() as cursor:
		#	sqlCommand="""
		#	replace into `reportPlatform{}`.`Dco2`(
		#	`date`,`siteId`,`name`,`co2Min`,`co2Median`,`co2Max`
		#	) Values(\'{}\',{},\'{}\',{},{},{})
		#	""".format(year,date,sId,name,co2Min,co2Median,co2Max)
		#	print(sqlCommand)
		#	cursor.execute(sqlCommand)
		with conn.cursor() as cursor:
			sqlCommand = f"select co2 from dataPlatform.co2 where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
			cursor.execute(sqlCommand)
			
			if cursor.rowcount == 0:
				print(f"SiteId: {sId} has no data in the day")
				continue
			else:
				for data in cursor:
					if data[0] is not None: data_list.append(data[0])
			
			if len(data_list) != 0:
				print(f"Data Length: {len(data_list)}")
				co2Min = round(np.percentile(np.array(data_list), 0) ,2)
				co225th = round(np.percentile(np.array(data_list), 25) ,2)
				co2Median = round(np.percentile(np.array(data_list), 50) ,2)
				co275th = round(np.percentile(np.array(data_list), 75) ,2)
				co2Max = round(np.percentile(np.array(data_list), 100) ,2)

		with conn.cursor() as cursor:
			replace_sql = f"replace into `reportPlatform{year}`.`Dco2` (`date`, `siteId`, `name`, `co2Min`, `co225th`, `co2Median`, `co275th`, `co2Max`) Values ('{st.strftime('%Y-%m-%d')}', {sId}, '{name}', {co2Min}, {co225th}, {co2Median}, {co275th}, {co2Max})"
			print(replace_sql)
			cursor.execute(replace_sql)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection close ------")