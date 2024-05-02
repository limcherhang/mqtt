logtime=$(date "+%Y-%m-%d")
logDir="/home/azureuser/log"

echo "MAILTO=dwyang@evercomm.com.sg
#
# dataETL
*/1 * * * * sleep 10; cd /home/azureuser/dataETL/ && python3 power_dataETL.py > /home/azureuser/log/power_dataETL_$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/temp.sh > /home/azureuser/log/temp.$logtime.log
*/1 * * * * cd /home/azureuser/dataETL/ && python3 twoInOne_3-1_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 twoInOne_3-2_dataETL.py
*/1 * * * * bash /home/azureuser/dataETL/pressure.sh > /home/azureuser/log/pressure.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/flow.sh > /home/azureuser/log/flow.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/flowU.sh > /home/azureuser/log/flowU.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/waterQuality.sh > /home/azureuser/log/waterQuality.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/router.sh > /home/azureuser/log/router.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/threeInOne.sh > /home/azureuser/log/threeInOne.$logtime.log
*/1 * * * * bash /home/azureuser/dataETL/ammonia.sh > /home/azureuser/log/ammonia.$logtime.log
*/1 * * * * cd /home/azureuser/dataETL/ && python3 particle_dataETL.py > /home/azureuser/log/particle_dataETL.py.$logtime.log
*/1 * * * * sleep 20; cd /home/azureuser/dataETL/ && python3 vibration.py > /home/azureuser/log/vibration_dataETL.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataETL/ && python3 wetness_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 environment_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 gpio_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 airQuality_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 co_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 gas_dataETL.py
4,19,34,49 * * * * cd /home/azureuser/dataETL/ && python3 power_API_dataETL.py
2,17,32,47 * * * * cd /home/azureuser/dataETL/ && python3 flow_API_dataETL.py
*/15 * * * * cd /home/azureuser/dataETL/ && python3 temp_API_dataETL.py
5,35 * * * * cd /home/azureuser/dataETL/ && python3 sindcon_API_dataETL.py
3,17,32,47 * * * * cd /home/azureuser/dataETL/ && python3 sigfox_API_dataETL.py
*/1 * * * * cd /home/azureuser/dataETL/ && python3 HDB_dataETL.py
#
#
# dataPlatform
*/1 * * * * sleep 20; python3 /home/azureuser/dataPlatform/power.py > /home/azureuser/log/power.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 temp.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 humidity.py
*/1 * * * * sleep 20; python3 /home/azureuser/dataPlatform/gpio.py > /home/azureuser/log/gpio.py.$logtime.log
*/1 * * * * python3 /home/azureuser/dataPlatform/pressure.py > /home/azureuser/log/pressure.py.$logtime.log
*/1 * * * * python3 /home/azureuser/dataPlatform/flowU.py > /home/azureuser/log/flowU.py.$logtime.log
*/1 * * * * python3 /home/azureuser/dataPlatform/flow.py > /home/azureuser/log/flow.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 quality.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 co2.py
*/1 * * * * python3 /home/azureuser/dataPlatform/ammonia.py > /home/azureuser/log/ammonia.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 flow_Name.py > /home/azureuser/log/flow_Name.py.$logtime.log
*/1 * * * * sleep 20; cd /home/azureuser/dataPlatform/ && python3 particle.py > /home/azureuser/log/particle.py.$logtime.log
*/1 * * * * sleep 20; cd /home/azureuser/dataPlatform/ && python3 vibration.py > /home/azureuser/log/vibration.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 wetness.py > /home/azureuser/log/wetness.py.$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 environment.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 ion.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 ch2o.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 voc.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 co.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 gas.py
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 flow_Chiller.py
5,20,35,50 * * * * cd /home/azureuser/dataPlatform/ && python3 power_API.py > /home/azureuser/log/power_API.py_$logtime.log
3,18,33,48 * * * * cd /home/azureuser/dataPlatform/ && python3 flow_Name_API.py > /home/azureuser/log/flow_Name_API.py_$logtime.log
*/1 * * * * cd /home/azureuser/dataPlatform/ && python3 temp_55.py
2,17,32,47 * * * * cd /home/azureuser/dataPlatform/ && python3 temp_API.py
#
# Site KC
# */5 * * * * cd /home/azureuser/KC/ && python3 kcAPI.py
# */5 * * * * cd /home/azureuser/KC/ && python3 kcRawToETL.py > /home/azureuser/log/kcRawToETL.py_$logtime.log
# */5 * * * * cd /home/azureuser/KC/ && python3 Power1.py > /home/azureuser/log/Power1.py_$logtime.log
# */10 * * * * cd /home/azureuser/KC/ && python3 KcThreeInOne.py
# 1,11,21,31,41,51 * * * * cd /home/azureuser/KC/ && python3 Power14+1.py > /home/azureuser/log/Power14+1.py_$logtime.log
# 1,11,21,31,41,51 * * * * cd /home/azureuser/KC/ && python3 kcETLTodataPlatform_abs.py > /home/azureuser/log/kcETLTodataPlatform_abs.py_$logtime.log
# 1,11,21,31,41,51 * * * * cd /home/azureuser/KC/ && python3 kcPower.py > /home/azureuser/log/kcPower.py_$logtime.log
# 30 5 * * * cd /home/azureuser/KC/report/ && python3 kcReportpower.py
# 50 5 * * * cd /home/azureuser/KC/report/ && python3 Dpower.py
# 0 6 * * * cd /home/azureuser/KC/report/ && python3 kcReportMpower.py
# # car
# */4 * * * * cd /home/azureuser/KC/v3 && python3 v3API.py
# */5 * * * * cd /home/azureuser/KC/v3 && python3 v3RawToETL.py
# 1,6,11,16,21,26,31,36,41,46,51,56 * * * * cd /home/azureuser/KC/v3 && python3 v3car79.py > /home/azureuser/log/v3car79.py_$logtime.log
# 1,6,11,16,21,26,31,36,41,46,51,56 * * * * cd /home/azureuser/KC/v3 && python3 v3ETLTodataPlatform.py > /home/azureuser/log/v3ETLTodataPlatform.py_$logtime.log
# # KC-old
# 1,11,21,31,41,51 * * * * cd /home/azureuser/dataPlatform/ && python3 temp_KC.py
# 1,11,21,31,41,51 * * * * cd /home/azureuser/dataPlatform/ && python3 co2_KC.py
# 1,11,21,31,41,51 * * * * cd /home/azureuser/dataPlatform/ && python3 humidity_KC.py
#
#
# PB
*/1 * * * * bash /home/azureuser/dataPlatform/PB/power.sh > /home/azureuser/log/power.PB.log
*/1 * * * * bash /home/azureuser/dataPlatform/PB/temp.sh > /home/azureuser/log/temp.PB.log
*/1 * * * * bash /home/azureuser/dataPlatform/PB/flowHDR.sh > /home/azureuser/log/flowHDR.PB.log
#
# HDB
*/1 * * * * bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
*/1 * * * * sleep 10 && bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
*/1 * * * * sleep 20 && bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
*/1 * * * * sleep 30 && bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
*/1 * * * * sleep 40 && bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
*/1 * * * * sleep 50 && bash /home/azureuser/dataPlatform/HDB/gpio.sh > /home/azureuser/log/gpio.log
#
# ISS
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash co2.Gw85.sh > /home/azureuser/log/co2.Gw85.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash co2.Gw65.sh > /home/azureuser/log/co2.Gw65.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash temp.Gw85.sh > /home/azureuser/log/temp.Gw85.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash temp.Gw65.sh > /home/azureuser/log/temp.Gw65.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash humidity.Gw85.sh > /home/azureuser/log/humidity.Gw85.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash humidity.Gw65.sh > /home/azureuser/log/humidity.Gw65.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash pressure.Gw85.sh > /home/azureuser/log/pressure.Gw85.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash pressure.Gw65.sh > /home/azureuser/log/pressure.Gw65.sh.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash particle.pm10.Gw65.sh > /home/azureuser/log/particle.pm10.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash particle.pm2_5.Gw65.sh > /home/azureuser/log/particle.pm2_5.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash particle.pm10.Gw85.sh > /home/azureuser/log/particle.pm10.Gw85.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash particle.pm2_5.Gw85.sh > /home/azureuser/log/particle.pm2_5.Gw85.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash hcho.Gw65.sh > /home/azureuser/log/hcho.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash hcho.Gw85.sh > /home/azureuser/log/hcho.Gw85.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash lightLevel.Gw65.sh > /home/azureuser/log/lightLevel.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash lightLevel.Gw85.sh > /home/azureuser/log/lightLevel.Gw85.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash pirTrigger.Gw65.sh > /home/azureuser/log/pirTrigger.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash pirTrigger.Gw85.sh > /home/azureuser/log/pirTrigger.Gw85.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash tvoc.Gw65.sh > /home/azureuser/log/tvoc.Gw65.log
*/10 * * * * cd /home/azureuser/dataPlatform/ISS && bash tvoc.Gw85.sh > /home/azureuser/log/tvoc.Gw85.log
#
# dataPlatform Verdeland
*/15 * * * * cd /home/azureuser/dataPlatform/Verdeland && bash Main.ActiveEnergy.sh > /home/azureuser/log/Main.ActiveEnergy.log
#
#
#reportPlatform
0 2 * * * python3 /home/azureuser/reportPlatform/Dpower.py > /home/azureuser/reportPlatform/log/Dpower.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dtemp.py > /home/azureuser/reportPlatform/log/Dtemp.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dhumidity.py > /home/azureuser/reportPlatform/log/Dhumidity.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dflow.py > /home/azureuser/reportPlatform/log/Dflow.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dco2.py > /home/azureuser/reportPlatform/log/Dco2.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dammonia.py > /home/azureuser/reportPlatform/log/Dammonia.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dparticle.py > /home/azureuser/reportPlatform/log/Dparticle.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dvibration.py > /home/azureuser/reportPlatform/log/Dvibration.py.$logtime.log
0 2 * * * python3 /home/azureuser/reportPlatform/Dpressure.py > /home/azureuser/reportPlatform/log/Dpressure.py.$logtime.log
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dwetness.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Do2.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dnoise.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dilluminance.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dquality.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dion.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dch2o.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dvoc.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dco.py
0 2 * * * cd /home/azureuser/reportPlatform/ && python3 Dgas.py
0 3 * * * cd /home/azureuser/reportPlatform/ && python3 Mpower.py
0 3 * * * cd /home/azureuser/reportPlatform/ && python3 Mgas.py
0 3 * * * cd /home/azureuser/reportPlatform/ && python3 Mflow.py
0 2 * * * cd /home/azureuser/KC/report && python3 v3report.py > /home/azureuser/log/v3report.py.$logtime.log
#
# processETL
*/1 * * * * cd /home/azureuser/processETL/ && python3 processChiller.py > /home/azureuser/log/processChiller.$logtime.log
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller_55.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller_62.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller_69.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller_70.py
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_71.py
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_73.py
*/1 * * * * cd /home/azureuser/processETL/ && bash chiller_74.sh > /home/azureuser/log/chiller_74.log
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_75.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 chiller_76.py
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_77.py
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_78.py
*/1 * * * * sleep 20; cd /home/azureuser/processETL/ && python3 chiller_79.py
*/1 * * * * cd /home/azureuser/processETL/ && python3 boiler.py
#
# PB
*/1 * * * * bash /home/azureuser/processETL/PB/chiller_PB.sh > /home/azureuser/log/chiller_PB.log
#
# ETL old
# processETL
*/1 * * * * cd /home/azureuser/bin/processETL/109PPSSBR && bash chiller.sh 109 > /home/azureuser/log/chiller.109.log
*/1 * * * * cd /home/azureuser/bin/processETL/136QuinRight && bash chiller.sh 136 > /home/azureuser/log/chiller.136.log
*/1 * * * * cd /home/azureuser/bin/processETL/133PRBR && bash chiller.sh 133 > /home/azureuser/log/chiller.133.log
*/1 * * * * cd /home/azureuser/bin/processETL/106PPSSOR && bash chiller.sh 106 > /home/azureuser/log/chiller.106.log
#
#
# PPSS BeachRoad GW 109 Site 4
0 2 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_PPSS && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_PPSS.log
#
# GW 106
30 2 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_PPSSOR && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_PPSSOR.log
#
# GW 112 113 110
0 3 * * * cd /home/azureuser/bin/reportPlatform/chillerReport && bash RunChillerScript.sh > /home/azureuser/log/chillerReport.log
#
# GW 133
0 3 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_PRBeachRoad && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_PRBeachRoad.log
#
# Quin Right Site 21
0 2 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_QuinRight && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_QuinRight.log
#
# YWCA
0 5 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_YWCA && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_YWCA.log
#
# CPF
30 5 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_CPF && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_CPF.log
#
# LHN
45 5 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_LHN && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_LHN.log
#
# Wast Mall
0 6 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_WestMall && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_WestMall.log
#
# Wast Mall
0 6 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_ChinatownPoint && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_ChinatownPoint.log
#
# Stahl
5 6 * * * cd /home/azureuser/bin/reportPlatform/chillerReport_Stahl && bash RunChillerScript.sh > /home/azureuser/log/chillerReport_Stahl.log
5 6 * * * cd /home/azureuser/bin/reportPlatform/boilerReport_Stahl && bash RunChillerScript.sh > /home/azureuser/log/boilerReport_Stahl.log
#
# replace & clean data(rawData)
5 0 * * * cd /home/azureuser/bin/ && python3 replaceAndCleanFor41_rawData.py
#
# replace & clean data(iotmgmt)
0 1 * * * bash /home/azureuser/bin/replaceAndClean_iotmgmt.sh local 10000 0 > /home/azureuser/log/replaceAndClean_iotmgmt.$logtime.log
#
# replace & clean data(dataETL)
0 5 * * * bash /home/azureuser/bin/dbReplaceIotDataETL.sh.sh > /home/azureuser/log/dbReplaceIotDataETL.$logtime.log
0 6 * * * bash /home/azureuser/bin/dbCleanDataETL.sh 1 > /home/azureuser/log/dbCleanDataETL.$logtime.log
#
# replace & clean data(dataPlatform)
0 3 * * * python3 /home/azureuser/bin/replace.py > /home/azureuser/log/replace.$logtime.log
0 4 * * * python3 /home/azureuser/bin/delete.py 1 > /home/azureuser/log/delete.$logtime.log
#
# update crontab
0 0 * * * bash /home/azureuser/crontab.process.sh
#" > ./process.crontab

cat ./process.crontab |crontab
rm ./process.crontab
