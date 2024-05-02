import configparser
import logging
from logging.handlers import TimedRotatingFileHandler
import queue
import paho.mqtt.client as mqtt
import pymysql
import time
import datetime
import threading
import subprocess
import sys

# 回调函数 - 当客户端连接到代理时调用
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))
    # 订阅一个主题
    client.subscribe("your/topic")

# 回调函数 - 当接收到来自代理的消息时调用
def on_message(client, userdata, msg):
    print("Received message: "+msg.payload.decode())

# 创建一个MQTT客户端实例
client = mqtt.Client()

# 设置连接回调函数
client.on_connect = on_connect

# 设置消息接收回调函数
client.on_message = on_message

# 连接到MQTT代理（通常是代理的IP地址或主机名）
client.connect("mqtt.emscloud.net", 1883, 60)

# 保持连接
client.loop_start()

client_rawdata = 'SubbacnetRaw' + 'aaron'
topic_rawdata = 'bacnet/+/raw'
topic_rawdata_hank = 'rawdata/bacnet/raw'
topic_list = [(topic_rawdata, 2), (topic_rawdata_hank, 2)]
print(topic_list)
print()
# 发布消息到主题
client.subscribe(topic_list, qos=2)

# 等待一段时间
time.sleep(5)

# 断开连接
client.disconnect()