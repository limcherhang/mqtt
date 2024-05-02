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
import json

class MQTT():
    #初始化
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
    # 連線設定 MQTT 
    def conn(self):
        self.client.username_pw_set(self.user, self.pwd)
        self.client.reconnect_delay_set(min_delay=1, max_delay=300)
        self.client.on_connect = self.__on_connect
        self.client.on_disconnect = self.__on_disconnect
        #self.client.on_message = self.__on_message_raw # 'iotdata/#'

        self.client.message_callback_add('iotdata/+/powerMeter/#', self.__on_message_pm) # 'iotdata/+/powerMeter/#'
        self.client.message_callback_add('iotdata/+/flowMeter/#', self.__on_message_flow) # 'iotdata/+/flowMeter/#'
        self.client.message_callback_add('iotdata/+/dTemperature/#', self.__on_message_temp)# 'iotdata/+/dTemperature/#'

        try:
            logging.debug(f"Trying to connect to broker: {self.broker} / on topic: {self.topic}")
            self.client.connect(self.broker, port=self.port, keepalive=30)
        except Exception as ex:
            logging.error(f"[MQTT Broker({self.broker}) Connetion Failed]: {str(ex)}")
            self.reconnect_Flag = True
        # 開始連線，執行設定的動作和處理重新連線問題
        # 也可以手動使用其他loop函式來進行連接
        self.client.loop_start()
    #訂閱端的topic設定
    def __on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logging.debug("0: Connection successful")
            if not self.reconnect_Flag:
                logging.info(f"Connection to MQTT Broker: {self.broker} on {self.topic} Succeed!")
            else:
                logging.critical(f"RE-connection to MQTT Broker: {self.broker} on {self.topic} Succeed! at {datetime.datetime.now().replace(microsecond=0)}")
                self.reconnect_Flag = False
            #qos=2 發送訊息確認三向交握 是否有收到訊息，確認一次
            self.client.subscribe(self.topic, qos=2) # 'iotdata/#'
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
    #斷線
    def __on_disconnect(self, client, userdata, rc):
        if rc != 0:
            logging.error(f"{rc}: Broker: {self.broker} Unexpected disconnection at {datetime.datetime.now().replace(microsecond=0)}.")
            self.reconnect_Flag = True
    # 當接收到從伺服器發送的訊息時要進行的動作(powermeter)
    def __on_message_pm(self, client, userdata, message):
        logging.debug(f"{message.payload.decode('utf-8')} on {message.topic} in __on_message_pm func.")
        # 轉換編碼utf-8才看得懂中文
        msg = str(message.payload.decode('utf-8'))
        logging.info(f"Receiving Message: '{msg}' from {self.broker} on topic {message.topic}")

        msg_list = message.topic.split('/')
        msg_dict = json.loads(msg)

        gId = msg_list[1]
        ieee = msg_list[3]
        receivedSync = msg_dict.get('ts')
        ch1Watt = int(float(msg_dict.get('value')) * 1000)

        msg_tuple = (f"{gId}, '{ieee}', '{receivedSync}', {ch1Watt}", msg_list[2])
        
        self.q.put(msg_tuple)
    # 當接收到從伺服器發送的訊息時要進行的動作(flow)
    def __on_message_flow(self, client, userdata, message):
        logging.debug(f"{message.payload.decode('utf-8')} on {message.topic} in __on_message_flow func.")
        # 轉換編碼utf-8才看得懂中文
        msg = str(message.payload.decode('utf-8'))
        logging.info(f"Receiving Message: '{msg}' from {self.broker} on topic {message.topic}")
        
        msg_list = message.topic.split('/')
        msg_dict = json.loads(msg)

        gId = msg_list[1]
        ieee = msg_list[3]
        receivedSync = msg_dict.get('ts')
        flowRate = float(msg_dict.get('value'))

        msg_tuple = (f"{gId}, '{ieee}', '{receivedSync}', {flowRate}", msg_list[2])
        
        self.q.put(msg_tuple)
    # 當接收到從伺服器發送的訊息時要進行的動作 (temp)
    def __on_message_temp(self, client, userdata, message):
        logging.debug(f"{message.payload.decode('utf-8')} on {message.topic} in __on_message_temp func.")
        # 轉換編碼utf-8才看得懂中文
        msg = str(message.payload.decode('utf-8'))
        logging.info(f"Receiving Message: '{msg}' from {self.broker} on topic {message.topic}")

        msg_list = message.topic.split('/')
        msg_dict = json.loads(msg)

        gId = msg_list[1]
        ieee = msg_list[3]
        receivedSync = msg_dict.get('ts')
        temp = float(msg_dict.get('value'))

        msg_tuple = (f"{gId}, '{ieee}', '{receivedSync}', {temp}", msg_list[4])
        self.q.put(msg_tuple)
#連線資料庫
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
            logging.error(f"SQL: {sql}")
            logging.error(f"[MySQL Insert ERROR]: {str(ex)}")
#執行資料庫
def sql(flag, value_string):

    global mysql_reconnected_flag

    value_string = value_string[:-2]
    
    if flag == 'powerMeter':
        sqlCommand = f"insert into `iotmgmt`.`pm` (`ts`, `gatewayId`, `ieee`, `receivedSync`, `ch1Watt`) Values {value_string}"
    elif flag == 'flowMeter':
        sqlCommand = f"insert into `iotmgmt`.`ultrasonicFlow2` (`ts`, `gatewayId`, `ieee`, `receivedSync`, `flowRate`) Values {value_string}"
    elif flag == 'dTemperature':
        sqlCommand = f"insert into `iotmgmt`.`dTemperature` (`ts`, `gatewayId`, `ieee`, `receivedSync`, `temp1`, `temp2`, `temp3`, `temp4`) Values {value_string}"
    
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
#主程式
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
        config.read('PPSS_config.ini')

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

        subClient_rawdata = 'SubppssRaw' + MQTTclientId # 'ProductionClient@ + yyyy-MM-dd_HH:mm:ss'
        subTopic_rawdata_pm = 'iotdata/+/powerMeter/#'
        subTopic_rawdata_flow = 'iotdata/+/flowMeter/#'
        subTopic_rawdata_temp = 'iotdata/+/dTemperature/#'
        
        subTopic_list = [(subTopic_rawdata_pm, 2), (subTopic_rawdata_flow, 2), (subTopic_rawdata_temp, 2)] # [('iotdata/+/powerMeter/#', 2), ('iotdata/+/flowMeter/#', 2), ('iotdata/+/dTemperature/#', 2)]

    except Exception as ex:
        sys.exit(f"[Config Setting ERROR]: {str(ex)}")

    logging.basicConfig(
        handlers=[TimedRotatingFileHandler(f'./log/{__file__}.log', when='midnight')], 
        level = loggingLevel, 
        format = '%(asctime)s.%(msecs)03d %(name)s [%(levelname)s] %(message)s', 
        datefmt = '%Y-%m-%d %H:%M:%S'
    )

    logging.critical(f"Now: {datetime.datetime.now().replace(microsecond=0)} Program Start!")
    logging.info("================================================ Config Setting ===============================================")
    logging.info(f"Current .py Version: {pyVersion}")
    logging.info(f"Protocol: Zigbee")
    logging.info(f"MQTT Brokers: {MQTTips}")
    logging.info(f"MQTT Port: {MQTTport}")
    logging.info(f"MQTT User: {MQTTuser}")
    logging.info(f"MQTT Password: {MQTTpwd}")
    logging.info(f"Subscriber ClientId: {subClient_rawdata}")
    logging.info(f"Subscriber Topic: '{subTopic_list}'")
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

    data_list = []
    op_list = []
    while True:
        pm_value_string = ''
        flow_value_string = ''
        temp_value_string = ''

        while dataQueue.qsize() != 0:
            data, type = dataQueue.get()

            if mysql_reconnected_flag:
                with open(f'{type}_fail_Message.txt.{datetime.datetime.now().date()}', 'a') as msg_f:
                    msg_f.write(data + '\n')
            else:
                if type == 'powerMeter':
                    pm_value_string += f"('{datetime.datetime.now()}', {data}), "
                elif type == 'flowMeter':
                    flow_value_string += f"('{datetime.datetime.now()}', {data}), "
                else:
                    #temp_value_string += f"('{datetime.datetime.now()}', {data}), "
                    process_list = data.replace("'","").split(', ')
                    process_list.append(type)
                    
                    ts = datetime.datetime.strptime(process_list[2], '%Y-%m-%d %H:%M:%S').replace(second=0)
                    if ts not in op_list:
                        op_list.append(ts)

                    data_list.append(process_list)
            
            time.sleep(0.1)
        
        #logging.info(f"--------------- Before ---------------")
        temp_list = []

        logging.warning(f"-------- data length: {len(data_list)} --------")
        for index, data in enumerate(data_list):
            ts = datetime.datetime.strptime(data[2], '%Y-%m-%d %H:%M:%S')
            if (datetime.datetime.now() - ts).seconds / 60 >= 1:
                temp_list.append(index)
            logging.warning(f"{[index]} {data}")
        #logging.info(f"--------------- Before ---------------")
        
        for index in temp_list[::-1]:
            logging.debug(f"deleting index: {index}")
            del data_list[index]

        for ts in op_list:
            for _gId, l in {'112':['ppssbms000f', 'ppssbms0010', 'ppssbms0011', 'ppssbms0012'], '113':['ppssbms001f', 'ppssbms0020', 'ppssbms0021', 'ppssbms0022', 'ppssbms0024', 'ppssbms0025']}.items():
                for _ieee in l:
                    logging.debug(f"--- Processing {_gId} {_ieee} ---")
                    temp1 = -999
                    temp2 = -999
                    temp3 = -999
                    temp4 = -999
                    index_list = []
                    for index, data in enumerate(data_list):
                        if datetime.datetime.strptime(data[2], '%Y-%m-%d %H:%M:%S').replace(second=0) == ts and data[0] == _gId and data[1] == _ieee:
                            if data[4] == 'tempChws':
                                temp1 = data[3]
                            elif data[4] == 'tempChwr':
                                temp2 = data[3]
                            elif data[4] == 'tempCws':
                                temp3 = data[3]
                            elif data[4] == 'tempCwr':
                                temp4 = data[3]
                            index_list.append(index)
                    
                    if temp1 != -999 and temp2 != -999 and temp3 != -999 and temp4 != -999:
                        temp_value_string += f"('{datetime.datetime.now()}', {_gId}, '{_ieee}', '{data[2]}', {temp1}, {temp2}, {temp3}, {temp4}), "
                        logging.debug(f"{_gId}, '{_ieee}', '{data[2]}', {temp1}, {temp2}, {temp3}, {temp4}")
                        logging.debug(f"index list for delete: {index_list}")
                        for index in index_list[::-1]:
                            del data_list[index]
                    elif _ieee == 'ppssbms0024' and temp1 != -999:
                        temp_value_string += f"('{datetime.datetime.now()}', {_gId}, '{_ieee}', '{data[2]}', {temp1}, NULL, NULL, NULL), "
                        logging.debug(f"{_gId}, '{_ieee}', '{data[2]}', {temp1}, NULL, NULL, NULL")
                        for index in index_list[::-1]:
                            del data_list[index]
                    elif _ieee == 'ppssbms0025' and temp1 != -999:
                        temp_value_string += f"('{datetime.datetime.now()}', {_gId}, '{_ieee}', '{data[2]}', {temp1}, NULL, NULL, NULL), "
                        logging.debug(f"{_gId}, '{_ieee}', '{data[2]}', {temp1}, NULL, NULL, NULL")
                        for index in index_list[::-1]:
                            del data_list[index]

        if pm_value_string != '':
            sql('powerMeter', pm_value_string)
        if flow_value_string != '':
            sql('flowMeter', flow_value_string)
        if temp_value_string != '':
            sql('dTemperature', temp_value_string)

        time.sleep(30)