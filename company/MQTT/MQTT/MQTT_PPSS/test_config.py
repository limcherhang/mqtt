import configparser
import sys

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
        
    subTopic_list = [(subTopic_rawdata_pm, 2), (subTopic_rawdata_flow, 2), (subTopic_rawdata_temp, 2)]

except Exception as ex:
    sys.exit(f"[Config Setting ERROR]: {str(ex)}")

print(MQTTclientId)
print(MQTTips)