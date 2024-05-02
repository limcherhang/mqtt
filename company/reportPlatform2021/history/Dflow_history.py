import pymysql
from datetime import datetime, timedelta
import sys
import statistics


def sql(string,year,mon,sId,name,st,et):
	cursor=conn.cursor()
	sqlCommand=f"""
	Select {string} From dataPlatform{year}.flow_{mon}
	Where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
	"""
	#print(sqlCommand)
	cursor.execute(sqlCommand)
	return cursor
	
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


if len(sys.argv)!=5:
    print(len(sys.argv))
    print("Type Error:參數不夠,含程式名稱需要5個\n 順序: python3 程式名稱 開始月份 開始日期 結束月份 結束日期")
    sys.exit()
else:
	st=datetime(2023, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d %H:00:00')
	et=datetime(2023, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d %H:00:00')
	year=st.strftime('%Y')
	mon=st.strftime('%m')
	print("-----程式執行時間不含結束時間-----")

print(f" from {st} to {et}")

programStartTime=datetime.now()
nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

conn=connectDB('127.0.0.1')
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList 
	Where tableDesc='flow' and gatewayId>0 and siteId=65
	"""
	cursor.execute(sqlCommand)

	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		
		sId=rows[0]
		name=rows[1]
		data_list=[]
		
		with conn.cursor() as cursor:	
			###searching lastest data
			sqlCommand=f"""
			Select * From dataPlatform{year}.flow_{mon} 
			Where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
			order by ts desc
			limit 1
			"""
			#print(sqlCommand)
			cursor.execute(sqlCommand)

			for data in cursor:
				print("  ",data)
				ts=data[0]
				waterConsumption=('NULL' if data[5] is None else data[5])
				total=('NULL' if data[6] is None else data[6])
				
				flowMax=(sql('Max(flowRate)',year,mon,sId,name,st,et)).fetchone()
				if flowMax[0] is None:
					flowMax = 'NULL'
				else:
					flowMax = round(flowMax[0], 2)
				
				flowMin=(sql('Min(flowRate)',year,mon,sId,name,st,et)).fetchone()
				if flowMin[0] is None:
					flowMin = 'NULL'
				else:
					flowMin = round(flowMin[0], 2)
				'''
				number=(sql('count(*)',year,mon,sId,name,st,et)).fetchone()
				if number[0]==0:
					continue
				else:
					if number[0]==1:
						num=1
					else:
						num=round(number[0]/2)
				'''
				for data in sql('flowRate',year,mon,sId,name,st,et):
					if data[0] is None:
						continue
					data_list.append(data[0])
				
				if len(data_list) == 0:
					flowMedian = 'NULL'
				else:
					flowMedian = statistics.median(data_list)
					flowMedian = round(flowMedian, 2)
					
				#####算flow medain舊的方式
				'''
				with conn.cursor() as cursor:
					sqlCommand=f"""
					Select flowRate
					From (
						Select * From dataPlatform{year}.flow_{mon}
						Where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
						order by flowRate desc
						limit {num}
					) as newtable
					order by flowRate 
					limit 1
					"""
					cursor.execute(sqlCommand)
					median=cursor.fetchone()
					print(f"median: {median}")
				'''
				with conn.cursor() as data_cursor:
					insert_sql=f"""
					Replace into `reportPlatform{year}`.`Dflow`(
					`date`,`siteId`,`name`,`waterConsumption`,`total`,`flowMin`,`flowMedian`,`flowMax`
					)values(\'{ts.strftime('%Y-%m-%d')}\',{sId},\'{name}\', {waterConsumption}, {total}, {flowMin}, {flowMedian}, {flowMax})
					"""
					print(insert_sql)
					data_cursor.execute(insert_sql)
		cnt+=1
	
	print("------ %d rows Fetched ------"%cnt)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")