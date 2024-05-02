import pymysql
from datetime import datetime, timedelta
import argparse

def connectDB():
	try:
		conn=pymysql.connect(
			host='127.0.0.1',
			user='ecoprog',
			password='ECO4prog'
		)
		print("----- Connection Succeed -----")
		return conn
	except Exception as ex:
		print(f"[Error]: {str(ex)}")
	return None

def getPMLog(sId, name, gId, ieee, insertion, user):
	print(" checking data ...")
	mon=datetime.now().month
	#receivedSync='NULL'
	#totalPositiveWattHour='NULL'
	m=1
	while m<=mon:
		cursor=conn.cursor()
		sqlCommand=f"select receivedSync,totalPositiveWattHour from iotdata2021.pm_0{m} where gatewayId={gId} and ieee=\'{ieee}\' and date_format(receivedSync,'%c')={m} order by receivedSync asc limit 1"
		#print(sqlCommand)
		cursor.execute(sqlCommand)
		#print(cursor.fetchone())
		data=cursor.fetchone()
		if data is None:
			if m==mon:
				print(f" gatewayId:{gId} {ieee} has no historical data")
				with open(f"./track_PMLog.log", 'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" [Error]: gatewayId:{gId} {ieee} has no historical data\n")
			m+=1
		else:
			#print(sqlCommand)
			receivedSync=data[0]
			totalPositiveWattHour=data[1]
			print(f" totalPositiveWattHour({totalPositiveWattHour}) found in {m}月({receivedSync})")
		
			if insertion==False:	
				return totalPositiveWattHour
			else:
				if totalPositiveWattHour is not None:
					print(f" Creating PMLog")
					insert_cursor=conn.cursor()
					insert_sql=f" insert into `mgmtETL`.`PMLog`(`ts`,`siteId`,`name`,`gatewayId`,`ieee`,`totalPositiveLatest`,`InsId`) Values(\'{receivedSync}\',{sId},\'{name}\',{gId},\'{ieee}\',{totalPositiveWattHour},\'{user}\')"
					print(insert_sql)
					insert_cursor.execute(insert_sql)					
					return totalPositiveWattHour			
	return 'failed'
		#m+=1

parser = argparse.ArgumentParser()
parser.add_argument('user')
args = parser.parse_args()
user = args.user
print(user)

programStartTime=datetime.now()

print(f"Start at {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}")

conn=connectDB()

device_cursor=conn.cursor()
device_sql="SELECT siteId, name, ieee, deviceType, deviceLogic, gatewayId FROM mgmtETL.Device where name like 'Power#%' and siteId=24 limit 1"
device_cursor.execute(device_sql)

cnt=0
for rows in device_cursor:
	
	insertion=True
	sId=rows[0]
	name=rows[1]
	ieee=rows[2]
	Type=int(rows[3])
	logic=rows[4]
	gId=rows[5]
	
	print(f"-------------------------------- Next --------------------------------")
	print(f" ----- gatewayId:{gId} {ieee} -----")
	if Type!=1 or logic!=1:
		#not power type
		#print(f"{name} Type:{Type} logic:{logic}")
		raise Exception(f" [Error]: siteId:{sId} {name} has wrong devceType or deviceLogic")
	else:
		#print(f"PM")
		pmLog_cursor=conn.cursor()
		pmLog_sql=f"select totalPositiveLatest from mgmtETL.PMLog where siteId={sId} and name=\'{name}\' and gatewayId={gId} and ieee=\'{ieee}\' limit 1"
		#print(pmLog_sql)
		pmLog_cursor.execute(pmLog_sql)
		totalPositiveLatest = pmLog_cursor.fetchone()
		
		if totalPositiveLatest is not None:
			insertion=False
			#getPMLog()
			print(f" gatewayId:{gId} {ieee} has own PMLog data")
			totalPWH=getPMLog(sId, name, gId, ieee, insertion, user)			
			if totalPositiveLatest[0]!=totalPWH:
				with open(f"./PMLog/track_PMLog.log",'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" [Error]: PMLog for gatewayId:{gId} {ieee} may be abnormal\n PMLog {totalPositiveLatest[0]} / iotdata2021 {totalPWH}\n\n")
				print(f" PMLog {totalPositiveLatest[0]} / iotdata2021 {totalPWH}")
				print(f" [Error]: PMLog for gatewayId:{gId} {ieee} may be abnormal")
			else:
				print(f" PMLog for gatewayId:{gId} {ieee} is {totalPWH}")
			
		else:
			insertion=True
			flag=getPMLog(sId, name, gId, ieee, insertion, user)
			if flag=='failed':
				print(f" Insertion Failed")
			else:
				with open(f"./PMLog/record_PMLog.log",'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" Create PMLog for gatewayId:{gId} {ieee} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
					f.write(f" totalPositiveLatest value is {flag}\n\n")
				#conn.commit()
				print(f" Insertion Succeed")
	cnt+=1

print(f"----- total rows: {cnt}-----")


conn.close()
programEndTime=datetime.now()
print(f"----- Connection closed ----- took: {(programEndTime-programStartTime).seconds}s")
