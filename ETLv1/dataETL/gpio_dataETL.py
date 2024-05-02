import time
import pymysql
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
#st = datetime(2022, 2, 22)
#et = datetime(2022, 2, 23)
logging.debug(f"---------- from {st} to {et} ----------")

conn=connectDB('127.0.0.1')

with conn.cursor() as cursor:
	sqlCommand = f"SELECT gatewayId, name, ieee FROM mgmtETL.Device where name like 'Gpio#%'"
	logging.debug(sqlCommand)

	cursor.execute(sqlCommand)
	if cursor.rowcount == 0:
		logging.warning(f"Gpio has no mapping info")
	else:
		for rows in cursor:
			gId = rows[0]
			name = rows[1]
			ieee = rows[2]
			value_string = ''
			with conn.cursor() as cursor:
				sqlCommand = f"select gatewayId, receivedSync, pin0, pin1, pin2, pin3, pin4, pin5, pin6, pin7 from iotmgmt.gpio where ieee='{ieee}' and gatewayId={gId} and receivedSync>='{st}' and receivedSync<'{et}'"
				logging.debug(sqlCommand)
				cursor.execute(sqlCommand)

				if cursor.rowcount == 0:
					logging.warning(f"GatewayId: {gId} {ieee} has no GPIO data in the minute!!!")
				else:
					for data in cursor:
						gId = data[0]
						ts = data[1]
						pin0 = ('NULL' if data[2] is None else data[2])
						pin1 = ('NULL' if data[3] is None else data[3])
						pin2 = ('NULL' if data[4] is None else data[4])
						pin3 = ('NULL' if data[5] is None else data[5])
						pin4 = ('NULL' if data[6] is None else data[6])
						pin5 = ('NULL' if data[7] is None else data[7])
						pin6 = ('NULL' if data[8] is None else data[8])
						pin7 = ('NULL' if data[9] is None else data[9])
						
						logging.debug(f"{ts} {gId} {name} {pin0} {pin1} {pin2} {pin3} {pin4} {pin5} {pin6} {pin7}")
						value_string += f"('{ts}', {gId}, '{name}', {pin0}, {pin1}, {pin2}, {pin3}, {pin4}, {pin5}, {pin6}, {pin7}), "

					if value_string != '':
						value_string = value_string[:-2]
						with conn.cursor() as cursor:
							replace_sql = f"replace into `dataETL`.`gpio` (`ts`, `gatewayId`, `name`, `pin0`, `pin1`, `pin2`, `pin3`, `pin4`, `pin5`, `pin6`, `pin7`) Values {value_string}"
							logging.debug(replace_sql)
							try:
								cursor.execute(replace_sql)
								conn.commit()
								logging.debug(f"----- Connection Commit -----")
							except Exception as ex:
								logging.error(f"SQL: {replace_sql}")
								logging.error(f"[Replace ERROR]: {str(ex)}")


conn.close()
logging.info(f"----- Connection Closed ----- took: {round(time.time()-s, 3)}s")
