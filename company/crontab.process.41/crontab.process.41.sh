echo "MAILTO=dwyang@evercomm.com.sg
# [RawData]
#
@reboot cd /home/ecoprog/DATA/MQTT_SG && python3 MQTT_SubZigBeeRaw_SG.py
@reboot cd /home/ecoprog/DATA/MQTT_SG && python3 MQTT_SubBACnetRaw_SG.py
@reboot cd /home/ecoprog/DATA/MQTT_SG && python3 MQTT_SubModbusRaw_SG.py
@reboot cd /home/ecoprog/DATA/MQTT_SG && python3 MQTT_SubM2MRaw_SG.py
@reboot cd /home/ecoprog/DATA/MQTT_TW && python3 MQTT_SubZigBeeRaw_TW.py
@reboot cd /home/ecoprog/DATA/MQTT_TW && python3 MQTT_SubBACnetRaw_TW.py
@reboot cd /home/ecoprog/DATA/MQTT_TW && python3 MQTT_SubModbusRaw_TW.py
@reboot cd /home/ecoprog/Hank_DATA/MQTT_TC && python3 MQSubM2M_JHP_TC.py
@reboot cd /home/ecoprog/DATA/MQTT_PPSS && python3 MQTT_SubPPSSRaw.py
#
#
#
# [iotmgmt]
# ***iotmgmt from 1.41 to 6.41***
*/1 * * * * sleep 40 && cd /home/ecoprog/ETL/iotmgmt/ && python3 iotmgmtFrom1.41To6.41.py
*/1 * * * * sleep 20 && cd /home/ecoprog/ETL/iotmgmt/ && python3 iotmgmtFrom1.41To6.41.py
*/1 * * * * cd /home/ecoprog/ETL/iotmgmt/ && python3 iotmgmtFrom1.41To6.41.py
#
# Raw Data to iotmgmt
@reboot cd /home/ecoprog/ETL/iotmgmt && python3 ZigBee_raw2iotmgmt.py
#
# GW164
*/1 * * * * cd /home/ecoprog/ETL/iotmgmt/GW164_pm/ && python3 pm_164.py
#
# 
# ***API***
*/15 * * * * cd /home/ecoprog/DATA/API/ && python3 rawdata_API.py
3,18,33,48 * * * * cd /home/ecoprog/DATA/API/ && python3 power_API.py
1,16,31,46 * * * * cd /home/ecoprog/DATA/API/ && python3 flow_API.py
*/30 * * * * cd /home/ecoprog/DATA/API/ && python3 sindcon_API.py 3
*/15 * * * * cd /home/ecoprog/DATA/API/ && python3 sigfox_API.py
#
#
# [ETL]
*/1 * * * * cd /home/ecoprog/ETL/iotmgmt/BACnet && python3 bacnet.py
*/1 * * * * cd /home/ecoprog/ETL/iotmgmt/ && python3 particle_rawData.py > /home/ecoprog/ETL/iotmgmt/log/particle_rawData.log
*/1 * * * * cd /home/ecoprog/ETL/iotmgmt/ && python3 vibration_rawData.py > /home/ecoprog/ETL/iotmgmt/log/vibration_rawData.log
#
# ***GW 103***
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/liquidLevel.sh > /home/ecoprog/ETL/iotmgmt/bin/log/liquidLevel.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/fineTekWaterFlow.sh > /home/ecoprog/ETL/iotmgmt/bin/log/fineTekWaterFlow.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/fineTekWaterFlowTotal.sh > /home/ecoprog/ETL/iotmgmt/bin/log/fineTekWaterFlowTotal.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/pressure.sh > /home/ecoprog/ETL/iotmgmt/bin/log/pressure.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/EMS103WaterFlowTotal.sh > /home/ecoprog/ETL/iotmgmt/bin/log/EMS103WaterFlowTotal.log
#
# ***GW 103 117***
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/AH5Temp.sh > /home/ecoprog/ETL/iotmgmt/bin/log/AH5Temp.log
#
# ***GW 133***
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/dTemperature.sh > /home/ecoprog/ETL/iotmgmt/bin/log/dTemperature.log
#
# ***SWTS***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw51.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swts.log
*/1 * * * * sleep 5 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swts52.log
*/1 * * * * sleep 20 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swts52.log
*/1 * * * * sleep 35 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swts52.log
*/1 * * * * sleep 50 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swts52.log
*/1 * * * * sleep 5 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52Vpp.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swtsGw52Vpp.log
*/1 * * * * sleep 20 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52Vpp.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swtsGw52Vpp.log
*/1 * * * * sleep 35 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52Vpp.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swtsGw52Vpp.log
*/1 * * * * sleep 50 && bash /home/ecoprog/ETL/iotmgmt/SWTS/swtsGw52Vpp.sh > /home/ecoprog/ETL/iotmgmt/SWTS/log/swtsGw52Vpp.log
#
# ***GW137***
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/MultiLoopPower/A25PowerMeter.sh > /home/ecoprog/ETL/iotmgmt/MultiLoopPower/log/A25PowerMeter.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/MultiLoopPower/A25PowerMeter1.sh > /home/ecoprog/ETL/iotmgmt/MultiLoopPower/log/A25PowerMeter1.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/MultiLoopPower/A25PowerMeter2.sh > /home/ecoprog/ETL/iotmgmt/MultiLoopPower/log/A25PowerMeter2.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/MultiLoopPower/A25PowerMeter3.sh > /home/ecoprog/ETL/iotmgmt/MultiLoopPower/log/A25PowerMeter3.log
#*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/MultiLoopPower/A25PowerMeter4.sh > /home/ecoprog/ETL/iotmgmt/MultiLoopPower/log/A25PowerMeter4.log
#
#
*/1 * * * * bash /home/ecoprog//ETL/iotmgmt/DixellTemp/DixellTempListen.sh > /home/ecoprog//ETL/iotmgmt/DixellTemp/log/DixellTempListen.log
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/DixellTemp/DixellTempListenGw135.sh > /home/ecoprog//ETL/iotmgmt/DixellTemp/log/DixellTempListenGw135.log
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/DixellTemp/DixellTempListenGw135_2.sh > /home/ecoprog//ETL/iotmgmt/DixellTemp/log/DixellTempListenGw135_2.log
#
# ***Gw200 201 Sanden ***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/NorikaFlowMeter.Sanden.ZB.sh > /home/ecoprog/ETL/iotmgmt/bin/log/NorikaFlowMeter.Sanden.ZB.log
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/NorikaFlowMeter.Sanden.M.sh > /home/ecoprog/ETL/iotmgmt/bin/log/NorikaFlowMeter.Sanden.M.log
#
# ***Gw 211***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/CHDH_ThreeInOne.sh > /home/ecoprog/ETL/iotmgmt/bin/log/CHDH_ThreeInOne.log
#
# ***Gw203***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/CPM20PowerMeterGw203.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/CPM20PowerMeterGw203.log
#
# ***Gw229***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/UMG96S_PowerMeterGw229.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/UMG96S_PowerMeterGw229.log
#
# ***Gw209 210***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/TTSIM1A.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/TTSIM1A.log
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/bin/TTSIM2.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/TTSIM2.log
#
# ***GW 300***
*/1 * * * * bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
*/1 * * * * sleep 10 && bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
*/1 * * * * sleep 20 && bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
*/1 * * * * sleep 30 && bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
*/1 * * * * sleep 40 && bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
*/1 * * * * sleep 50 && bash /home/ecoprog/ETL/iotmgmt/HDB/gpio.sh >  /home/ecoprog/ETL/iotmgmt/bin/log/gpio.log
#" > ./process.crontab

cat ./process.crontab |crontab
rm ./process.crontab
