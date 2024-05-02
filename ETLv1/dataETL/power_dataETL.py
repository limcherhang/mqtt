import pymysql
import time
from datetime import datetime, timedelta

def connectDB(host):
	try:
		conn=pymysql.connect(
			host=host,
			read_default_file='~/.my.cnf'
		)
		print("----- Connection Succeed -----")
		return conn
	except Exception as ex:
		print("[ERROR]:",str(ex))
	return None

s=time.time()
programStartTime = datetime.now().replace(microsecond=0)
print("----- now: %s -----"%datetime.now().replace(microsecond=0))

timeRange_st=(programStartTime-timedelta(minutes=2)).replace(second=0)
timeRange_et=programStartTime
print("Searching from %s to %s"%(timeRange_st,timeRange_et))

#conn=connectDB('192.168.1.62')
conn=connectDB('127.0.0.1')
#db_81_conn=connectDB('192.168.1.81')

with conn.cursor() as cursor:
	sqlCommand="""
	Select siteId, name, ieee, gatewayId, syncSec
	From mgmtETL.Device
	where name like	'Power#%' and gatewayId>0
	order by siteId
	"""
	cursor.execute(sqlCommand)
	n=0
	for rows in cursor:
		sId=rows[0]
		name=rows[1]
		ieee=rows[2]
		print(f"Processing siteId:{sId} {ieee} {name}")
		
		data_cursor = conn.cursor()
		sqlCommand=f"""
		Select date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts, gatewayId,
		ch1Watt, ch2Watt, ch3Watt,
		totalPositiveWattHour,
		totalNegativeWattHour,
		ch1Current,ch2Current,ch3Current,
		ch1Voltage,ch2Voltage,ch3Voltage,
		ch1PowerFactor,ch2PowerFactor,ch3PowerFactor,
		voltage12,voltage23,voltage31,
		ch1Hz,ch2Hz,ch3Hz,
		i1THD,i2THD,i3THD,
		v1THD,v2THD,v3THD
		From iotmgmt.pm
		Where ieee='{ieee}' and receivedSync>='{timeRange_st}' and receivedSync<'{timeRange_et}'
		"""
		#print(sqlCommand)
		data_cursor.execute(sqlCommand)
		if data_cursor.rowcount==0:
			print(f" [Error]: {ieee} {name} has no data")
		
		cnt=0
		for data in data_cursor:
			#print("(%d)"%(cnt+1),data)
			#string=', '.join(['%s']*len(custom))
			#mix=', '.join(str(i) for i in data[2:])
			ts=data[0]
			gId=data[1]
			ch1Watt=(0 if data[2] is None else data[2])
			ch2Watt=(0 if data[3] is None else data[3])
			ch3Watt=(0 if data[4] is None else data[4])
			totalPositiveWattHour=('NULL' if data[5] is None else data[5])
			totalNegativeWattHour=('NULL' if data[6] is None else data[6])
			ch1Current=(0 if data[7] is None else data[7])
			ch2Current=(0 if data[8] is None else data[8])
			ch3Current=(0 if data[9] is None else data[9])
			ch1Voltage=('NULL' if data[10] is None else data[10])
			ch2Voltage=('NULL' if data[11] is None else data[11])
			ch3Voltage=('NULL' if data[12] is None else data[12])
			ch1PowerFactor=('NULL' if data[13] is None else data[13])
			ch2PowerFactor=('NULL' if data[14] is None else data[14])
			ch3PowerFactor=('NULL' if data[15] is None else data[15])
			voltage12=('NULL' if data[16] is None else data[16])
			voltage23=('NULL' if data[17] is None else data[17])
			voltage31=('NULL' if data[18] is None else data[18])
			ch1Hz=('NULL' if data[19] is None else data[19])
			ch2Hz=('NULL' if data[20] is None else data[20])
			ch3Hz=('NULL' if data[21] is None else data[21])
			i1THD=('NULL' if data[22] is None else data[22])
			i2THD=('NULL' if data[23] is None else data[23])
			i3THD=('NULL' if data[24] is None else data[24])
			v1THD=('NULL' if data[25] is None else data[25])
			v2THD=('NULL' if data[26] is None else data[26])
			v3THD=('NULL' if data[27] is None else data[27])
			with conn.cursor() as replace_cursor:
				replace_sql=f"""
				Replace into `dataETL`.`power`(
				`ts`,`gatewayId`,`name`,
				`ch1Watt`,`ch2Watt`,`ch3Watt`,
				`totalPositiveWattHour`,
				`totalNegativeWattHour`,
				`ch1Current`,`ch2Current`,`ch3Current`,
				`ch1Voltage`,`ch2Voltage`,`ch3Voltage`,
				`ch1PowerFactor`,`ch2PowerFactor`,`ch3PowerFactor`,
				`voltage12`,`voltage23`,`voltage31`,
				`ch1Hz`,`ch2Hz`,`ch3Hz`,
				`i1THD`,`i2THD`,`i3THD`,
				`v1THD`,`v2THD`,`v3THD`
				) Values(\'{ts}\',{gId},\'{name}\',
				{ch1Watt},{ch2Watt},{ch3Watt},
				{totalPositiveWattHour},
				{totalNegativeWattHour},
				{ch1Current},{ch2Current},{ch3Current},
				{ch1Voltage},{ch2Voltage},{ch3Voltage},
				{ch1PowerFactor},{ch2PowerFactor},{ch3PowerFactor},
				{voltage12},{voltage23},{voltage31},
				{ch1Hz},{ch2Hz},{ch3Hz},
				{i1THD},{i2THD},{v1THD},
				{v1THD},{v2THD},{v3THD})
				"""
				#""".format(data[0],data[1],rows[1],mix)
				print(replace_sql)
				try:
					replace_cursor.execute(replace_sql)
				except Exception as ex:
					print(f"siteId: {sId} name: {name} ieee: {ieee}")
					print(f"[Repalce ERROR]: {str(ex)}")
			cnt+=1
		
		n+=1

conn.commit()
print("------ Replaceing Succeed ------")
conn.close()
print(f"------ Connection closed ------ took:{time.time()-s}s")
#programEndTime = datetime.now()
#print(f"took: {programEndTime-programStartTime}")