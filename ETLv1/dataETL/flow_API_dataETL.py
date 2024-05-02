import pymysql
import time
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta

def connectDB(host):
	try:
		conn=pymysql.connect(
			host=host,
			read_default_file='~/.my.cnf'
		)
		logging.debug(f"IP: {host} Connection Succeed")
		return conn
	except Exception as ex:
		logging.error(f"[Connection ERROR]: {str(ex)}")
	return None

logging.basicConfig(
	handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
	level = logging.ERROR, 
	format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
	datefmt = '%Y-%m-%d %H:%M:%S'
)


s=time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- now: {nowTime} ----------")

st=(nowTime-timedelta(minutes=20)).replace(second=0)
et=nowTime
logging.info(f"----- Searching from {st} to {et} -----")

conn=connectDB('127.0.0.1')

value_string = ''
with conn.cursor() as cursor:

	sqlCommand="""
	Select siteId, name, nameListName, ieee, dataTableRaw
	From mgmtETL.vDeviceInfo
	where name like	'Flow#%' and deviceGId=182
	"""
	cursor.execute(sqlCommand)

	for rows in cursor:
		name = rows[1]
		ieee = rows[3]
		tableRaw = rows[4]

		logging.debug(f"----- Prcoessing {ieee} {name} -----")
		
		if tableRaw != 'flowTMR2RMT': continue

		with conn.cursor() as data_cursor:
			sqlCommand = f"""
			SELECT 
				date_format(receivedSync, '%Y-%m-%d %H:%i:00') as ts, gatewayId,
				flowInstant,
				flowTotalPositive
			FROM iotmgmt.flowTMR2RMT 
			where 
				ieee='{ieee}' and
				receivedSync>='{st}' and 
				receivedSync<'{et}'
			"""

			data_cursor.execute(sqlCommand)
			if data_cursor.rowcount == 0:
				logging.warning(f"{ieee} {name} has no data at {nowTime}")
				continue
			else:
				for data in data_cursor:
					ts = data[0]
					gId = data[1]
					flowInstant = ('NULL' if data[2] is None else data[2])
					total = ('NULL' if data[3] is None else data[3])
					
					logging.info(f"'{ts}', {gId}, '{name}', {flowInstant}, {total}")
					value_string += f"('{ts}', {gId}, '{name}', {flowInstant}, {total}), "

if value_string != '':
	value_string = value_string[:-2]
	with conn.cursor() as cursor:
		replace_sql = f"replace into `dataETL`.`flow` (`ts`, `gatewayId`, `name`, `flowRate`, `flowTotalPositive`) Values {value_string}"
		logging.debug(replace_sql)
		try:
			cursor.execute(replace_sql)
			conn.commit()
		except Exception as ex:
			logging.error(f"SQL: {replace_sql}")
			logging.error(f"[Replace ERROR]: {str(ex)}")

conn.close()
logging.info(f"------ Connection closed ------ took:{round(time.time()-s, 3)}s")
