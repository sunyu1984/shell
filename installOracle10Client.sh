#!/bin/bash

# 
oraUser=`cat /etc/passwd | cut -f1 -d':' | grep -w "oracle" -c`
oraHomeDir=`cat /etc/passwd | grep oracle | awk -F ':' '{print $6}'`

wget -nH -P /tmp -r ftp://dvget:abc123@10.161.32.100/oracleClient10205/ >/dev/null 2>&1
wget -nH -P /tmp -r ftp://dvget:abc123@10.161.32.100/rlwrap/ >/dev/null 2>&1

if [ $oraUser -le 0 ]; then
    groupadd -g 500 dba
    useradd -u 500 -d /home/oracle -g "dba" oracle
    echo "oracle,123" | passwd --stdin oracle > /dev/null
fi

if [ "$oraHomeDir" =  "" ]; then
    oraHomeDir="/home/oracle"
fi

cd /tmp/oracleClient10205
rpm -ivh oracle* >/dev/null

cd /tmp/rlwrap
rpm -ivh perl-Data-Dumper-2.145-3.el7.x86_64.rpm
rpm -ivh rlwrap-0.42-1.el7.x86_64.rpm

touch /usr/lib/oracle/10.2.0.5/client64/tnsnames.ora
chown oracle:dba /usr/lib/oracle/10.2.0.5/client64/tnsnames.ora

echo "export LD_LIBRARY_PATH=/usr/lib/oracle/10.2.0.5/client64/lib" >> $oraHomeDir/.bash_profile
echo "export TNS_ADMIN=/usr/lib/oracle/10.2.0.5/client64" >> $oraHomeDir/.bash_profile
echo "export ORACLE_HOME=/home/oracle" >> $oraHomeDir/.bash_profile
echo "alias sqlplus='rlwrap /usr/lib/oracle/10.2.0.5/client64/bin/sqlplus'" >> $oraHomeDir/.bash_profile