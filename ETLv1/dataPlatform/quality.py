import pymysql
import time
import logging
from logging.handlers import TimedRotatingFileHandler
from datetime import datetime, timedelta

def connectDB(host):
	try:
		conn=pymysql.connect(
			host = host, 
			read_default_file = '~/.my.cnf'
		)
		logging.debug(f"IP: {host} Connection Succeed")
		return conn
	except Exception as ex:
		logging.error(f"[Connection ERROR]: {str(ex)}")

logging.basicConfig(
	handlers = [TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
	level = logging.ERROR, 
	format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
	datefmt = '%Y-%m-%d %H:%M:%S'
)

s = time.time()
nowTime = datetime.now().replace(microsecond=0)
logging.info(f"---------- Now: {nowTime} ---------- Program Started !")
st = (nowTime - timedelta(minutes=3)).replace(second=0)
et = nowTime
logging.debug(f"---------- from {st} to {et} ----------")

conn=connectDB('127.0.0.1')

with conn.cursor() as cursor:
	sqlCommand = "select siteId, name, gatewayId, dataETLName from mgmtETL.NameList where protocol is not NULL and gatewayId>0 and tableDesc='quality'"
	cursor.execute(sqlCommand)
	
	if cursor.rowcount == 0:
		logging.warning(f'Quailty has no mapping info')
	else:
		value_string = ''
		for rows in cursor:
			sId = rows[0]
			name = rows[1]
			gId = rows[2]
			etlName = rows[3]
			logging.info(f"----- Processing {sId} {name} -----")
			with conn.cursor() as cursor:
				sqlCommand = f"select ts, ph, ORP, TDS, EC from dataETL.waterQuality where gatewayId={gId} and name='{etlName}' and ts>='{st}' and ts<'{et}'"
				logging.debug(sqlCommand)
				cursor.execute(sqlCommand)
				if cursor.rowcount == 0:
					logging.warning(f"GatewayId: {gId} has no WaterQuality data in the minute!!!")
					continue
				for data in cursor:
					logging.debug(data)
					ts = data[0]
					ph = ('NULL' if data[1] is None else data[1])
					orp = ('NULL' if data[2] is None else data[2])
					tds = ('NULL' if data[3] is None else data[3])
					ec = ('NULL' if data[4] is None else data[4])
					
					value_string += f"('{ts}', {sId}, '{name}', {ph}, {orp}, {tds}, {ec}), "

if value_string != '':
	value_string = value_string[:-2]
	with conn.cursor() as cursor:
		replace_sql = f"replace into `dataPlatform`.`quality` (`ts`, `siteId`, `name`, `pH`, `ORP`, `TDS`, `EC`) Values {value_string}"
		logging.debug(replace_sql)
		try:
			cursor.execute(replace_sql)
		except Exception as ex:
			logging.error(f"SQL: {replace_sql}")
			logging.error(f"[Replace ERROR]: {str(ex)}")

conn.commit()
conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
