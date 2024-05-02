import paho.mqtt.client as mqtt
import pymysql
import logging
import subprocess
from logging.handlers import TimedRotatingFileHandler
import datetime
import time
import configparser
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
        self.client.message_callback_add(self.topic, self.__on_message_raw) # topic: zigbee/+/raw

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
                logging.info(f"RE-connection to MQTT Broker: {self.broker} on {self.topic} Succeed! at {datetime.datetime.now().replace(microsecond=0)}")
                self.reconnect_Flag = False

            self.client.subscribe(self.topic, qos=2)
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
        
        # insert without linkQuality on 1.41
        new_msg = ''
        msg_list = msg.split(', ')
        for index, s in enumerate(msg_list):
            if index != 3:
                new_msg += s + ', '

        self.q.put(new_msg[:-2])

def is_connected(conn,sql):
    s_reconnect = time.time()
    cnt = 0
    while True:
        cnt += 1
        try:
            logging.error(f"[{cnt} times]: Connection Lost ! Reconnecting...")
            conn.ping(reconnect=True)
            break
        except pymysql.OperationalError:
            logging.error(f"Waiting 5 seconds and automatically reconnect again")
            time.sleep((5*1000000 - datetime.datetime.now().microsecond) / 1000000)
    logging.error(f"[Reconnection Succeed]: Took: {round(time.time()-s_reconnect, 2)}s")
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

        subClient_rawdata = 'SubzigbeeRaw' + MQTTclientId
        subTopic_rawdata = 'ISS8CL/iaqsensor'
        
    except Exception as ex:
        sys.exit(f"[Config Setting ERROR]: {str(ex)}")

    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'{__file__}.log', when='D', interval=1, atTime=datetime.time(hour=0, minute=0, second=0))], 
        level = loggingLevel, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    logging.critical(f"Now: {datetime.datetime.now().replace(microsecond=0)} Program Start!")
    logging.info("================================================ Config Setting ===============================================")
    logging.info(f"Current .py Version: {pyVersion}")
    logging.info(f"Protocol: zigbee")
    logging.info(f"MQTT Brokers: {MQTTips}")
    logging.info(f"MQTT Port: {MQTTport}")
    logging.info(f"MQTT User: {MQTTuser}")
    logging.info(f"MQTT Password: {MQTTpwd}")
    logging.info(f"Subscriber ClientId: {subClient_rawdata}")
    logging.info(f"Subscriber Topic: {subTopic_rawdata}")
    logging.info("===============================================================================================================")

    dataQueue = queue.Queue(maxsize=0)
    
    for ip in MQTTips:
        subMQTT = MQTT(ip, MQTTport, MQTTuser, MQTTpwd, subClient_rawdata, subTopic_rawdata, dataQueue)
        subMQTT.conn()

    while True:
        try:
            conn = pymysql.connect(
                host = '127.0.0.1', 
                read_default_file = '~/.my.cnf'
            )
            cursor = conn.cursor()
            logging.debug(f"MySQL Connection Succeed!")
            break
        except Exception as ex:
            logging.error(f"[MySQL Connection ERROR]: {str(ex)} at {datetime.datetime.now().replace(microsecond=0)}")
            time.sleep(5)

    while True:
        value_string = ''
        if not dataQueue.empty():
            value_string = dataQueue.get()
            #
            topic_list = subTopic_rawdata.split('/')
            gId = topic_list[0]
            #
            #value_string = f"('{datetime.datetime.now().replace(microsecond=0)}','{gId}','" +   value_string  + "'" + ')'
            value_string = f"('{datetime.datetime.now().replace(microsecond=0)}','302','" +   value_string  + "'" + ')'
            sqlCommand = f"insert into `rawData`.`mqttIAQ` (`ts`,`gatewayId`, `data`) Values {value_string}"
            logging.debug(sqlCommand)
            try:
                cursor.execute(sqlCommand)
                conn.commit()
                logging.debug(f"Insert Succeed!")
            except pymysql.err.OperationalError as ex:
                logging.debug(f"MySQL Insert ERROR!")
            except Exception as ex:
                logging.error(f"[Other ERROR]: {str(ex)}")
                if isinstance(ex.args, tuple):
                    errNo = ex.args[0]
                if errNo == 0:
                    logging.error(f"[MySQL Connection ERROR]: {str(ex)}")
                    is_connected(conn,sqlCommand)
        time.sleep(0.01)
