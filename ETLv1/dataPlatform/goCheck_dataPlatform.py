import pymysql
import os
import pathlib
import logging
from logging.config import fileConfig
from datetime import datetime, timedelta
from toolkits import connection
from toolkits import ammonia_daily
from toolkits import co2_daily
from toolkits import flow_daily
from toolkits import gpio_daily
from toolkits import humidity_daily
from toolkits import power_daily
from toolkits import pressure_daily
from toolkits import quality_daily
from toolkits import temp_daily
from toolkits import particle_daily
from toolkits import vibration_daily

def chillerPlant(conn, sId, name, gId, power1, power2, lastDate, todayDate):
	
	while lastDate<todayDate:
		ts = lastDate
		lastDate += timedelta(minutes=1)

		with conn.cursor() as cursor:
			sqlCommand = f"select sum(ch1Watt), sum(ch2Watt), sum(ch3Watt) from dataETL.power where gatewayId={gId} and name in ('{power1}', '{power2}') and ts='{ts}'"
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			data = cursor.fetchone()
			ch1Watt = data[0]
			ch2Watt = data[1]
			ch3Watt = data[2]
			if ch1Watt is not None and ch2Watt is not None and ch3Watt is not None:
				powerConsumed = round((ch1Watt+ch2Watt+ch3Watt)/1000, 2)
			else:
				continue
		
		with conn.cursor() as cursor:
			replace_sql = f"replace into `dataPlatform`.`power` (`ts`, `siteId`, `name`, `ch1Watt`, `ch2Watt`, `ch3Watt`, `powerConsumed`) Values ('{ts}', {sId}, '{name}', {ch1Watt}, {ch2Watt}, {ch3Watt}, {powerConsumed})"
			#print(replace_sql)
			cursor.execute(replace_sql)

	conn.commit()
	print(" Calculation done!")

def check(table, sId, name, gId, etlName, st_date, et_date):
	
	#st_date=lastDate.strftime('%Y-%m-%d')
	#et_date=todayDate.strftime('%Y-%m-%d')

	dpf_list=[]
	dpf_cursor=conn.cursor()#dataPlatform
	sqlCommand=f"select ts from dataPlatform.{table} where siteId={sId} and name=\'{name}\' and ts>=\'{st_date}\' and ts<\'{et_date}\'"
	#print(f" {sqlCommand}")
	dpf_cursor.execute(sqlCommand)
	for dpf_data in dpf_cursor:
		data = dpf_data[0].replace(second=0)
		if data not in dpf_list:
			dpf_list.append(data)
	print(f" dataPlatform rows: {len(dpf_list)}")
	
	str_etlName=etlName.split('#')
	#print(str_etlName[0])
	if str_etlName[0]=='Flow':
		etlTable='flow'
	elif str_etlName[0]=='FlowU':
		etlTable='flowU'
	elif str_etlName[0]=='Gpio':
		etlTable='gpio'
	elif str_etlName[0]=='Power':
		etlTable='power'
	elif str_etlName[0]=='Pressure':
		etlTable='pressure'
	elif str_etlName[0]=='Temp':
		etlTable='temp'
	elif str_etlName[0]=='TwoInOne':
		etlTable='twoInOne'
	elif str_etlName[0]=='WaterQuality':
		etlTable='waterQuality'
	elif str_etlName[0]=='ThreeInOne':
		etlTable='threeInOne'
	elif str_etlName[0]=='Ammonia':
		etlTable='ammonia'
	elif str_etlName[0]=='Particle':
		etlTable='particle'
	elif str_etlName[0]=='Vibration':
		etlTable='vibration'
	else:
		#raise Exception(f" [Error]: {str_etlName[0]} doesn't exit")
		print(f"[Error]: {etlName} isn't defined")
		return 0
	
	etl_list=[]
	etl_cursor=conn.cursor()#dataETL
	sqlCommand=f"select ts from dataETL.{etlTable} where gatewayId={gId} and name=\'{etlName}\' and ts>=\'{st_date}\' and ts<\'{et_date}\'"
	#print(f" {sqlCommand}")
	etl_cursor.execute(sqlCommand)
	for etl_data in etl_cursor:
		data = etl_data[0].replace(second=0)
		if data not in etl_list:
			etl_list.append(data)
	print(f" dataETL rows: {len(etl_list)}")

	if len(dpf_list)==len(etl_list):
		print(f" {sId} {name} {etlName} checked fine")
		logging.info(f" Checked fine")
	else:
		return 1
	
	return 0

fileConfig('dataPlatform_logging_config.ini')

programStartTime = datetime.now().replace(microsecond=0)
#print(f"Program starts at {programStartTime}")
lastDate = (programStartTime-timedelta(days=1)).replace(hour=0, minute=0, second=0)
todayDate = programStartTime.replace(hour=0, minute=0, second=0)
#lastDate = datetime(2022, 1, 4)
#todayDate = datetime(2022, 1, 5)
print(f" from {lastDate} to {todayDate}")

pwd = str(pathlib.Path("__file__").parent.absolute())
logging.info(f"Loaction: {pwd}")
#print(pwd)

conn=connection.connectDB()

nameList_cursor = conn.cursor()
sqlCommand=" \
	Select \
	siteId, name, nameDesc, tableDesc, gatewayId, protocol, dataETLName \
	from mgmtETL.NameList \
	where  gatewayId>0 and protocol is not NULL \
	#limit 15 \
	"
nameList_cursor.execute(sqlCommand)

cnt=0
for rows in nameList_cursor:
	
	sId=rows[0]
	name=rows[1]
	table=rows[3]
	gId=rows[4]
	protocol=rows[5]
	etlName=rows[6]
	print(f"{cnt+1}------------ {sId} {name} ------------")
	logging.info(f"------------ Processing {sId} {name} ------------")
	#print(f" protocol:{protocol} etlName:{etlName}")
	#exeception issue for protocol is Combination
	if protocol=='Combination' and etlName is None:
		cursor=conn.cursor()
		sqlCommand=f"select dataETLCombination from mgmtETL.NameList where siteId={sId} and name='{name}' and gatewayId={gId}"
		cursor.execute(sqlCommand)
		allData=cursor.fetchone()
		if table=='flow':
			etlName=allData[0][2:8]
		elif table=='power':
			power1=allData[0][2:10]
			power2=allData[0][14:22]
			#print(etlName1, etlName2)
			chillerPlant(conn, sId, name, gId, power1, power2, lastDate, todayDate)
			continue

	flag=check(table, sId, name, gId, etlName, lastDate, todayDate)
	
	if flag==1:
		#pwd=str(pathlib.Path("__file__").parent.absolute())
		#print(f" python3 {pwd}/toolkits/{table}_daily.py")
		#with open(f"/home/ecoetl/dataPlatform/toolkits/record.log", 'a') as f:
		#with open(f"{pwd}/toolkits/record.log", 'a') as f:
		#	f.write(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
		#	f.write(f"------------ {sId} {name} ------------\n")
		#	f.write(f" {sId} {name} calculating again...\n")
		logging.info(f" calculating again...")
		if table=='ammonia':
			ammonia_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='co2':
			co2_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='flow':
			flow_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='gpio':
			gpio_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='humidity':
			humidity_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='power':
			power_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='pressure':
			pressure_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='quality':
			quality_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='temp':
			temp_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='particle':
			particle_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		elif table=='vibration':
			vibration_daily.main(conn,gId,etlName,sId,name,lastDate,todayDate)
		#os.system(f"python3 /home/ecoetl/dataPlatform/toolkits/{table}_daily.py {gId} {etlName} {sId} {name} {lastDate} {todayDate}")
		
	cnt+=1

print(f"----- Total rows: {cnt} -----")

programEndTime = datetime.now()

conn.close()
print(f"----- Connection Closed ----- took: {(programEndTime-programStartTime).seconds}s")
logging.info("----- Calculation Done -----")
