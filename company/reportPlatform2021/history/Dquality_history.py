import pymysql
from datetime import datetime, timedelta
import sys
import statistics
'''
def replace(table,time,id,name,ph1,ph2,ph3,orp1,orp2,orp3,tds1,tds2,tds3):
	sqlCommand="""
	Replace into reportPlatform2021.{}(
	`date`,`siteId`,`name`,
	`pHMin`,`pHMedian`,`pHMax`,
	`ORPMin`,`ORPMedian`,`ORPMax`,
	`TDSMin`,`TDSMedian`,`TDSMax`
	)Values(\'{}\',{},\'{}\',
	{},{},{},
	{},{},{},
	{},{},{})
	""".format(table,time,id,name,ph1,ph2,ph3,orp1,orp2,orp3,tds1,tds2,tds3)
	print(sqlCommand)
	return sqlCommand
'''
def sql(string,year,mon,sId,name,st,et):
	cursor=conn.cursor()
	sqlCommand=f"""
	Select {string} From dataPlatform{year}.quality_{mon} 
	Where siteid={sId} and name='{name}' and ts>='{st}' and ts<'{et}'
	order by ts asc
	"""
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
	st=datetime(2021, int(sys.argv[1]), int(sys.argv[2]))#.strftime('%Y-%m-%d %H:00:00')
	et=datetime(2021, int(sys.argv[3]), int(sys.argv[4]))#.strftime('%Y-%m-%d %H:00:00')
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
	Select siteId, name, nameDesc, tableDesc, dataETLValue
	From mgmtETL.NameList
	Where tableDesc='quality' and gatewayId>0 and protocol is NOT NULL
	"""
	cursor.execute(sqlCommand)
	
	cnt=0
	for rows in cursor:
		print("%d "%(cnt+1),rows)
		
		data_list=[]
		sId=rows[0]
		name=rows[1]
		etlValue=int(rows[4])
		
		if etlValue==2:
			desc='pH'
		elif etlValue==3:
			desc='ORP'
		elif etlValue==4:
			desc='TDS'
		#sql_string=f"Max({desc})"
		Max=(sql(f"Max({desc})", year, mon, sId, name, st, et)).fetchone()[0]
		Min=(sql(f"Min({desc})", year, mon, sId, name, st, et)).fetchone()[0]
		for data in sql(desc,year,mon,sId,name,st,et):
			data_list.append(data[0])
		Median=statistics.median(data_list)
		# pHMin, pHMedian, pHMax, ORPMin, ORPMedian, ORPMax, TDSMin, TDSMedian, TDSMax
		if etlValue==2:
			pHMin=round(Min,2)
			pHMedian=round(Median,2)
			pHMax=round(Max,2)
			ORPMin= ORPMedian= ORPMax= TDSMin= TDSMedian= TDSMax ='NULL'
		elif etlValue==3:
			ORPMin=round(Min,2)
			ORPMedian=round(Median,2)
			ORPMax=round(Max,2)
			pHMin= pHMedian= pHMax= TDSMin= TDSMedian= TDSMax ='NULL'
		elif etlValue==4:
			TDSMin=round(Min,2)
			TDSMedian=round(Median,2)
			TDSMax=round(Max,2)
			pHMin= pHMedian= pHMax= ORPMin= ORPMedian= ORPMax ='NULL'
		
		with conn.cursor() as data_cursor:
			insert_sql=f"""
			Replace into `reportPlatform2021`.`Dquality`(
			`date`,`siteId`,`name`,
			`pHMin`,`pHMedian`,`pHMax`,
			`ORPMin`,`ORPMedian`,`ORPMax`,
			`TDSMin`,`TDSMedian`,`TDSMax`
			)Values(\'{date}\',{sId},\'{name}\',
			{pHMin},{pHMedian},{pHMax},
			{ORPMin},{ORPMedian},{ORPMax},
			{TDSMin},{TDSMedian},{TDSMax})
			"""
			print(insert_sql)
			#data_cursor.execute(insert_sql)
			
		cnt+=1
	print("------ %d rows Fetched ------"%cnt)
	
conn.commit()
print("------ Replacing Succeed ------")
conn.close()
print("------ Connection closed ------")