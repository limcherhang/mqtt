import pymysql
from datetime import datetime, timedelta

def connect(host,port,username,password):
	try:
		conn=pymysql.connect(
			host=host,
			port=port,
			user=username,
			passwd=password,
			#read_default_file='~/.my.cnf'
		)
		return conn
	except Exception as ex:
		raise f"[Error] {str(ex)}"
	return None

def getGpio(conn, gId, dNo, gpio_list, ts):
	cursor=conn.cursor()
	for i in range(len(gpio_list)):
		sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo={dNo} and objectInstance={gpio_list[i]} and ts like '{ts}'"
		#print(sqlCommand)
		cursor.execute(sqlCommand)
		opFlag=cursor.fetchone()[0]
		if opFlag=='1' or opFlag=='active':
			return 1
		elif opFlag=='0' or opFlag=='inactive':
			return 0

def getPower(conn, gId, ObjIns, time):
	cursor = conn.cursor()
	sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo=300 and objectInstance={ObjIns} and ts like '{time}'"
	cursor.execute(sqlCommand)
	power = cursor.fetchone()[0]
	#print(sqlCommand)
	return float(power)

def getTemp(conn, gId, dNo, ObjIns, time):
	cursor = conn.cursor()
	sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo={dNo} and objectInstance={ObjIns} and ts like '{time}'"
	cursor.execute(sqlCommand)
	temp = cursor.fetchone()[0]
	#print(sqlCommand)
	return float(temp)

def insertflow(stage_conn, ts, name, value):
	with stage_conn.cursor() as flow_cursor:
		flow_sql=f"""
		replace into `dataPlatform`.`flow`(
		`ts`, `siteId`, `name`, `flowRate`, `waterConsumed`
		) Values(
		'{ts}', 24, '{name}', {round(value,2)}, 0
		)
		"""
		print(flow_sql)
		flow_cursor.execute(flow_sql)

def cpf(bms_conn, stage_conn, gId, dNo, name, gpio, coolingCapacity, efficiency, st, et):
	data_cursor = bms_conn.cursor()
	#pb_cursor = pb_conn.cursor()
	#ads_cursor = ads_conn.cursor()
	stage_cursor = stage_conn.cursor()
	#get CoolingCapicity data
	sqlCommand=f"select ts, data from bms.rawData where gatewayId={gId} and deviceNo={dNo} and objectInstance={coolingCapacity} and ts>='{st}' and ts<'{et}'"
	#print(sqlCommand)
	data_cursor.execute(sqlCommand)
	if data_cursor.rowcount==0:
		print(f"[Error]: gatewayId:{gId} {dNo} has no data during the time!")
		return 0
	print(f"gatewayId:{gId} deviceNo:{dNo} {name}")
	for rows in data_cursor:
		ts=rows[0]
		time=f"{str(ts)[0:16]}:%"
		rt_data=rows[1]
		
		with bms_conn.cursor() as cursor:
			#get Efficiency data
			sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo={dNo} and objectInstance={efficiency} and ts like '{time}'"
			#print(sqlCommand)
			cursor.execute(sqlCommand)
			if cursor.rowcount==0:
				eff_data='NULL'
				print(f" [Error]: gatewayId:{gId} {name} has no efficiency data")
			else:
				eff_data=cursor.fetchone()[0]
		
		#get Operation status of Chiller
		with bms_conn.cursor() as cursor:
			gpio_dNo=538
			if gpio is None:
				opFlag=getGpio(bms_conn, gId, gpio_dNo, [3020818, 3020847], time)
			else:
				sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo={gpio_dNo} and objectInstance={gpio} and ts like '{time}'"
				#print(sqlCommand)
				cursor.execute(sqlCommand)
				if cursor.rowcount==0:
					print(f" [Error]: gatewayId:{gId} {name} has no gpio data")
					opFlag='NULL'
				else:
					data = cursor.fetchone()[0]
					if data == '1' or data == 'active':
						opFlag=1
					elif data == '0' or data == 'inactive':
						opFlag=0
			
		insert_sql=f"""
		replace into `processETL`.`chiller` (
		`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`
		) Values(
		'{ts.replace(second=0)}', 23, '{name}', {opFlag}, {rt_data}, {eff_data}
		)
		"""
		print(insert_sql)
		#pb_cursor.execute(insert_sql)
		#ads_cursor.execute(insert_sql)
		stage_cursor.execute(insert_sql)

def ywca(bms_conn, stage_conn, gId, name, power, temp, st, et):
	data_cursor=bms_conn.cursor()
	#pb_cursor=pb_conn.cursor()
	#ads_cursor=ads_conn.cursor()
	stage_cursor = stage_conn.cursor()
	print(f"gatewayId:{gId} {name}")
	#get Chillers Flow data
	sqlCommand=f"select ts, data from bms.rawData where gatewayId={gId} and deviceNo=13002 and objectInstance=0 and ts>='{st}' and ts<'{et}'"
	data_cursor.execute(sqlCommand)
	if data_cursor.rowcount==0:
			print(f" [Error]: deviceNo:13002 has no data during the time!")
			return 0
	for rows in data_cursor:
		ts=rows[0]
		time=f"{str(ts)[0:16]}:%"
		flow=float(rows[1])*3.6
		opFlag=0
		rt_data=0
		eff_data=0

		cursor = bms_conn.cursor()
		#get CH-1 Power
		ch1_power = getPower(bms_conn, gId, 11140, time)
		#get CH-2 Power
		ch2_power = getPower(bms_conn, gId, 11240, time)
		if power is None:
			if ch1_power>=10000 or ch2_power>=10000:
				opFlag=1
			total_power=ch1_power+ch2_power
			sqlCommand=f"select data from bms.rawData where gatewayId={gId} and deviceNo=300 and objectInstance=2 and ts like '{time}'"
			cursor.execute(sqlCommand)
			rt_data=cursor.fetchone()[0]
			
			eff_data = (0 if float(rt_data) == 0 else round((total_power/1000/float(rt_data)),3))
		else:
			if ch1_power>=10000 and ch2_power>=10000:
				flow=round((flow/2),2)
				insertflow(stage_conn, ts.replace(second=0), 'flow#3', flow)
				insertflow(stage_conn, ts.replace(second=0), 'flow#4', flow)
			else:
				#print(f"ch-1 power: {ch1_power}")
				#print(f"ch-2 power: {ch2_power}")
				if ch1_power>ch2_power:
					insertflow(stage_conn, ts.replace(second=0),'flow#3',flow)
					insertflow(stage_conn, ts.replace(second=0),'flow#4',0)
				elif ch2_power>ch1_power:
					insertflow(stage_conn, ts.replace(second=0),'flow#3',0)
					insertflow(stage_conn, ts.replace(second=0),'flow#4',flow)
					
			#get CHWS Temp data
			#if temp=='13001':
			#	chws = getTemp(bms_conn, gId, temp, 3, time)
			#	chwr = getTemp(bms_conn, gId, temp, 1, time)
			#else:
			chws = getTemp(bms_conn, gId, temp, 2, time)
			chwr = getTemp(bms_conn, gId, temp, 0, time)
			#calculate cooling capacity data
			#print(f"Taking {flow} to calculate")
			rt_data = (997*4.2*(float(chwr)-float(chws))*flow) / (3600*3.51685)
			if rt_data == 0: return 0
			#calculate efficiency/opFlag data
			if power==11140:
				if ch1_power>=10000:
					opFlag=1
				eff_data=round((ch1_power/1000/rt_data),3)
			elif power==11240:
				if ch2_power>=10000:
					opFlag=1
				eff_data=round((ch2_power/1000/rt_data),3)
		
		insert_sql=f"""
		replace into `processETL`.`chiller` (
		`ts`, `siteId`, `name`, `opFlag`, `coolingCapacity`, `efficiency`
		) Values (
		'{ts.replace(second=0)}', 24, '{name}', {opFlag}, {round(float(rt_data),2)}, {eff_data}
		)
		"""
		print(insert_sql)
		#pb_cursor.execute(insert_sql)
		#ads_cursor.execute(insert_sql)
		stage_cursor.execute(insert_sql)

def main(gId, nowTime):
	bms_conn = connect('sg.evercomm.com',44106,'eco','ECO4ever')
	#pb_conn = connect('192.168.1.52')
	#ads_conn = connect('192.168.1.53')
	#stage_conn = connect('192.168.1.62')
	stage_conn = connect('127.0.0.1',3306,'ecoprog','ECO4ever8118')
	
	st = (nowTime-timedelta(minutes=1)).replace(second=0)
	et = nowTime
	
	chillerCount=0
	if gId==148:
		chillerCount=3
		chillerName_list=['chiller#1', 'chiller#2', 'chiller#Plant']
		gpio_list=[3020818, 3020847, None]
		rt_list=[3000037, 3000038, 3000222]
		eff_list=[3000067, 3000068, 3000039]
		for i in range(chillerCount):
			cpf(bms_conn, stage_conn, gId, 500, chillerName_list[i], gpio_list[i], rt_list[i], eff_list[i], st, et)
			#print(sql)
	elif gId==152:
		chillerCount=3
		chillerName_list=['chiller#1', 'chiller#2', 'chiller#Plant']
		power_list=[11140, 11240, None]
		temp_list=[4001041, 4001042, 13001]
		for i in range(chillerCount):
			ywca(bms_conn, stage_conn, gId, chillerName_list[i], power_list[i], temp_list[i], st, et)

	#pb_conn.commit()
	#ads_conn.commit()
	stage_conn.commit()
	bms_conn.close()
	#pb_conn.close()
	#ads_conn.close()
	stage_conn.close()
	
if __name__=='__main__':
	nowTime = datetime.now().replace(microsecond=0)
	programStartTime = nowTime
	gatewayIds = [148, 152]
	for gId in gatewayIds:
		main(gId, nowTime)
	programEndTime = datetime.now().replace(microsecond=0)
	print(f"Calculation Done in {(programEndTime-programStartTime).seconds}s")