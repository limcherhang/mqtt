import pymysql
from datetime import datetime, timedelta
import time
import logging
from logging.handlers import TimedRotatingFileHandler

def connectDB(host,port,username,password):
    try:
        conn = pymysql.connect(
            host = host, 
            port = port,
            user = username,      
            passwd = password,
            #read_default_file = '~/.my.cnf'
        )
        logging.debug(f"IP: {host} Connection Succeed!")
        return conn
    except Exception as ex:
        logging.error(f"[Connection ERROR]: {str(ex)}")
        return None

def main():
    logging.debug(f"hi main func.")
    
    nowTime = datetime.now().replace(microsecond=0)
    st = (nowTime - timedelta(minutes=3)).replace(second=0)
    et = nowTime

    conn = connectDB('127.0.0.1',3306,'ecoprog','ECO4ever8118')
    prod_conn = connectDB('sg.evercomm.com',44106,'eco','ECO4ever')

    name_dict = {
        'TAG10': 'Gpio#1', 'TAG11': 'Gpio#2', 'TAG12': 'Gpio#3', 'TAG13': 'Gpio#4', 'TAG14': 'Gpio#5', 
        'TAG15': 'Gpio#6', 'TAG16': 'Gpio#7', 'TAG17': 'Gpio#8', 'TAG18': 'Gpio#9', 'TAG19': 'Gpio#10', 
        'TAG20': 'Gpio#11', 'TAG21': 'Gpio#12', 'TAG22': 'Gpio#13', 'TAG23': 'Gpio#14'
    }

    value_string = ''
    for sn, name in name_dict.items():
        logging.info(f"----- Processing {sn} {name} -----")

        with prod_conn.cursor() as data_cursor:
            sqlCommand = f"select GWts, gatewayId, name, rawdata from rawData.M2M where DBts>='{st}' and DBts<'{et}' and name='{sn}' order by DBts asc"
            logging.debug(sqlCommand)

            data_cursor.execute(sqlCommand)

            if data_cursor.rowcount == 0:
                logging.warning(f"[Data Warning]: no data for {sn} {name} from {st} to {et}")
                continue
            else:
                for data in data_cursor:
                    logging.debug(data)

                    ts = data[0]
                    gId = data[1]
                    if sn == data[2]:
                        etlName = name
                    if data[3] is None:
                        continue
                    else:
                        status = data[3]
                    
                    logging.info(f"'{ts}', {gId}, '{etlName}', '{status}'")
                    value_string += f"('{ts}', {gId}, '{etlName}', '{status}'), "

    if value_string != '':
        value_string = value_string[:-2]
        with conn.cursor() as cursor:
            replace_sql = f"replace into `dataETL`.`gpio` (`ts`, `gatewayId`, `name`, `pin0`) Values {value_string}"
            logging.debug(replace_sql)
            try:
                cursor.execute(replace_sql)
                conn.commit()
                logging.info(f"Replace Succeed!")
            except Exception as ex:
                logging.error(f"SQL: {replace_sql}")
                logging.error(f"[Replace ERROR]: {str(ex)}")

    return

if __name__ == '__main__':

    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = logging.INFO, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    s = time.time()
    main()
    logging.info(f"-------- Program Closes -------- Took: {round(time.time() - s, 2)}s")
