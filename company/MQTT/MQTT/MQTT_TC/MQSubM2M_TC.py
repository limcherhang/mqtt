from datetime import datetime
import time
from paho.mqtt import client as mqtt_client
import mysql.connector
import os
import shutil
import threading
import json
import logging
from logging.handlers import RotatingFileHandler


mutex = threading.Lock()

localFileSave = "M2Mdata.txt"
tempFile = "M2MdataTemp.txt"

clientId = "SUBM2Mraw"
topic = "rawdata/M2M/raw"
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
    handlers=[RotatingFileHandler('log/M2Mraw.log', maxBytes=1000000, backupCount=10)],
    format='%(asctime)s %(name)s %(levelname)s %(message)s',
    level=dictLevel[logLevel]
    )



def on_disconnect(client, userdata, rc):
    global reconnect
    reconnect = True
    logging.error("disconnect to MQTT")

def on_connect(client,userdata,flags,rc):
    global reconnect
    if rc == 0:
        logging.info("Connected to MQTT Broker!")
        client.subscribe(topic, qos=2)
        if(reconnect):
            reconnect = False
            logging.info("MQTT subbacnetraw reconnected.")
    else:
        logging.error("Failed to connect, return code %d\n", rc)

def on_message(client,userdata,message):
    msgraw=str(message.payload.decode("utf-8")).splitlines()[0]

    mutex.acquire()
    f = open(localFileSave,'a+')
    f.write(msgraw+"\r\n")
    f.close()
    mutex.release()

    #logging.info(msgraw)

def JHPParsing(query1):
    try:
        ts = payload["DateTime"]
        data = payload["DATA"]
        gwid = data[0]['V']

        for i in range(1,len(data)):

            ID = data[i]['ID'][3:]
            data1 = data[i]['V']
            raw = f"'{datetime.now()}','{ts}','{gwid}',{ID},{data1}"
            query1 += f"({raw}),"

    except Exception as e:
        logging.error(f"ParsingError: {e}")


    return query1



if(__name__ == "__main__"):
    while True:
        try:
            pwd =os.environ['HOME']
            conn1 = mysql.connector.connect(
                host="127.0.0.1",
                option_files = f'{pwd}/.my.cnf'
            )
            cur1=conn1.cursor()
            break
        except:
            logging.error("DB is not ready, wait for 5 seconds")
            time.sleep(5)


            
    client=mqtt_client.Client(clientId,clean_session=False)
    client.on_connect=on_connect
    client.on_disconnect = on_disconnect
    client.on_message=on_message
    client.username_pw_set(user,passwd)
    client.reconnect_delay_set(min_delay=1, max_delay=5)
    while(1):
        try:
            client.connect(broker, port, 60)
            break
        except Exception as e:
            logging.error(f"connect error {e}")
            time.sleep(10)

    client.loop_start()
    time.sleep(0.1)

    while True:
        if reconnect == False:
            if os.path.isfile(localFileSave):
                with open(localFileSave,"r") as f:
                    lines = f.readlines()
                
                if(len(lines) > 0 and len(lines) < 100):
                    # copy file to avoid writing to the database in the loop, the sub thread still writing down the local file
                    mutex.acquire()
                    shutil.copyfile(localFileSave,tempFile)
                    with open(localFileSave,"w")as f_w:
                        f_w.write("")
                    mutex.release()
                        

                    with open(tempFile,"r") as f:
                        lines = f.readlines()

                    while(len(lines)):
                        tmpLineData = lines[0]
                        jsonFormat = lines[0].split("\n")[0]
                        if(jsonFormat == "065166 control unit disconnect"):
                            logging.error(f"{datetime.now()} {jsonFormat}")
                        else:
                            try:
                                payload = json.loads(jsonFormat)

                                query1 = "insert into rawData.M2M values "
                                query1 = JHPParsing(query1)

                                query1 = query1[:-1]
                                try:
                                    cur1.execute(query1)
                                    conn1.commit()
                                except Exception as e:
                                    logging.error(f"The insert failed data: {query1}  ------   {e}")

                                    if not conn1.is_connected():
                                        while(1):
                                            try:
                                                conn1.reconnect()
                                                
                                                if(conn1.is_connected()):
                                                    cur1.execute(query1)
                                                    conn1.commit()
                                                    break
                                            except Exception as e:
                                                logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                                time.sleep(5)

                            except Exception as e:
                                logging.error(f"Data error: {query1} --- {e}")
                                logging.error(tmpLineData)

                        with open(tempFile,"w")as f_w:
                            for line in lines:
                                if(tmpLineData in line):
                                    continue
                                f_w.write(line)
                        with open(tempFile,"r")as f:
                            lines = f.readlines()
                        
                elif(len(lines) >= 100):
                    # copy file to avoid writing to the database in the loop, the sub thread still writing to the local file
                    mutex.acquire()
                    shutil.copyfile(localFileSave,tempFile)
                    with open(localFileSave,"w")as f_w:
                        f_w.write("")
                    mutex.release()

                    
                    with open(tempFile,"r") as f:
                        lines = f.readlines()


                    query1 = "insert into rawData.M2M values "
                        

                    for i in range(len(lines)):
                        jsonFormat = lines[i].split("\n")[0]

                        
                        if(jsonFormat == "065166 control unit disconnect"):
                            logging.error(jsonFormat)
                        else:
                            try:
                                payload = json.loads(jsonFormat)
                                query1 = JHPParsing()

                            except Exception as e:
                                logging.error(f"Data error: {e}")
                                logging.error(jsonFormat)

                            #================================================500 row saves once================================================
                            #========================================to avoid cursor buffer insufficient========================================
                            if(i != 0 and i % 500 == 0):
                                query1 = query1[:-1]
                                
                                try:
                                    cur1.execute(query1)
                                    conn1.commit()
                                except Exception as e:
                                    logging.error(f"The insert failed data: {query1}  ------   {e}")

                                    if not conn1.is_connected():
                                        while(1):
                                            try:
                                                conn1.reconnect()
                                                
                                                if(conn1.is_connected()):
                                                    cur1.execute(query1)
                                                    conn1.commit()
                                                    break
                                            except Exception as e:
                                                logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                                time.sleep(5)
                                except:
                                    logging.error(f"The insert failed data: {query1}")


                                query1 = "insert into rawData.M2M values "
                            #================================================500 row saves once================================================

                    query1 = query1[:-1]

                    try:
                        cur1.execute(query1)
                        conn1.commit()
                    except Exception as e:
                        logging.error(f"The insert failed data: {query1}  ------   {e}")

                        if not conn1.is_connected():
                            while(1):
                                try:
                                    conn1.reconnect()
                                    
                                    if(conn1.is_connected()):
                                        cur1.execute(query1)
                                        conn1.commit()
                                        break
                                except Exception as e:
                                    logging.error(f"Connected DB error,will reconnect in 5 sec:  {e}")
                                    time.sleep(5)
                    except:
                        logging.error(f"The insert failed data: {query1}")


                    with open(tempFile,"w")as fw:
                        fw.write("")

        time.sleep(1)