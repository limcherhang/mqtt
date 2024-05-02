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
			user='ecoprog',
			password='ECO4prog'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc=%s and gatewayId>0
	"""
	cnt=0
	cursor.execute(sqlCommand,('temp',))
	for rows in cursor:
		sId = rows[0]
		name = rows[1]
		print(f"----- Processing {sId} {name} -----")
		data_list = []
		with conn.cursor() as cursor:
			#cursor.execute(sql('MAX(temp)',rows[3],rows[0],rows[1],st,et))
			#max=cursor.fetchone()
			##print(max)
			#if max==None:
			#	continue
			##cursor.execute(rows[3],
			##print(sql('MAX(temp)',rows[3],rows[0],rows[1],st,et))#,
			##print(sql('MIN(temp)',rows[3],rows[0],rows[1],st,et))
			#
			#cursor.execute(sql('MIN(temp)',rows[3],rows[0],rows[1],st,et))
			#min=cursor.fetchone()
			##print(min)
			#if min==None:
			#	continue
			#sqlCommand="""
			#Select count(*) From dataPlatform.{}
			#Where siteId='{}' and name='{}' and ts>='{}' and ts<'{}'
			#order by ts asc
			#""".format(rows[3],rows[0],rows[1],st,et)
			#
			#cursor.execute(sqlCommand)
			#number=cursor.fetchone()
			#if number[0]==0:
			#	continue
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
			#	where siteId={} and name='{}' and ts>='{}' and ts<'{}'
			#	order by temp desc
			#	limit {}
			#	) as newtable
			#order by temp
			#limit 1
			#""".format(rows[3],rows[0],rows[1],st,et,num)
			##print(sqlCommand)
			#cursor.execute(sqlCommand)
			#data=cursor.fetchone()
			sqlCommand = f"select temp from dataPlatform.temp where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'"
			#cursor.execute(sql('temp', rows[3], rows[0], rows[1], st, et))
			cursor.execute(sqlCommand)
			
			if cursor.rowcount == 0:
				print(f"SiteId: {sId} has no data in the day")
				continue
			else:
				for data in cursor:
					if data[0] is not None: data_list.append(data[0])
			
			if len(data_list) != 0:
				print(f"Data Length: {len(data_list)}")
				tempMin = round(np.percentile(np.array(data_list), 0) ,2)
				temp25th = round(np.percentile(np.array(data_list), 25) ,2)
				tempMedian = round(np.percentile(np.array(data_list), 50) ,2)
				temp75th = round(np.percentile(np.array(data_list), 75) ,2)
				tempMax = round(np.percentile(np.array(data_list), 100) ,2)

		with conn.cursor() as cursor:
			#sqlCommand="""
			#Replace into `reportPlatform{}`.`{}` (
			#`date`,`siteId`,`name`,`tempMin`,`temp25th`,`tempMedian`,`temp75th`,`tempMax`
			#)values(\'{}\',{},\'{}\',{},{},{})
			#""".format(year,"D"+rows[3],data[0].strftime('%Y-%m-%d'),data[1],data[2],round(min[0],2),temp25th,round(data[3],2),temp75th,round(max[0],2)
			replace_sql = f"replace into `reportPlatform{year}`.`Dtemp` (`date`, `siteId`, `name`, `tempMin`, `temp25th`, `tempMedian`, `temp75th`, `tempMax`) Values ('{st.strftime('%Y-%m-%d')}', {sId}, '{name}', {tempMin}, {temp25th}, {tempMedian}, {temp75th}, {tempMax})"
			print(replace_sql)
			cursor.execute(replace_sql)

		cnt+=1
	
	print("------ Fetching %d rows Succeed ------"%cnt)
	
conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection close ------")