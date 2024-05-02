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

st=(nowTime-timedelta(minutes=65)).replace(second=0)
et=nowTime
logging.info(f"----- Searching from {st} to {et} -----")

conn=connectDB('127.0.0.1')

value_string = ''
with conn.cursor() as cursor:
	sqlCommand="""
	Select name, ieee, gatewayId
	From mgmtETL.Device
	where name like	'Power#%' and gatewayId=170
	"""
	cursor.execute(sqlCommand)
	
	
	for rows in cursor:
		name = rows[0]
		ieee = rows[1]
		gId = rows[2]
		logging.debug(f"Processing GatewyId:{gId} {ieee} {name}")
		
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
		Where gatewayId={gId} and ieee='{ieee}' and receivedSync>='{st}' and receivedSync<'{et}'
		"""
		logging.debug(sqlCommand)
		data_cursor.execute(sqlCommand)
		if data_cursor.rowcount==0:
			logging.warning(f"{ieee} {name} has no data at {datetime.now().replace(microsecond=0)}")
			continue

		for data in data_cursor:
			ts=data[0]
			gId=data[1]
			ch1Watt=(0 if data[2] is None else data[2])
			ch2Watt=(0 if data[3] is None else data[3])
			ch3Watt=(0 if data[4] is None else data[4])
			totalPositiveWattHour=('NULL' if data[5] is None else data[5])
			#totalNegativeWattHour=('NULL' if data[6] is None else data[6])
			#ch1Current=('NULL' if data[7] is None else data[7])
			#ch2Current=('NULL' if data[8] is None else data[8])
			#ch3Current=('NULL' if data[9] is None else data[9])
			#ch1Voltage=('NULL' if data[10] is None else data[10])
			#ch2Voltage=('NULL' if data[11] is None else data[11])
			#ch3Voltage=('NULL' if data[12] is None else data[12])
			#ch1PowerFactor=('NULL' if data[13] is None else data[13])
			#ch2PowerFactor=('NULL' if data[14] is None else data[14])
			#ch3PowerFactor=('NULL' if data[15] is None else data[15])
			#voltage12=('NULL' if data[16] is None else data[16])
			#voltage23=('NULL' if data[17] is None else data[17])
			#voltage31=('NULL' if data[18] is None else data[18])
			#ch1Hz=('NULL' if data[19] is None else data[19])
			#ch2Hz=('NULL' if data[20] is None else data[20])
			#ch3Hz=('NULL' if data[21] is None else data[21])
			#i1THD=('NULL' if data[22] is None else data[22])
			#i2THD=('NULL' if data[23] is None else data[23])
			#i3THD=('NULL' if data[24] is None else data[24])
			#v1THD=('NULL' if data[25] is None else data[25])
			#v2THD=('NULL' if data[26] is None else data[26])
			#v3THD=('NULL' if data[27] is None else data[27])
			
			value_string += f"('{ts}', {gId}, '{name}', {ch1Watt}, {ch2Watt}, {ch3Watt}, {totalPositiveWattHour}), "
			logging.info(f"'{ts}', {gId}, '{name}', {ch1Watt}, {ch2Watt}, {ch3Watt}, {totalPositiveWattHour}")

if value_string != '':
	value_string = value_string[:-2]
	with conn.cursor() as cursor:
		replace_sql = f"replace into `dataETL`.`power` (`ts`, `gatewayId`, `name`, `ch1Watt`, `ch2Watt`, `ch3Watt`, `totalPositiveWattHour`) Values {value_string}"
		logging.debug(replace_sql)
		try:
			cursor.execute(replace_sql)
			conn.commit()
		except Exception as ex:
			logging.error(f"SQL: {replace_sql}")
			logging.error(f"[Replace ERROR]: {str(ex)}")

conn.close()
logging.info(f"------ Connection closed ------ took:{time.time()-s}s")
