import pymysql
from datetime import datetime, timedelta
import sys
import statistics

def sql(string, year, mon, sId, name, st, et):
	cursor=conn.cursor()
	sqlCommand=f"select {string} from dataPlatform{year}.ammonia_{mon} \
	where siteId={sId} and name='{name}' and ts>='{st}' and ts<'{et}' "
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
	sqlCommand="\
		select \
		siteId, name, nameDesc, tableDesc \
		from mgmtETL.NameList \
		where tableDesc='ammonia' and gatewayId>0 and protocol is NOT NULL \
		"
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print(f"{(cnt+1)} {rows}")
		data_list=[]
		sId=rows[0]
		name=rows[1]
		
		with conn.cursor() as cursor:
			NH3Max=(sql('Max(NH3)',year,mon,sId,name,st,et)).fetchone()
			if NH3Max[0] is None:
				continue
			else:
				NH3Max=NH3Max[0]

			NH3Min=(sql('Min(NH3)',year,mon,sId,name,st,et)).fetchone()
			if NH3Min[0] is None:
				continue
			else:
				NH3Min=NH3Min[0]
			
			for data in sql('NH3',year,mon,sId,name,st,et):
				data_list.append(data[0])
			NH3Median=statistics.median(data_list)
		
		with conn.cursor() as data_cursor:
			insert_sql=f"""
			Replace into `reportPlatform2021`.`Dammonia` (
			`date`, `siteId`, `name`, `NH3Min`, `NH3Median`, `NH3Max`
			) Values(\'{date}\', {sId}, \'{name}\', {round(NH3Min,2)}, {round(NH3Median,2)}, {round(NH3Max,2)}
			"""
			print(insert_sql)
			#data_cursor.execute(insert_sql)
		
		cnt+=1

	print(f"----- Fetching {cnt} rows Succeed -----")

conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")