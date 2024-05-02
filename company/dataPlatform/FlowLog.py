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

def getFlowLog(sId, name, gId, ieee, insertion, user):
	print(" checking data ...")
	mon=datetime.now().month
	#receivedSync='NULL'
	#totalPositiveWattHour='NULL'
	m=1
	while m<=mon:
		cursor=conn.cursor()
		sqlCommand=f"select receivedSync,netAccumulator from iotdata2021.ultrasonicFlow2_0{m} where gatewayId={gId} and ieee=\'{ieee}\' and date_format(receivedSync,'%c')={m} order by receivedSync asc limit 1"
		#print(sqlCommand)
		cursor.execute(sqlCommand)
		#print(cursor.fetchone())
		data=cursor.fetchone()
		if data is None:
			if m==mon:
				print(f" gatewayId:{gId} {ieee} has no historical data")
				#/FlowLog
				with open(f"./FlowLog/track_FlowLog.log",'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" [Error]: gatewayId:{gId} {ieee} has no historical data\n")
			m+=1
		else:
			#print(sqlCommand)
			receivedSync=data[0]
			netAccumulator=data[1]
			print(f" netAccumulator({netAccumulator}) found in {m}月({receivedSync})")
		
			if insertion==False:	
				return netAccumulator
			else:
				if netAccumulator is not None:
					print(f" Creating FlowLog")
					insert_cursor=conn.cursor()
					insert_sql=f" insert into `mgmtETL`.`FlowLog`(`ts`,`siteId`,`name`,`gatewayId`,`ieee`,`totalLatest`,`InsId`) Values(\'{receivedSync}\',{sId},\'{name}\',{gId},\'{ieee}\',{netAccumulator},\'{user}\')"
					print(insert_sql)
					insert_cursor.execute(insert_sql)					
					return netAccumulator
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
device_sql="SELECT siteId, name, ieee, deviceType, deviceLogic, gatewayId FROM mgmtETL.Device where name like 'FlowU#%' #order by siteId desc limit 1"
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
	
	if Type!=6 or logic!=1:
		#not power type
		#print(f"{name} Type:{Type} logic:{logic}")
		raise Exception(f" [Error]: siteId:{sId} {name} has wrong devceType or deviceLogic")
	else:
		flowLog_cursor=conn.cursor()
		flowLog_sql=f"select totalLatest from mgmtETL.FlowLog where siteId={sId} and name=\'{name}\' and gatewayId={gId} and ieee=\'{ieee}\' limit 1"
		#print(pmLog_sql)
		flowLog_cursor.execute(flowLog_sql)
		totalLatest = flowLog_cursor.fetchone()
		
		if totalLatest is not None:
			insertion=False
			print(f" gatewayId:{gId} {ieee} has own FlowLog data")
			netAccumulator=getFlowLog(sId, name, gId, ieee, insertion, user)			
			if totalLatest[0]!=netAccumulator:
				
				#
				with open(f"./FlowLog/track_FlowLog.log",'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" [Error]: FlowLog for gatewayId:{gId} {ieee} may be abnormal\n FlowLog {totalLatest[0]} / iotdata2021 {netAccumulator}\n\n")
				
				print(f" FlowLog {totalLatest[0]} / iotdata2021 {netAccumulator}")
				print(f" [Error]: FlowLog for gatewayId:{gId} {ieee} may be abnormal")
			else:
				print(f" FlowLog for gatewayId:{gId} {ieee} is {netAccumulator}")
			
		else:
			insertion=True
			flag=getFlowLog(sId, name, gId, ieee, insertion, user)
			if flag=='failed':
				print(f" [Error]: Insertion Failed")
			else:
				
				#/FlowLog
				with open(f"./FlowLog/record_FlowLog.log",'a') as f:
					f.write(f"Time: {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n-------------------------------- {gId} {ieee} --------------------------------\n")
					f.write(f" Create FlowLog for gatewayId:{gId} {ieee} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
					f.write(f" netAccumulator value is {flag}\n\n")
				
				conn.commit()
				print(f" Insertion Succeed")
	
	cnt+=1
	
print(f"----- total rows: {cnt}-----")


conn.close()
programEndTime=datetime.now()
print(f"----- Connection closed ----- took: {(programEndTime-programStartTime).seconds}s")
