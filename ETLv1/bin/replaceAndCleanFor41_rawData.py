import pymysql
import logging
import os
import datetime
import time

from logging.handlers import TimedRotatingFileHandler

class MySQLConn:
    def __init__(self, db_env: dict, autocommit: bool=True) -> None:
        self.host=db_env['host']
        self.port=int(db_env['port'])
        # self.user=db_env['user']
        # self.password=db_env['password']
        self.autocommit = autocommit
        self.connect()
        
    def connect(self,):
        self.connection = pymysql.connect(
            host=self.host,
            port=int(self.port),
            # user=self.user,
            # password=self.password,
            autocommit=self.autocommit,
            charset='utf8mb4',
            read_default_file = '~/.my.cnf'
        )
        logger.info("=================================================")
        logger.info("our db_config:")
        logger.info(f"host: {self.host}")
        logger.info(f"port: {self.port}")
        # logger.info(f"user: {self.user}")
        # logger.info(f"password: {self.password}")
        logger.info(f"autocommit: {self.autocommit}")
        # logger.info(f"dictionary mode: {self.dict_mode}")
        logger.info("=================================================")

    def cursor(self,):       
        try:
            return self.connection.cursor()
        except pymysql.err.OperationalError as e:
            logger.error(f"Lost connection to MySQL server: {e}")
            self.connect()
            return self.connection.cursor()
        
    def close(self,):
        return self.connection.close()

def get_logger(logPath: str, filename: str, level: str=logging.DEBUG):
    
    check_if_folder_exists(logPath)
    logfile = f"{logPath}/{filename}"

    logging.basicConfig(handlers=[TimedRotatingFileHandler(logfile , when='midnight')], level=level, format='%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    
    logger = logging.getLogger(__name__)
    return logger

def check_if_folder_exists(path):
    try:
        os.mkdir(path)
    except FileExistsError:
        pass

def process_delete(schema: str, table: str, start: datetime.datetime, end: datetime.datetime, cursor: pymysql.cursors.Cursor):
    while True:
        if "API" in table and table != 'RESTAPI':
            delete_sql = f"""
                DELETE FROM {schema}.{table} WHERE APIts >= '{start}' AND APIts < '{end}' LIMIT 10000;
            """
        else:
            delete_sql = f"""
                DELETE FROM {schema}.{table} WHERE GWts >= '{start}' AND GWts < '{end}' LIMIT 10000;
            """
        try:
            logger.debug(delete_sql)
            cursor.execute(delete_sql)
            logger.info(f"DELETE {table} from {start} to {end} Succeed!")
            
        except Exception as ex:
            logger.error(f"Error executing {delete_sql}")
            logger.error(f"Error message: {ex}")
        if cursor.rowcount == 0:
            break
        
        time.sleep(1)

def convert_sec(times):
    if times < 60:
        result = f"{round(times)} sec"
    elif times < 3600:      # times < 3600 sec = 60 sec * 60 min = 1 hour
        m = times // 60
        s = round(times - m*60)
        result = f"{m} minutes {s} sec"
    elif times < 86400:     # times < 86400 sec = 3600 sec * 24 hour = 1 day
        h = times // 3600
        s = times - h*3600
        m = s // 60
        s = round(s - m*60)
        result = f"{h} hour {m} minutes {s} sec"
    else:                   # times >= 1 day
        d = times // 86400
        s = times - d*86400
        h = s // 3600
        s = s - h*3600
        m = s // 60
        s = round(s - m*60)
        result = f"{d} day {h} hour {m} minutes {s} sec"
    return result

db_config = {
    'host': "127.0.0.1",
    'port': 3306,
}

# db_config = {
#     'host': "sg.evercomm.com",
#     'port': 44206,
#     'user': "eco",
#     'password': "ECO4ever",
# }

if __name__ == '__main__':
    startRunTime = time.time()
    file = __file__
    basename = os.path.basename(file)
    filename = os.path.splitext(basename)[0]
    logPath = os.getcwd()+ '/log'

    logger = get_logger(logPath, filename+'.log')

    conn = MySQLConn(db_config)

    nowTime = datetime.datetime.now().date()

    process_date = nowTime - datetime.timedelta(days=1) # 昨天的日期，昨天以前的都要replace和清掉

    with conn.cursor() as cursor:
        if process_date.month == 1 and process_date.day == 1: # 如果昨天的日期是2024年1月1號，那我們要處理的月份就是去年的資料也就是2024-1=2023年
            year = process_date.year - 1
        else:
            year = process_date.year
        schema = 'rawData'
        cursor.execute(f"SELECT SUBSTRING_INDEX(table_name, '_', 1) as tbl_name FROM information_schema.tables WHERE table_schema = '{schema}{year}' group by tbl_name")

        for (table, ) in cursor.fetchall():

            logger.info(f"----------- Processing {table} ---------")
            if "API" in table and table != 'RESTAPI':
                sqlCommand = f"""
                    SELECT DISTINCT(DATE(APIts)) FROM {schema}.{table} WHERE APIts < '{process_date}';
                """
            else:
                sqlCommand = f"""
                    SELECT DISTINCT(DATE(GWts)) FROM {schema}.{table} WHERE GWts < '{process_date}';
                """

            logger.debug(sqlCommand)
            cursor.execute(sqlCommand)
            for (date, ) in cursor.fetchall():
                write_month = f"{date.month:02}"
                write_year = date.year
                date = datetime.datetime(date.year, date.month, date.day, 0, 0, 0)
                next_date = date + datetime.timedelta(days=1)

                while date.timestamp() < next_date.timestamp():

                    next_time = date + datetime.timedelta(hours=1)
                    if "API" in table and table != 'RESTAPI':
                        replace_sql = f"""
                            REPLACE INTO {schema}{write_year}.{table}_{write_month}
                            (
                                SELECT * FROM {schema}.{table} WHERE APIts >= '{date}' AND APIts < '{next_time}'
                                EXCEPT
                                SELECT * FROM {schema}{write_year}.{table}_{write_month} WHERE APIts >= '{date}' AND APIts < '{next_time}'
                            )
                        """

                        try:
                            logger.debug(replace_sql)
                            cursor.execute(replace_sql)
                            logger.info("REPLACE Succeed!")
                            errorCode = 0
                        except Exception as ex:
                            logger.error(f"Error executing {replace_sql}")
                            logger.error(f"Error message: {ex}")
                            errorCode = 1

                        if errorCode == 1:
                            logger.error(f"Since {replace_sql} is unsuccessful, detele is not executed")
                        else:
                            sqlCommand = f"""
                                SELECT * FROM {schema}.{table} WHERE APIts >= '{date}' AND APIts < '{next_time}'
                                EXCEPT
                                SELECT * FROM {schema}{write_year}.{table}_{write_month} WHERE APIts >= '{date}' AND APIts < '{next_time}'
                            """
                            cursor.execute(sqlCommand)
                            exist_data = cursor.fetchall()
                            if exist_data == ():
                                process_delete(schema, table, date, next_time, cursor) 
                            else:
                                logger.error(f"It still have some data doesn't move to rawData{year}")
                                logger.error(exist_data)
                        del errorCode
                    else:
                        replace_sql = f"""
                            REPLACE INTO {schema}{write_year}.{table}_{write_month}
                            (
                                SELECT * FROM {schema}.{table} WHERE GWts >= '{date}' AND GWts < '{next_time}'
                                EXCEPT
                                SELECT * FROM {schema}{write_year}.{table}_{write_month} WHERE GWts >= '{date}' AND GWts < '{next_time}'
                            )
                        """
                        try:
                            logger.debug(replace_sql)
                            cursor.execute(replace_sql)
                            logger.info("REPLACE Succeed!")
                            errorCode = 0
                        except Exception as ex:
                            logger.error(f"Error executing {replace_sql}")
                            logger.error(f"Error message: {ex}")
                            errorCode = 1
                        if errorCode == 1:
                            logger.error(f"Since {replace_sql} is unsuccessful, detele is not executed")
                        else:
                            if table == 'ZB':
                                sqlCommand = f"""
                                    SELECT DBts, GWts, ZBts, ieee, clusterID FROM {schema}.{table} WHERE GWts >= '{date}' AND GWts < '{next_time}' GROUP BY DBts, GWts, ZBts, ieee, clusterID
                                    EXCEPT
                                    SELECT DBts, GWts, ZBts, ieee, clusterID FROM {schema}{write_year}.{table}_{write_month} WHERE GWts >= '{date}' AND GWts < '{next_time}'
                                """
                            else:
                                sqlCommand = f"""
                                    SELECT * FROM {schema}.{table} WHERE GWts >= '{date}' AND GWts < '{next_time}'
                                    EXCEPT
                                    SELECT * FROM {schema}{write_year}.{table}_{write_month} WHERE GWts >= '{date}' AND GWts < '{next_time}'
                                """

                            cursor.execute(sqlCommand)
                            exist_data = cursor.fetchall()
                            if exist_data == ():
                                process_delete(schema, table, date, next_time, cursor) 
                            else:
                                logger.error(f"It still have some data doesn't move to rawData{year}")
                                logger.error(exist_data)
                        del errorCode
                    date = next_time

    conn.close()
    endRuntime = time.time()

    logger.info(f"RUN TIME: {convert_sec(endRuntime-startRunTime)}")