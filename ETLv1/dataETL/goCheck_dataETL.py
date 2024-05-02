import pymysql
import pathlib
import logging
from logging.config import fileConfig
from datetime import datetime, timedelta
from toolkits import connection
from toolkits import flow_daily
from toolkits import flowU_daily
from toolkits import gpio_daily
from toolkits import power_daily
from toolkits import pressure_daily
from toolkits import temp_daily
from toolkits import twoInOne_daily
from toolkits import threeInOne_daily
from toolkits import waterQuality_daily
from toolkits import ammonia_daily
from toolkits import particle_daily
from toolkits import vibration_daily

def getRows(table, etlName, gId, ieee, todayDate, lastDate, insertion):
	insertion=insertion
	pwd=str(pathlib.Path("__file__").parent.absolute())
	#print(pwd)
	logging.info(f"Location: {pwd}")
	st_date=lastDate.strftime('%Y-%m-%d')
	et_date=todayDate.strftime('%Y-%m-%d')
	
	
	if table=='Flow':
		etlTable='flow'
		iotTable='flowTMR2RMT'
	elif table=='FlowU':
		etlTable='flowU'
		iotTable='ultrasonicFlow2'
	elif table=='Gpio':
		etlTable='gpio'
		iotTable='gpio'
	elif table=='Power':
		etlTable='power'
		iotTable='pm'
	elif table=='Pressure':
		etlTable='pressure'
		iotTable='pressure'
	elif table=='Temp':
		etlTable='temp'
		iotTable='dTemperature'
	elif table=='TwoInOne':
		etlTable='twoInOne'
		iotTable='co2'
	elif table=='ThreeInOne':
		etlTable='threeInOne'
		iotTable='co2'
	elif table=='WaterQuality':
		etlTable='waterQuality'
		iotTable='waterQuality'
	elif table=='Ammonia':
		etlTable='ammonia'
		iotTable='zigbeeRawModbus'
	elif table=='Particle':
		etlTable='particle'
		iotTable='particle'
		print("[Skip] 1 data per second")
		return None
	elif table=='Vibration':
		etlTable='vibration'
		iotTable='vibration'
	else:
	#	raise Exception(f"[Error]: {table} isn't defined")
		print(f"[Error]: {table} isn't defined")
		return None
	logging.info(f"Processing {table} .....")
	etl_list=[]
	etl_cursor=conn.cursor()
	sqlCommand=f"Select ts from dataETL.{etlTable} where gatewayId={gId} and name=\'{etlName}\' and ts>=\'{st_date}\' and ts<\'{et_date}\'"
	#print(sqlCommand)
	etl_cursor.execute(sqlCommand)
	for etl_data in etl_cursor:
		if etl_data[0] not in etl_list:
			etl_list.append(etl_data[0])
	etl_rows=len(etl_list)
	print(f" etl rows: {etl_rows}")
	
	iot_list=[]
	iot_cursor=conn.cursor()
	sqlCommand=f"Select date_format(receivedSync, '%Y-%m-%d %H:%i:00') from iotmgmt.{iotTable} where gatewayId={gId} and ieee=\'{ieee}\' and receivedSync>=\'{st_date}\' and receivedSync<\'{et_date}\'"
	#print(sqlCommand)
	iot_cursor.execute(sqlCommand)
	for iot_data in iot_cursor:
		if iot_data[0] not in iot_list:
			iot_list.append(iot_data[0])
	iot_rows=len(iot_list)
	print(f" iot rows: {iot_rows}")

	if etl_rows==iot_rows:
		print(f" gatewayId:{gId} {etlName} {ieee} checked fine")
	else:
		# open file ?
		#with open(f"/home/ecoetl/dataETL/toolkits/record.log",'a') as f:
		#with open(f"{pwd}/toolkits/record.log",'a') as f:
		#	f.write(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
		#	f.write(f"------------ {gId} {etlName} {ieee} ------------\n")
		#	f.write(f" {gId} {ieee} in {iotTable} calculating again...")
		logging.info(f" {gId} {ieee} in {iotTable} calculating again...")
		#print(f"{iotTable}, {etlName} {gId} {ieee} {st_date} {et_date} {insertion}")
		if iotTable=='flowTMR2RMT':
			num=flow_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='ultrasonicFlow2':
			num=flowU_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='gpio':
			num=gpio_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
			#print("Processing...")
		elif iotTable=='pm':
			num=power_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='pressure':
			num=pressure_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='dTemperature':
			num=temp_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='co2':
			if table=='TwoInOne':
				num=twoInOne_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
			elif table=='ThreeInOne':
				num=threeInOne_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='waterQuality':
			num=waterQuality_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='zigbeeRawModbus':
			num=ammonia_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='particle':
			num=particle_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		elif iotTable=='vibration':
			num=vibration_daily.main(conn, etlName, gId, ieee, st_date, et_date, insertion)
		else:
			print(f" [Error]: {table} doesn't exist")
		
		if num>1300:
			print(f" Value: {num} [Status]: normal")
		elif num>1000:
			print(f" Value: {num} [Status]: Unstable")
		else:
			print(f" Value: {num} [Status]: abnormal")
		#with open(f"/home/ecoetl/dataETL/toolkits/record.log",'a') as f:
		#with open(f"{pwd}/toolkits/record.log",'a') as f:
		#	f.write(f" Value is {num}\n\n")

fileConfig('dataETL_logging_config.ini')

programStartTime = datetime.now()
print(f"Program starts at {programStartTime.strftime('%Y-%m-%d %H:%M:%S')}\n")
logging.info(f"----- now: {programStartTime} -----")
todayDate = datetime.now()
lastDate = (todayDate-timedelta(days=1))

conn=connection.connectDB()

print(f" Running from {lastDate.strftime('%Y-%m-%d')} to {todayDate.strftime('%Y-%m-%d')}")

device_cursor=conn.cursor()
sqlCommand="Select substring_index(name,'#',1) as tableDesc, siteid, name, ieee, gatewayId from mgmtETL.Device where siteId!=11"
device_cursor.execute(sqlCommand)

insertion=True

cnt=0
for rows in device_cursor:
	
	table=rows[0]
	sId=rows[1]
	etlName=rows[2]
	ieee=rows[3]
	gId=rows[4]
	
	if table!='Router':
		print(f"{cnt+1}------------ {sId} {etlName} {gId} {ieee} ------------")
		getRows(table, etlName, gId, ieee, todayDate, lastDate, insertion)
	
	cnt+=1
print(f"----- Total rows: {cnt} -----")

programEndTime = datetime.now()

conn.close()
print(f"----- Connection Closed ----- took: {(programEndTime-programStartTime).seconds}s")
logging.info(f"----- Calculation Done !!! -----")