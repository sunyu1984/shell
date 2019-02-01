#!/bin/bash

cpu=`ipmitool -I open sensor list | grep -E "CPU Temp"`
fan1=`ipmitool -I open sensor list | grep -E "FAN1"`
fan2=`ipmitool -I open sensor list | grep -E "FAN2"`
fan3=`ipmitool -I open sensor list | grep -E "FAN3"`

echo "======================================="
echo "      Sensor     |  Reading  | Status  "
echo "======================================="

cpuRead=`echo $cpu | awk -F "|" '{print $2}'`
cpuSts=`echo $cpu | awk -F "|" '{print $4}'`

fan1Read=`echo $fan1 | awk -F "|" '{print $2}'`
fan1Sts=`echo $fan1 | awk -F "|" '{print $4}'`

fan2Read=`echo $fan2 | awk -F "|" '{print $2}'`
fan2Sts=`echo $fan2 | awk -F "|" '{print $4}'`

fan3Read=`echo $fan3 | awk -F "|" '{print $2}'`
fan3Sts=`echo $fan3 | awk -F "|" '{print $4}'`

printf "%-16s | %-9s | %-13s\n" "CPU Temperature" $cpuRead $cpuSts
printf "%-16s | %-9s | %-13s\n" "FAN1" $fan1Read $fan1Sts
printf "%-16s | %-9s | %-13s\n" "FAN2" $fan2Read $fan2Sts
printf "%-16s | %-9s | %-13s\n" "FAN3" $fan3Read $fan3Sts

for i in `lsblk | grep "disk" | awk '{print $1"|"$4}'`
do
    diskName='/dev/'`echo $i | awk -F "|" '{print $1}'`
    diskSpace=`echo $i | awk -F "|" '{print $2}'`
    diskHours=`smartctl -A $diskName | grep "Power_On_Hours" | awk '{print $10}'`
    printf "%-16s | %-9s | %-13s\n" $diskName $diskSpace $diskHours
done

echo "======================================="
