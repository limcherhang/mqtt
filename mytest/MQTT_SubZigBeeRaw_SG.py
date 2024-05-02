import _logger
from mysql_connection import MySQLConn
from MQTT import MQTT
import subprocess
import sys
import configparser
import queue
import datetime
import time

logger = _logger.get_logger('./log/MQTT_SubZigBeeRaw_SG.log')

processIds = subprocess.check_output(
    f"ps -fC python3 | awk '{{print $9}}'",
    shell=True,
    encoding='utf-8',
).split('\n')

id_cnt = 0
for id in processIds:
    if id == __file__:
        id_cnt+=1
    if id_cnt > 1:
        sys.exit(f"[Program Execution Failed]:{__file__} us running right now!")

try:
    config = configparser.ConfigParser()
    config.read('config_TW.ini')

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
    subTopic_rawdata = 'zigbee/+/raw' # 'zigbee/+/raw'  #優點:一對多、訊息分類，訂閱者只取自己相關的訊息
    subTopic_rawdata_Hank = 'rawdata/zb/raw' # Hank's MQTT Topic: 'rawdata/zb/raw' for Zigbee #缺點 一對一
    subTopic_list = [(subTopic_rawdata, 2), (subTopic_rawdata_Hank, 2)]
except Exception as ex:
    sys.exit(f"[Config Setting ERROR]: {str(ex)}")

logger.critical(f"Now: {datetime.datetime.now().replace(microsecond=0)} Program Start!")
logger.info("================================================ Config Setting ===============================================")
logger.info(f"Current .py Version: {pyVersion}")
logger.info(f"Protocol: Zigbee")
logger.info(f"MQTT Brokers: {MQTTips}")
logger.info(f"MQTT Port: {MQTTport}")
logger.info(f"MQTT User: {MQTTuser}")
logger.info(f"MQTT Password: {MQTTpwd}")
logger.info(f"Subscriber ClientId: {subClient_rawdata}")
logger.info(f"Subscriber Topic: '{subTopic_rawdata}' & '{subTopic_rawdata_Hank}'")
logger.info("===============================================================================================================")

dataQueue = queue.Queue(maxsize=0)

for ip in MQTTips:
    subMQTT = MQTT(ip, MQTTport, MQTTuser, MQTTpwd, subClient_rawdata, subTopic_list, dataQueue)
    subMQTT.conn()

while True:
    try:
        connection = MySQLConn("own", dict_mode=False)
        cursor = connection.setup()
        mysql_reconnected_flag = False
        logger.info("MySQL connection Succeed!")
        break
    except Exception as ex:
        logger.error(f"cannot connected MySQL")
        break

while True:
    value_string = ''
    data_list = []
    while dataQueue.qsize() != 0:
        data = dataQueue.get()
        data_list.append(data)
    
    for data in data_list:
        new_msg = ''
        logger.info(f"data length: {len([d for d in data.split(',')])}")
        logger.info(f"data: {data}")
        msg_list = data.split(',')
        if len(msg_list) == 6:
            
            for index, s in enumerate(msg_list):
                if index == 2:
                    new_msg += s + ', NULL, '
                else:
                    new_msg += s + ', '
            logger.info(f'change msg{new_msg}')
        if mysql_reconnected_flag:
            with open('fail_Message.txt', 'a') as msg_f:
                msg_f.write(data + '\n')
        else:
            if new_msg:
                value_string += f"('{datetime.datetime.now().replace(microsecond=0)}', {new_msg[:-2]}), "
            else:
                value_string += f"('{datetime.datetime.now().replace(microsecond=0)}', {data}), "
    
    if value_string != '':
        value_string = value_string[:-2]
        sqlCommand = f"insert into `rawData`.`ZB` (`DBts`, `GWts`, `ZBts`, `gatewayId`, `linkQuality`, `ieee`, `clusterID`, `rawdata`) Values {value_string}"

        logger.debug(f"query:{sqlCommand}")

        cursor.execute(sqlCommand)

        # logger.info("The following value is going to insert to rawData.ZB!")
        # logger.info(f"{value_string}")

        logger.debug("Insert Succeed!")



    time.sleep(0.0001)