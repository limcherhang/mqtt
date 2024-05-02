import pymysql
from datetime import datetime, timedelta
import sys
import statistics

def sql(string,year,mon,sId,name,st,et):
	cursor=conn.cursor()
	sqlCommand=f"""
	Select {string} 
	From dataPlatform{year}.humidity_{mon} 
	Where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
	"""
	print(sqlCommand)
	cursor.execute(sqlCommand)
	return cursor
	
def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			#host='192.168.1.62',
			user='ecoetl',
			password='ECO4etl'
		)
		print("------ Connection Succeed ------")
		return conn
	except Exception as ex:
		print("------ Connection Failed ------\n",str(ex))
	return None


if len(sys.argv)!=5:
    print(len(sys.argv))
    print("Type Error:參數不夠,含程式名稱需要5個\n 順序: python3 程式名稱 開始月份 開始日期 結束月份 結束日期")
    sys.exit()
else:
	st=datetime(2021, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d 00:00:00')
	et=datetime(2021, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d 00:00:00')
	year=st.strftime('%Y')
	mon=st.strftime('%m')
	date=st.strftime('%Y-%m-%d')
	print("-----程式執行時間不含結束時間-----")

print(f" from {st} to {et}")

programStartTime = datetime.now()
nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc='humidity' and gatewayId>0 and protocol is NOT NULL
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print(f"{(cnt+1)} ",rows)
		sId=rows[0]
		name=rows[1]
		data_list=[]
		
		with conn.cursor() as cursor:
			
			humidityMax=(sql('Max(humidity)',year,mon,sId,name,st,et)).fetchone()
			if humidityMax is None:
				print(f" {sId} {name} has no max data")
				continue
			else:
				humidityMax=humidityMax[0]

			humidityMin=(sql('Min(humidity)',year,mon,sId,name,st,et)).fetchone()
			if humidityMin is None:
				print(f" {sId} {name} has no min data")
				continue
			else:
				humidityMin=humidityMin[0]
			
			
			'''
			sqlCommand="""
			Select count(*) From dataPlatform2021.{}
			Where name='{}' and siteId={} and ts>='{}' and ts<'{}'
			""".format(rows[3]+'_'+mon,rows[1],rows[0],st.strftime('%Y-%m-%d 00:00:00'),et.strftime('%Y-%m-%d 00:00:00'))
			cursor.execute(sqlCommand)
			number=cursor.fetchone()
			if number[0]==0:
				continue
			else:
				if number[0]==1:
					num=1
				else:
					num=round(number[0]/2)
			sqlCommand="""
			Select *
			From
				(
				Select * from dataPlatform2021.{}
				where name='{}' and siteId={} and 
				ts>='{}' and ts<'{}'
				order by humidity desc
				limit {}
				) as newtable
			order by humidity 
			limit 1
			""".format(rows[3]+'_'+mon,rows[1],rows[0],st.strftime('%Y-%m-%d 00:00:00'),et.strftime('%Y-%m-%d 00:00:00'),num)
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			data=cursor.fetchone()
			#print(data)
			'''
			for data in sql('humidity',year,mon,sId,name,st,et):
				data_list.append(data[0])
			if len(data_list)==0:
				print(f" {sId} {name} has no  data")
				continue
			else:
				humidityMedian=statistics.median(data_list)

		with conn.cursor() as data_cursor:
			insert_sql=f"""
			Replace into `reportPlatform{year}`.Dhumidity (
			`date`,`siteId`,`name`,`humidityMin`,`humidityMedian`,`humidityMax`
			)values(\'{date}\',{sId},\'{name}\', {round(humidityMin,2)}, {round(humidityMedian,2)}, {round(humidityMax,2)})
			"""
			print(insert_sql)
			#data_cursor.execute(insert_sql)
			
		cnt+=1
	
	print("------ Fetching %d rows Succeed ------"%cnt)
	
conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")