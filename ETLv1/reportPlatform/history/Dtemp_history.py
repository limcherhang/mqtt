import pymysql
from datetime import datetime, timedelta
import sys
import statistics

def sql(string,year,mon,siteId,name,st,et):
	cursor=conn.cursor()
	sqlCommand=f"""
	Select {string} From dataPlatform{year}.temp_{mon} 
	Where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
	"""
	cursor.execute(sqlCommand)
	#print(sqlCommand)
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
	st=datetime(2023, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d 00:00:00')
	et=datetime(2023, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d 00:00:00')
	year=st.strftime('%Y')
	mon=st.strftime('%m')
	date=st.strftime('%Y-%m-%d')
	print("-----程式執行時間不含結束時間-----")

programStartTime=datetime.now()
nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:%S'))

conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc='temp' and gatewayId>0 and siteId=65 and protocol is NOT NULL #siteId=20 
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print(rows)
		data_list=[]
		sId=rows[0]
		name=rows[1]
		tempMax=0
		tempMin=0
		with conn.cursor() as cursor:
			
			tempMax=(sql('Max(temp)',year,mon,sId,name,st,et)).fetchone()
			if tempMax[0] is None:
				continue
			else:
				tempMax=tempMax[0]

			tempMin=(sql('Min(temp)',year,mon,sId,name,st,et)).fetchone()	
			if tempMin[0] is None:
				continue
			else:
				tempMin=tempMin[0]
			 
			for data in sql('temp',year,mon,sId,name,st,et):
				data_list.append(data[0])
			tempMedian=statistics.median(data_list)
		
		with conn.cursor() as data_cursor:
			insert_sql=f"""
			Replace into `reportPlatform{year}`.`Dtemp` (
			`date`,`siteId`,`name`,`tempMin`,`tempMedian`,`tempMax`
			)values(\'{date}\',{sId},\'{name}\',{round(tempMin,2)},{round(tempMedian,2)},{round(tempMax,2)}
			)"""
			print(insert_sql)
			#data_cursor.execute(insert_sql)
			
		cnt+=1
	
	print("------ Fetching %d rows Succeed ------"%cnt)

#更新DB SQL指令
conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")