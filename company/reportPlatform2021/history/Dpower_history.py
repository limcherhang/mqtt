import pymysql
from datetime import datetime, timedelta
import sys

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


#if len(sys.argv)!=5:
#	print(len(sys.argv))
#	print("Type Error:參數不夠,含程式名稱需要5個\n 順序: python3 程式名稱 開始月份 開始日期 結束月份 結束日期")
#	sys.exit()
#else:
#	st=datetime(datetime.now().year, int(sys.argv[1]), int(sys.argv[2]))
#	et=datetime(datetime.now().year, int(sys.argv[3]), int(sys.argv[4]))
#	year=st.strftime('%Y')
#	mon=st.strftime('%m')
#	date=st.strftime('%Y-%m-%d')
#	print("-----程式執行時間不含結束時間-----")

st = datetime(2023, 5, 15)
et = datetime(2023, 5, 16)
year = 2023
mon = 5
date = st.strftime('%Y-%m-%d')

print(f" from {st} to {et}")

programStartTime=datetime.now()
nowTime=datetime.now()
print("------ Time: %s ------"%nowTime.strftime('%Y-%m-%d %H:%M:00'))


conn=connectDB()
with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, nameDesc, tableDesc
	From mgmtETL.NameList
	Where tableDesc='power' and gatewayId>0 and siteId=65 and protocol is NOT NULL
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		
		sId=rows[0]
		name=rows[1]
		data_list=[]
		
		with conn.cursor() as cursor:
			sqlCommand=f"\
				select * from dataPlatform{year}.power_05 \
				where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}' and energyConsumed is not NULL and total is not NULL \
				order by ts desc \
				limit 1 \
				"
			cursor.execute(sqlCommand)
			#print(sqlCommand)

			for data in cursor:
				print(data)
				ts=data[0]
				energyConsumption=('NULL' if data[7] is None else data[7])
				total=('NULL' if data[7] is None else data[8])
				
				with conn.cursor() as data_cursor:
					insert_sql=f"""
					Replace into `reportPlatform{year}`.`Dpower` (
					`date`,`siteId`,`name`,`energyConsumption`,`total`
					)values(\'{date}\',{sId},\'{name}\', {energyConsumption}, {total})
					"""
					print(insert_sql)
					data_cursor.execute(insert_sql)
			
		cnt+=1
	
	print("------ Fetching %d rows Succeed ------"%cnt)

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------\n\n")
