from datetime import datetime
import time
from paho.mqtt import client as mqtt_client
import mysql.connector
import os
import shutil
import threading
import logging
from logging.handlers import RotatingFileHandler


mutex = threading.Lock()

localFileSave = "bacnetdata.txt"
tempFile = "bacnettmp.txt"

topic = "rawdata/bacnet/raw"
clientId = "SUBbacnetraw"
logLevel = ""

reconnect = False



with open('config') as f:
    lines = f.readlines()
for data in lines:
    temp = data.split("=")

    if(temp[0] == "broker"):
        broker = temp[1].split("\n")[0]
    elif(temp[0] == "port"):
        port = int(temp[1].split("\n")[0])
    elif(temp[0] == "user"):
        user = temp[1].split("\n")[0]
    elif(temp[0] == "passwd"):
        passwd = temp[1].split("\n")[0]
    elif(temp[0] == "clientid"):
        clientId += temp[1].split("\n")[0]
    elif(temp[0] == "logLevel"):
        logLevel = temp[1].split("\n")[0]

dictLevel = {"DEBUG":10,"INFO":20,"WARNING":30,"ERROR":40,"CRITICAL":50}

logging.basicConfig(
    handlers=[RotatingFileHandler('log/bacnetraw.log', maxBytes=1000000, backupCount=10)],
    format='%(asctime)s %(name)s %(levelname)s %(message)s',
    level=dictLevel[logLevel]
    )




class varInit:
	def __init__(self):
        
		self.sqlbacnetraw = "INSERT INTO rawData.BACnet VALUES "
		self.sqlClockIn = "INSERT INTO rawData.GWClockIn VALUES "


def on_disconnect(client, userdata, rc):
    global reconnect
    reconnect = True
    logging.error("disconnect to MQTT")

def on_connect(client, userdata, flags, rc):
    global reconnect
    if rc == 0:
        logging.info("Connected to MQTT Broker!")
        client.subscribe(topic, qos=2)
        if(reconnect):
            reconnect = False
            logging.info("MQTT subbacnetraw reconnected.")
    else:
        logging.error("Failed to connect, return code %d\n", rc)


def on_message(client, userdata, msg):
    msgraw=str(msg.payload.decode("utf-8"))
    logging.info(f"subscribe:{msgraw} topic: {msg.topic}")
    
    mutex.acquire()
    with open(localFileSave,"a+") as f:
        f.write(msgraw+"\r\n")
    mutex.release()




if(__name__ == "__main__"):
    #out = check_output("ps aux | grep MQSUB_bacnetraw.py | grep -v 'grep' | awk '{print $2}'", shell=True).decode().split('\n')
    #if(len(out) > 2):
    #    print("This process was starting ...  will exit")
    #    logging.error("This process was starting ...  will exit")
    #    sys.exit()
    
    while(1):
        try:
            #conn = mysql.connector.connect(host='192.168.1.21',port=3306,user='admin',passwd='admin',charset='utf8')
            pwd =os.environ['HOME']
            conn = mysql.connector.connect(
                host="127.0.0.1",
                option_files = f'{pwd}/.my.cnf'
            )
            cursor = conn.cursor()
            break
        except Exception as e:
            logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
            time.sleep(5)
        
    var = varInit()


    client = mqtt_client.Client(clientId,clean_session=False)
    client.on_connect = on_connect
    client.on_disconnect = on_disconnect
    client.on_message = on_message
    client.username_pw_set(user,passwd)
    client.reconnect_delay_set(min_delay=1, max_delay=5)
    while(1):
        try:
            client.connect(broker, port, 60)
            break
        except Exception as e:
            logging.error(f"connect error {e}")
            time.sleep(10)
#    client.loop_forever()   # loop_forever(timeout=1.0, max_packets=1, retry_first_connection=False)

#================================================================================================================
#=========================================check receive data size & save=========================================
    client.loop_start()
    time.sleep(0.1)
    while True:
        if reconnect == False:
            if os.path.isfile(localFileSave):
                with open(localFileSave,"r") as f:
                    lines = f.readlines()
                
                if(len(lines) > 0 and len(lines) <= 100):
                    mutex.acquire()

                    shutil.copyfile(localFileSave,tempFile)
                    with open(localFileSave,"w")as f_w:
                        f_w.write("")

                    mutex.release()

                    with open(tempFile,"r") as f:
                        lines = f.readlines()

                    while(len(lines)):
                        rawTemp = lines[0]

                        if(rawTemp[:6] == "INSERT"):
                            sql = rawTemp
                        else:
                            raw = "'" + str(datetime.now()) + "'," + rawTemp[:len(rawTemp)-1]
                            sql = f"INSERT INTO rawData.BACnet VALUES ({raw});"


                        try:
                            cursor.execute(sql)
                            conn.commit()
                        except Exception as e:	#data line error
                            logging.error(f"insert error: {e}")
                            if(not conn.is_connected()):
                                while(1):
                                    try:
                                        conn.reconnect()
                                        
                                        if(conn.is_connected()):
                                            cursor.execute(sql)
                                            conn.commit()
                                            logging.info("reconnecting")
                                            break
                                    except Exception as e:
                                        logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                        time.sleep(5)

                            
                        with open(tempFile,"w")as f_w:
                            for line in lines:
                                if(rawTemp in line):
                                    continue
                                f_w.write(line)
                        with open(tempFile,"r")as f:
                            lines = f.readlines()


                elif(len(lines) > 100):
                    mutex.acquire()

                    shutil.copyfile(localFileSave,tempFile)
                    with open(localFileSave,"w")as f_w:
                        f_w.write("")

                    mutex.release()

                    with open(tempFile,"r") as f:
                        lines = f.readlines()

                    for i in range(len(lines)):
                        raw = "'" + str(datetime.now()) + "'," + lines[i][:len(lines[i])-1]
                        
                        if(raw[:6] == "INSERT"):
                            raw = raw.split("VALUES")[1][1:]
                            var.sqlClockIn += f"({raw}),"
                        else:
                            var.sqlbacnetraw += f"({raw}),"

                        #==================================================================1000 row saves once==================================================================
                        if(i != 0 and i % 1000 == 0):
                            try:
                                if(var.sqlClockIn[-2:-1] == ")"):
                                    cursor.execute(var.sqlClockIn[:-1])
                                    conn.commit()
                            except Exception as e:
                                logging.error(f"insert ClockIn error: {e}")
                                if(not conn.is_connected()):
                                    while(1):
                                        try:
                                            conn.reconnect()
                                            
                                            if(conn.is_connected()):
                                                logging.info("reconnecting") 

                                                try:
                                                    if(var.sqlClockIn[-2:-1] == ")"):
                                                        cursor.execute(var.sqlClockIn[:-1])
                                                        conn.commit()
                                                except Exception as e:
                                                    logging.error(f"insert ClockIn error: {e}")
                                        except Exception as e:
                                            logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                            time.sleep(5)

                            try:
                                if(var.sqlbacnetraw[-2:-1] == ")"):
                                    cursor.execute(var.sqlbacnetraw[:-1])
                                    conn.commit()
                            except Exception as e:
                                logging.error(f"insert db error: {e}")
                                if(not conn.is_connected()):
                                    while(1):
                                        try:
                                            conn.reconnect()
                                            
                                            if(conn.is_connected()):
                                                logging.info("reconnecting") 

                                                try:
                                                    if(var.sqlbacnetraw[-2:-1] == ")"):
                                                        cursor.execute(var.sqlbacnetraw[:-1])
                                                        conn.commit()
                                                except Exception as e:
                                                    logging.error(f"insert db error: {e}")
                                        except Exception as e:
                                            logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                            time.sleep(5)
                            
                            var.__init__()
                            logging.info("Insert 1000 rows, waiting for 1 sec")
                            time.sleep(1)
                        #==================================================================1000 row saves once==================================================================
                    if(conn.is_connected()):
                        try:
                            if(var.sqlClockIn[-2:-1] == ")"):
                                cursor.execute(var.sqlClockIn[:-1])
                                conn.commit()
                        except Exception as e:
                            logging.error(f"insert ClockIn error: {e}")

                        try:
                            if(var.sqlbacnetraw[-2:-1] == ")"):
                                cursor.execute(var.sqlbacnetraw[:-1])
                                conn.commit()
                        except Exception as e:
                            logging.error(f"insert db error: {e}")
                        
                    else:
                        while(1):
                            try:
                                conn.reconnect()
                                
                                if(conn.is_connected()):
                                    logging.info("reconnecting")

                                    try:
                                        if(var.sqlClockIn[-2:-1] == ")"):
                                            cursor.execute(var.sqlClockIn[:-1])
                                            conn.commit()
                                    except Exception as e:
                                        logging.error(f"insert ClockIn error: {e}")
                                        
                                    try:
                                        if(var.sqlbacnetraw[-2:-1] == ")"):
                                            cursor.execute(var.sqlbacnetraw[:-1])
                                            conn.commit()
                                    except Exception as e:
                                        logging.error(f"insert db error: {e}")

                                    break
                            except Exception as e:
                                logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                time.sleep(5)

                    
                    #os.remove(tempFile)
                    var.__init__()
                    logging.info("Insert all complete, waiting for 1 sec")

        time.sleep(1)

