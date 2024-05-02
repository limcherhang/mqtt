import paho.mqtt.client as mqtt
import pymysql
import logging
import subprocess
from logging.handlers import TimedRotatingFileHandler
import datetime
import time
import configparser
import threading
import sys
import queue

class MQTT():

    def __init__(self, ip, port, user, pwd, clientId, topic, dataQ):
        self.broker = ip
        self.port = port
        self.user = user
        self.pwd = pwd
        self.clientId = clientId
        self.topic = topic
        self.q = dataQ

        self.reconnect_Flag = False
        self.client = mqtt.Client(client_id=self.clientId, clean_session=False)

    def conn(self):
        self.client.username_pw_set(self.user, self.pwd)
        self.client.reconnect_delay_set(min_delay=1, max_delay=300)
        self.client.on_connect = self.__on_connect
        self.client.on_disconnect = self.__on_disconnect
        self.client.on_message = self.__on_message_raw # [('bacnet/+/raw', 2), ('rawdata/bacnet/raw', 2)]
        
        try:
            logging.debug(f"Trying to connect to broker: {self.broker} / on topic: {self.topic}")
            self.client.connect(self.broker, port=self.port, keepalive=30)
        except Exception as ex:
            logging.error(f"[MQTT Broker({self.broker}) Connetion Failed]: {str(ex)}")
            self.reconnect_Flag = True
        
        self.client.loop_start()

    def __on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logging.debug("0: Connection successful")
            if not self.reconnect_Flag:
                logging.info(f"Connection to MQTT Broker: {self.broker} on {self.topic} Succeed!")
            else:
                logging.critical(f"RE-connection to MQTT Broker: {self.broker} on {self.topic} Succeed! at {datetime.datetime.now().replace(microsecond=0)}")
                self.reconnect_Flag = False
            
            self.client.subscribe(self.topic, qos=2) # [('bacnet/+/raw', 2), ('rawdata/bacnet/raw', 2)]
        elif rc == 1:
            logging.error("1: Connection refused - incorrect protocol version")
        elif rc == 2:
            logging.error("2: Connection refused - invalid client identifier")
        elif rc == 3:
            logging.error("3: Connection refused - server unavailable")
        elif rc == 4:
            logging.error("4: Connection refused - bad username or password")
        elif rc == 5:
            logging.error("5: Connection refused - not authorised")
        else:
            logging.error(f"{rc}: other issues")

    def __on_disconnect(self, client, userdata, rc):
        if rc != 0:
            logging.error(f"{rc}: Broker: {self.broker} Unexpected disconnection at {datetime.datetime.now().replace(microsecond=0)}.")
            self.reconnect_Flag = True

    def __on_message_raw(self, client, userdata, message):
        logging.debug(f"{message.payload.decode('utf-8')} on {message.topic} in __on_message_raw func.")
        msg = str(message.payload.decode('utf-8'))
        logging.info(f"Receiving Message: '{msg}' from {self.broker} on topic {message.topic}")
        self.q.put(msg)

def is_connected(conn, sql):
    global mysql_reconnected_flag

    s_reconnect = time.time()
    cnt = 0
    while True:
        cnt += 1
        try:
            logging.error(f"[{cnt} times]: Connection Lost ! Reconnecting...")
            conn.ping(reconnect=True)
            mysql_reconnected_flag = False
            break
        except:
            logging.error(f"Waiting 5 seconds and automatically reconnect again")
            time.sleep((5*1000000 - datetime.datetime.now().microsecond) / 1000000)
    logging.critical(f"[Reconnection Succeed]: Took: {round(time.time()-s_reconnect, 2)}s")

    with conn.cursor() as cursor:
        try:
            cursor.execute(sql)
            conn.commit()
            logging.critical(f"Insert Succeed! at is_connected func. at {datetime.datetime.now().replace(microsecond=0)}")
        except Exception as ex:
            logging.error(f"SQL: {sqlCommand}")
            logging.error(f"[MySQL Insert ERROR]: {str(ex)}")

if __name__ == '__main__':

    # Checking whether it's running
    processIds = subprocess.check_output(
        f"ps -fC python3 | awk '{{print $9}}'",
        shell = True, 
        encoding = 'utf-8'
    ).split('\n')
    print(processIds)

    id_cnt = 0
    for id in processIds:
        if id == __file__:
            id_cnt += 1
        if id_cnt>1:
            sys.exit(f"[Program Execution Failed]: {__file__} is running right now !")

    try:
        config = configparser.ConfigParser()
        config.read('config.ini')

        # General Setting
        loggingLevel = config['General']['logLevel']
        pyVersion = config['General']['pyVersion']

        # MQTT Setting
        MQTTclientId = config['MQTT']['clientId']
        MQTTuser = config['MQTT']['user']
        MQTTpwd = config['MQTT']['password']
        MQTTport = int(config['MQTT']['port'])

        MQTTips = []
        for k, v in config.items('MQTT'):
            if k.find('ip') == 0:
                MQTTips.append(v)

        subClient_rawdata = 'SubbacnetRaw' + MQTTclientId
        subTopic_rawdata = 'bacnet/+/raw' # bacnet/+/raw
        subTopic_rawdata_Hank = 'rawdata/bacnet/raw' # Hank's MQTT Topic: rawdata/protocol/raw for BACnet
        subTopic_list = [(subTopic_rawdata, 2), (subTopic_rawdata_Hank, 2)]
        
    except Exception as ex:
        sys.exit(f"[Config Setting ERROR]: {str(ex)}")

    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'./log/MQTT_SubBACnetRaw_TW.py.log', when='midnight')], 
        level = loggingLevel, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    logging.critical(f"Now: {datetime.datetime.now().replace(microsecond=0)} Program Start!")
    logging.info("================================================ Config Setting ===============================================")
    logging.info(f"Current .py Version: {pyVersion}")
    logging.info(f"Protocol: BACnet")
    logging.info(f"MQTT Brokers: {MQTTips}")
    logging.info(f"MQTT Port: {MQTTport}")
    logging.info(f"MQTT User: {MQTTuser}")
    logging.info(f"MQTT Password: {MQTTpwd}")
    logging.info(f"Subscriber ClientId: {subClient_rawdata}")
    logging.info(f"Subscriber Topic: '{subTopic_rawdata}' & '{subTopic_rawdata_Hank}'")
    logging.info("===============================================================================================================")

    dataQueue = queue.Queue(maxsize=0)
    
    for ip in MQTTips:
        subMQTT = MQTT(ip, MQTTport, MQTTuser, MQTTpwd, subClient_rawdata, subTopic_list, dataQueue)
        subMQTT.conn()

    while True:
        try:
            conn = pymysql.connect(
                host = '127.0.0.1', 
                read_default_file = '~/.my.cnf'
            )
            cursor = conn.cursor()
            mysql_reconnected_flag = False
            logging.info(f"MySQL Connection Succeed!")
            break
        except Exception as ex:
            logging.error(f"[MySQL Connection ERROR]: {str(ex)} at {datetime.datetime.now().replace(microsecond=0)}")
            time.sleep(5)

    while True:
        value_string = ''
        data_list = []
        while dataQueue.qsize() != 0:
            data = dataQueue.get()
            data_list.append(data)
        
        for data in data_list:
            if mysql_reconnected_flag:
                with open('fail_Message.txt', 'a') as msg_f:
                    msg_f.write(data + '\n')
            else:
                value_string += f"('{datetime.datetime.now().replace(microsecond=0)}', {data}), "

        if value_string != '':
            value_string = value_string[:-2]
            sqlCommand = f"insert into `rawData`.`BACnet` (`DBts`, `GWts`, `gatewayId`, `name`, `rawdata`) Values {value_string}"
            try:
                cursor.execute(sqlCommand)
                conn.commit()
                logging.debug(f"Insert Succeed!")
            except pymysql.err.OperationalError as ex:
                if isinstance(ex.args, tuple):
                    errNo = ex.args[0]
                if errNo == 2013 or errNo == 2003: # 2013: 'lost connection during query', 2003: 'Can't connect to MySQL server'
                    logging.error(f"[MySQL Connection ERROR]: {str(ex)}")
                    mysql_reconnected_flag = True
                    tConn = threading.Thread(target=is_connected, args=(conn, sqlCommand)).start()
                else:
                    logging.error(f"SQL: {sqlCommand}")
                    logging.error(f"[MySQL Insert ERROR]: {str(ex)}")
            except pymysql.err.InterfaceError as ex:
                if isinstance(ex.args, tuple):
                    errNo = ex.args[0]
                if errNo == 0:
                    logging.error(f"[MySQL Connection ERROR]: {str(ex)}")
                    mysql_reconnected_flag = True
                    is_connected(conn, sqlCommand)
            except Exception as ex:
                logging.error(f"SQL: {sqlCommand}")
                logging.error(f"[Other ERROR]: {str(ex)}")
    
        time.sleep(0.0001)