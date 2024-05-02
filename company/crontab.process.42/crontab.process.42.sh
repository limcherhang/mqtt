logtime=$(date "+%Y-%m-%d")
logDir="/home/ecoprog/log"

echo "MAILTO=daweiyang7@gmail.com
#
# dataETL
*/1 * * * * sleep 10; cd /home/ecoprog/dataETL/ && python3 power_dataETL.py > /home/ecoprog/log/power_dataETL_$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/temp.sh > /home/ecoprog/log/temp.$logtime.log
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 twoInOne_3-1_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 twoInOne_3-2_dataETL.py
*/1 * * * * bash /home/ecoprog/dataETL/pressure.sh > /home/ecoprog/log/pressure.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/flow.sh > /home/ecoprog/log/flow.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/flowU.sh > /home/ecoprog/log/flowU.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/waterQuality.sh > /home/ecoprog/log/waterQuality.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/router.sh > /home/ecoprog/log/router.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/threeInOne.sh > /home/ecoprog/log/threeInOne.$logtime.log
*/1 * * * * bash /home/ecoprog/dataETL/ammonia.sh > /home/ecoprog/log/ammonia.$logtime.log
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 particle_dataETL.py > /home/ecoprog/log/particle_dataETL.py.$logtime.log
*/1 * * * * sleep 20; cd /home/ecoprog/dataETL/ && python3 vibration.py > /home/ecoprog/log/vibration_dataETL.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 wetness_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 environment_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 gpio_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 airQuality_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 co_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 gas_dataETL.py
4,19,34,49 * * * * cd /home/ecoprog/dataETL/ && python3 power_API_dataETL.py
2,17,32,47 * * * * cd /home/ecoprog/dataETL/ && python3 flow_API_dataETL.py
*/15 * * * * cd /home/ecoprog/dataETL/ && python3 temp_API_dataETL.py
5,35 * * * * cd /home/ecoprog/dataETL/ && python3 sindcon_API_dataETL.py
3,17,32,47 * * * * cd /home/ecoprog/dataETL/ && python3 sigfox_API_dataETL.py
*/1 * * * * cd /home/ecoprog/dataETL/ && python3 HDB_dataETL.py
#
# KC
*/5 * * * * cd /home/ecoprog/KC/ && python3 kcAPI.py
*/5 * * * * cd /home/ecoprog/KC/ && python3 kcRawToETL.py
*/5 * * * * cd /home/ecoprog/KC/ && python3 Power1.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/KC/ && python3 Power14+1.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/KC/ && python3 kcETLTodataPlatform_abs.py
#1,11,21,31,41,51 * * * * cd /home/ecoprog/KC/ && python3 kcETLTodataPlatform.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/KC/ && python3 kcPower.py
30 3 * * * cd /home/ecoprog/KC/report/ && python3 kcReportpower.py
50 3 * * * cd /home/ecoprog/KC/report/ && python3 Dpower.py
0 4 * * * cd /home/ecoprog/KC/report/ && python3 kcReportMpower.py
# car
*/4 * * * * cd /home/ecoprog/KC/v3 && python3 v3API.py
*/5 * * * * cd /home/ecoprog/KC/v3 && python3 v3RawToETL.py
1,6,11,16,21,26,31,36,41,46,51,56 * * * * cd /home/ecoprog/KC/v3 && python3 v3car79.py
1,6,11,16,21,26,31,36,41,46,51,56 * * * * cd /home/ecoprog/KC/v3 && python3 v3ETLTodataPlatform.py
# KC-old
#*/5 * * * * cd /home/ecoprog/dataETL/KC/ && python3 api_test_kc_json.py
#*/10 * * * * cd /home/ecoprog/dataETL/KC/ && python3 rawToETL_api.py
*/10 * * * * cd /home/ecoprog/dataETL/KC/ && bash ThreeInOne.sh > /home/ecoprog/log/ThreeInOne.KC.log
#1,11,21,31,41,51 * * * * cd /home/ecoprog/dataETL/KC/ && python3 kc_count.py
#1,11,21,31,41,51 * * * * cd /home/ecoprog/dataETL/KC/ && python3 power1.py
#2,12,22,32,42,52 * * * * cd /home/ecoprog/dataETL/KC/ && python3 power14.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/dataPlatform/ && python3 temp_KC.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/dataPlatform/ && python3 co2_KC.py
1,11,21,31,41,51 * * * * cd /home/ecoprog/dataPlatform/ && python3 humidity_KC.py
#
# dataPlatform
*/1 * * * * sleep 20; python3 /home/ecoprog/dataPlatform/power.py > /home/ecoprog/log/power.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 temp.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 humidity.py
*/1 * * * * sleep 20; python3 /home/ecoprog/dataPlatform/gpio.py > /home/ecoprog/log/gpio.py.$logtime.log
*/1 * * * * python3 /home/ecoprog/dataPlatform/pressure.py > /home/ecoprog/log/pressure.py.$logtime.log
*/1 * * * * python3 /home/ecoprog/dataPlatform/flowU.py > /home/ecoprog/log/flowU.py.$logtime.log
*/1 * * * * python3 /home/ecoprog/dataPlatform/flow.py > /home/ecoprog/log/flow.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 quality.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 co2.py
*/1 * * * * python3 /home/ecoprog/dataPlatform/ammonia.py > /home/ecoprog/log/ammonia.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 flow_Name.py > /home/ecoprog/log/flow_Name.py.$logtime.log
*/1 * * * * sleep 20; cd /home/ecoprog/dataPlatform/ && python3 particle.py > /home/ecoprog/log/particle.py.$logtime.log
*/1 * * * * sleep 20; cd /home/ecoprog/dataPlatform/ && python3 vibration.py > /home/ecoprog/log/vibration.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 wetness.py > /home/ecoprog/log/wetness.py.$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 environment.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 ion.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 ch2o.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 voc.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 co.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 gas.py
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 flow_Chiller.py
5,20,35,50 * * * * cd /home/ecoprog/dataPlatform/ && python3 power_API.py >> /home/ecoprog/log/power_API.py_$logtime.log
3,18,33,48 * * * * cd /home/ecoprog/dataPlatform/ && python3 flow_Name_API.py >> /home/ecoprog/log/flow_Name_API.py_$logtime.log
*/1 * * * * cd /home/ecoprog/dataPlatform/ && python3 temp_55.py
2,17,32,47 * * * * cd /home/ecoprog/dataPlatform/ && python3 temp_API.py
#
# 
#
# PB
*/1 * * * * bash /home/ecoprog/dataPlatform/PB/power.sh > /home/ecoprog/log/power.PB.log
*/1 * * * * bash /home/ecoprog/dataPlatform/PB/temp.sh > /home/ecoprog/log/temp.PB.log
*/1 * * * * bash /home/ecoprog/dataPlatform/PB/flowHDR.sh > /home/ecoprog/log/flowHDR.PB.log
# HDB
*/1 * * * * bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
*/1 * * * * sleep 10 && bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
*/1 * * * * sleep 20 && bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
*/1 * * * * sleep 30 && bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
*/1 * * * * sleep 40 && bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
*/1 * * * * sleep 50 && bash /home/ecoprog/dataPlatform/HDB/gpio.sh > /home/ecoprog/log/gpio.log
# ISS
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash co2.Gw85.sh > /home/ecoprog/log/co2.Gw85.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash co2.Gw65.sh > /home/ecoprog/log/co2.Gw65.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash temp.Gw85.sh > /home/ecoprog/log/temp.Gw85.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash temp.Gw65.sh > /home/ecoprog/log/temp.Gw65.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash humidity.Gw85.sh > /home/ecoprog/log/humidity.Gw85.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash humidity.Gw65.sh > /home/ecoprog/log/humidity.Gw65.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash pressure.Gw85.sh > /home/ecoprog/log/pressure.Gw85.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash pressure.Gw65.sh > /home/ecoprog/log/pressure.Gw65.sh.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash particle.pm10.Gw65.sh > /home/ecoprog/log/particle.pm10.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash particle.pm2_5.Gw65.sh > /home/ecoprog/log/particle.pm2_5.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash particle.pm10.Gw85.sh > /home/ecoprog/log/particle.pm10.Gw85.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash particle.pm2_5.Gw85.sh > /home/ecoprog/log/particle.pm2_5.Gw85.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash hcho.Gw65.sh > /home/ecoprog/log/hcho.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash hcho.Gw85.sh > /home/ecoprog/log/hcho.Gw85.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash lightLevel.Gw65.sh > /home/ecoprog/log/lightLevel.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash lightLevel.Gw85.sh > /home/ecoprog/log/lightLevel.Gw85.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash pirTrigger.Gw65.sh > /home/ecoprog/log/pirTrigger.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash pirTrigger.Gw85.sh > /home/ecoprog/log/pirTrigger.Gw85.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash tvoc.Gw65.sh > /home/ecoprog/log/tvoc.Gw65.log
*/10 * * * * cd /home/ecoprog/dataPlatform/ISS && bash tvoc.Gw85.sh > /home/ecoprog/log/tvoc.Gw85.log
#
# dataPlatform Verdeland
*/15 * * * * cd /home/ecoprog/dataPlatform/Verdeland && bash Main.ActiveEnergy.sh > /home/ecoprog/log/Main.ActiveEnergy.log
#
#reportPlatform
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dpower.py > /home/ecoprog/log/Dpower.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dtemp.py > /home/ecoprog/log/Dtemp.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dhumidity.py > /home/ecoprog/log/Dhumidity.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dflow.py > /home/ecoprog/log/Dflow.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dco2.py > /home/ecoprog/log/Dco2.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dammonia.py > /home/ecoprog/log/Dammonia.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dparticle.py > /home/ecoprog/log/Dparticle.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dvibration.py > /home/ecoprog/log/Dvibration.py.$logtime.log
0 2 * * * python3 /home/ecoprog/reportPlatform2021/Dpressure.py > /home/ecoprog/log/Dpressure.py.$logtime.log
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dwetness.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Do2.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dnoise.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dilluminance.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dquality.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dion.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dch2o.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dvoc.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dco.py
0 2 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Dgas.py
0 3 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Mpower.py
0 3 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Mgas.py
0 3 * * * cd /home/ecoprog/reportPlatform2021/ && python3 Mflow.py
0 2 * * * cd /home/ecoprog/KC/report && python3 v3report.py
#
# replace & clean data(dataETL)
0 5 * * * bash /home/ecoprog/bin/dbReplaceIotDataETL.sh > /home/ecoprog/log/dbReplaceIotDataETL.$logtime.log
0 6 * * * bash /home/ecoprog/bin/dbCleanDataETL.sh 1 > /home/ecoprog/log/dbCleanDataETL.$logtime.log
#
0 5 * * * bash /home/ecoprog/bin/dbReplaceIotDataETL.sh > /home/ecoprog/log/dbReplaceIotDataETL.$logtime.log
0 6 * * * bash /home/ecoprog/bin/dbCleanDataETL.sh 1 > /home/ecoprog/log/dbCleanDataETL.$logtime.log
#
# replace & clean data(dataPlatform)
0 3 * * * python3 /home/ecoprog/bin/replace.py > /home/ecoprog/log/replace.$logtime.log
0 4 * * * python3 /home/ecoprog/bin/delete.py 1 > /home/ecoprog/log/delete.$logtime.log
#
# processETL
*/1 * * * * cd /home/ecoprog/processETL/ && python3 processChiller.py > /home/ecoprog/log/processChiller.$logtime.log
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller_55.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller_62.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller_69.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller_70.py
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_71.py
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_73.py
*/1 * * * * cd /home/ecoprog/processETL/ && bash chiller_74.sh > /home/ecoprog/log/chiller_74.log
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_75.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 chiller_76.py
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_77.py
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_78.py
*/1 * * * * sleep 20; cd /home/ecoprog/processETL/ && python3 chiller_79.py
*/1 * * * * cd /home/ecoprog/processETL/ && python3 boiler.py
#
# PB
*/1 * * * * bash /home/ecoprog/processETL/PB/chiller_PB.sh > /home/ecoprog/log/chiller_PB.log
#
# update crontab
0 0 * * * bash /home/ecoprog/crontab.process.sh
#" > ./process.crontab

cat ./process.crontab |crontab
rm ./process.crontab
