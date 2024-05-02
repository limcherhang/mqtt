import pymysql
import numpy as np
from datetime import datetime, timedelta

nowTime=datetime.now()

print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

st=(nowTime-timedelta(days=1)).replace(hour=0, minute=0, second=0)
year = st.year
et=nowTime.strftime('%Y-%m-%d 00:00:00')

#def sql(string,table,siteId,name,start,end):
#	sqlCommand="""
#	Select {} 
#	From dataPlatform.{} 
#	Where siteId={} and name='{}' and ts>='{}' and ts<'{}'
#	""".format(string,table,siteId,name,start,end)
#	return sqlCommand
	
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

print("Searching data from %s to %s ..."%(st,et))

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc=%s and gatewayId>0
	"""
	cursor.execute(sqlCommand,('humidity',))
	
	for rows in cursor:
		print(rows)
		sId = rows[0]
		name = rows[1]
		print(f"----- Processing {sId} {name} -----")
		data_list = []
		with conn.cursor() as cursor:
			#cursor.execute(sql('MAX(humidity)',rows[3],rows[0],rows[1],st,et))
			#max=cursor.fetchone()
			#if max==None:
			#	continue
			#
			#cursor.execute(sql('MIN(humidity)',rows[3],rows[0],rows[1],st,et))
			#min=cursor.fetchone()
			#if min==None:
			#	continue
			##print(min[0])
			#
			#sqlCommand="""
			#Select count(*) From dataPlatform.{}
			#Where name='{}' and siteId={} and ts>='{}' and ts<'{}'
			#order by ts asc
			#""".format(rows[3],rows[1],rows[0],st,et)
			#cursor.execute(sqlCommand)
			#number=cursor.fetchone()
			#if number[0]==0:
			#		continue
			#else:
			#	if number[0]==1:
			#		num=1
			#	else:
			#		num=round(number[0]/2)
			#
			#sqlCommand="""
			#Select *
			#From
			#	(
			#	Select * from dataPlatform.{}
			#	where name='{}' and siteId={} and 
			#	ts>='{}' and ts<'{}'
			#	order by humidity desc
			#	limit {}
			#	) as newtable
			#order by humidity
			#limit 1
			#""".format(rows[3],rows[1],rows[0],st,et,num)
			##print(sqlCommand)
			#cursor.execute(sqlCommand)
			#data=cursor.fetchone()	
			sqlCommand = f"select humidity from dataPlatform.humidity where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
			cursor.execute(sqlCommand)

			if cursor.rowcount == 0:
				print(f"SiteId: {sId} has no data in the day")
				continue
			else:
				for data in cursor:
					if data[0] is not None: data_list.append(data[0])

			if len(data_list) != 0:
				#print(f"Data Length: {len(data_list)}")
				humidityMin = round(np.percentile(np.array(data_list), 0) ,2)
				humidity25th = round(np.percentile(np.array(data_list), 25) ,2)
				humidityMedian = round(np.percentile(np.array(data_list), 50) ,2)
				humidity75th = round(np.percentile(np.array(data_list), 75) ,2)
				humidityMax = round(np.percentile(np.array(data_list), 100) ,2)

		with conn.cursor() as cursor:
			replace_sql = f"replace into `reportPlatform{year}`.`Dhumidity` (`date`, `siteId`, `name`, `humidityMin`, `humidity25th`, `humidityMedian`, `humidity75th`, `humidityMax`) Values ('{st.strftime('%Y-%m-%d')}', {sId}, '{name}', {humidityMin}, {humidity25th}, {humidityMedian}, {humidity75th}, {humidityMax})"
			print(replace_sql)
			cursor.execute(replace_sql)
	
conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")