#!/bin/bash

clear

ftpAddr="172.16.14.160"
ftpUser=""
ftpPasswd=""
wlJDKPath=""
# 错误退出
function errExit()
{
    echo -e "\n$1" 1>&2
    exit 99
}

function delayed()
{
    IFS=''
    echo -e "Must 'source installWeblogic12c.sh' execute script, if not, press Ctrl + C!"
    for (( i=30; i>0; i--)); do
        printf "\rStarting in $i seconds..."
        read -s -N 1 -t 1 key

        if [ "$key" == $'\x0a' ] ;then
            break
        fi
    done
}

# 检查是否为root用户
function checkRootUser ()
{
    if [ `id -u` -eq 0 ];then  
        return 66
    fi
}

# 因为无外网，不能安装lsb_release来检测系统，所以只能通过检查指定文件判断系统是否为Centos7
function checkOSByFile()
{
    local release=""
    local version=""
    local main_ver=""
    # release
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
    # version
    if [[ -s /etc/redhat-release ]]; then
        version=`grep -oE  "[0-9.]+" /etc/redhat-release`
    else
        version=`grep -oE  "[0-9.]+" /etc/issue`
    fi
    
    main_ver=${version%%.*}

    if [ "$main_ver" != "7" ] || [ "$release" != "centos" ]; then
        return 99
    fi
    return 66
}

# 关闭SELinux
function closeSELinux ()
{
    local checkSELinux=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$checkSELinux" == "SELINUX=enforcing" ]; then
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# 创建Oracle Inventory
function createOracleInvertory ()
{
    
    echo -e "   Setting the inventory to $1\n"
    echo -e "   Setting the group name to $2\n"
    INVDIR=/etc
    PLATFORMID=`uname -a | awk '{{print $1}}'`
    
    
    if [ "$PLATFORMID" = "Linux" ];then
        INVDIR=/etc
    fi
        
    if [ "$PLATFORMID" = "SunOS" ];then
        INVDIR=/var/opt/oracle
    fi
    
    if [ "$PLATFORMID" = "HP-UX" ];then
        INVDIR=/var/opt/oracle
    fi
    
    if [ "$PLATFORMID" = "AIX" ];then
        INVDIR=/etc
    fi
        
    echo -e "   Creating inventory pointer file in $INVDIR directory\n"
    if [ -d $INVDIR ]; then
        chmod 755 $INVDIR;
    else
        mkdir -p $INVDIR;
    fi
    
    INVPTR=${INVDIR}/oraInst.loc
    INVLOC=$1
    GRP=$2
    PTRDIR="`dirname $INVPTR`";
    
    # Create the software inventory location pointer file
    if [ ! -d "$PTRDIR" ]; then
        mkdir -p $PTRDIR;
    fi
    echo -e "   Creating the Oracle inventory pointer file ($INVPTR)\n";
    echo    inventory_loc=$INVLOC > $INVPTR
    echo    inst_group=$GRP >> $INVPTR
    chmod 644 $INVPTR
    # Create the inventory directory if it doesn't exist
    if [ ! -d "$INVLOC" ];then
        echo -e "   Creating the Oracle inventory directory ($INVLOC)\n";
    mkdir -p $INVLOC;
    fi
    
    echo -e "   Changing permissions of $1 to 770\n";
    chmod -R g+rw,o-rwx $1;
    if [ $? != 0 ]; then
        echo -e "   OUI-35086:WARNING: chmod of $1 to 770 failed!\n";
    fi
    echo -e "   Changing groupname of $1 to $2\n";
    chgrp -R $2 $1;
    if [ $? != 0 ]; then
        echo -e "   OUI-10057:WARNING: chgrp of $1 to $2 failed!\n";
    fi
    echo -e "   All things is complete!!!\n"
}

# 查找或下载安装文件和jdk
function findOrDownLoadFile ()
{
    jdkName=$1
    weblogicName=$2
      
    # 通过FTP下载JDK
    if [ "$jdkName" != "not" ];then
        jdkTarFileSts=`find / -name $jdkName | wc -l`
        if [ $jdkTarFileSts == 0 ];then
            echo -e "   Not found JDK file, Now download from ftp://10.161.32.100\n"
            if [ -z "$ftpUser" ]; then
                read -p "   Please input ftp account: "
                ftpUser=$REPLY
                read -p "   Please input ftp account's password: "
                ftpPasswd=$REPLY
            fi
            echo ""
            echo -e "   Begin Download JDK................"
            wget -t 3 -T 5 ftp://$ftpUser:$ftpPasswd@$ftpAddr/$jdkName >/dev/null 2>&1 || errExit "   Download JDK fail,Exit!!!"
            echo -e "   Download finished!................\n"
            rm -rf /usr/local/jdk1.7.0_80
            tar zxvf jdk-7u80-linux-x64.tar.gz >/dev/null 2>&1 || errExit "   Unzip Fail,Exit!!!"
            mv jdk1.7.0_80 /usr/local/jdk1.7.0_80
            rm -rf jdk-7u80-linux-x64.tar.gz
        # 本地有JDK文件        
        else
            jdkTarFileLocate=`find / -name $jdkName`
            echo -e "   found JDK file, Pass!!!\n"
            # 复制到/opt/bea/oracle目录
            cp $jdkTarFileLocate /opt/bea/oracle >/dev/null 2>&1
            rm -rf /usr/local/jdk1.7.0_80
            tar zxvf /opt/bea/oracle/jdk-7u80-linux-x64.tar.gz >/dev/null 2>&1 || errExit "   Unzip Fail,Exit!!!"
            mv /opt/bea/oracle/jdk1.7.0_80 /usr/local/jdk1.7.0_80
            rm -rf /opt/bea/oracle/jdk-7u80-linux-x64.tar.gz
        fi
    fi
    
    if [ "$weblogicName" != "not" ];then
        wblFileSts=`find / -name $weblogicName | wc -l`
        # 通过FTP下载weblogic安装文件
        if [ $wblFileSts == 0 ];then
                echo -e "   Not found WLC file, Now download from ftp://10.161.32.100\n"
                if [ -z "$ftpUser" ]; then
                    read -p "   Please input ftp account: "
                    ftpUser=$REPLY
                    read -p "   Please input ftp account's password: "
                    ftpPasswd=$REPLY
                fi
                echo ""
                echo -e "   Begin Download Weblogic12c........"
                wget -t 3 -T 5 ftp://$ftpUser:$ftpPasswd@$ftpAddr/$weblogicName >/dev/null 2>&1 || errExit "   Download Weblogic12c fail,Exit!!!"
                echo -e "   Download finished!..............\n"
                rm -rf /opt/bea/oracle/fmw_12.1.3.0.0_wls.jar
                mv fmw_12.1.3.0.0_wls.jar /opt/bea/oracle
                chown weblogic:oracle /opt/bea/oracle/fmw_12.1.3.0.0_wls.jar
        # 本地有weblogic安装文件      
        else
            wblFileLocate=`find / -name $weblogicName`
            echo -e "   found Weblogic12c file, Pass!!!\n"
            # 复制到/tmp/installmysql目录
            cp $wblFileLocate /opt/bea/oracle >/dev/null 2>&1
            chown weblogic:oracle /opt/bea/oracle/fmw_12.1.3.0.0_wls.jar
        fi
    fi
}

# 为指定用户设置JDK的环境变量
function setJdk ()
{
    userName=$1
    jdkHome=$2

    # 取用户主目录
    userPath=`cat /etc/passwd | grep ^$userName | awk -F ":" '{print $6}'`
    if [ -z "$userPath" ]; then
        echo -e "   Not found user,Can't set JDK,Exit!!!"
        exit 99
    else
        sed -i 's/export JAVA_HOME=/#export JAVA_HOME=/g' $userPath/.bash_profile
        sed -i 's/export JRE_HOME=/#export JRE_HOME=/g' $userPath/.bash_profile
        sed -i 's/export CLASSPATH=/#export CLASSPATH=/g' $userPath/.bash_profile
        sed -i 's/export PATH=/#export PATH=/g' $userPath/.bash_profile
        # 解决JDK的Bug(JDK从/dev/random读取‘randomness’经常耗费10分钟或者更长的时间)
        sed -i 's/securerandom.source=file:\/dev\/urandom/securerandom.source=file:\/dev\/.\/urandom/g' $jdkHome/jre/lib/security/java.security

        echo "" >> $userPath/.bash_profile
        echo "export JAVA_HOME=$jdkHome" >> $userPath/.bash_profile
        echo "export JRE_HOME=$jdkHome/jre" >> $userPath/.bash_profile
        echo "export CLASSPATH=.:\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CLASSPATH" >> $userPath/.bash_profile
        echo "export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH" >> $userPath/.bash_profile
        echo -e "   Set JDK for user $userName OK!!!\n"
    fi
    wlJDKPath=$jdkHome
}

# 检查密码是否符合要求
function checkPasswd ()
{
    chkPwd=$1
    if ! [[ ${#chkPwd} -ge 8 && "$chkPwd" == *[0-9]* ]];then
        echo -e "   The password must be at least 8 alphanumeric characters with at least one number or special character\n"
        return 99
    else
        echo ""
        echo -e "   OK,you set domain password is '$chkPwd'\n"
        return 66
    fi
}

# 检查domain名称合法性
function checkDomainName ()
{
    dName=$1
    regCheck=`echo $dName | grep "^[^a-zA-Z_]" | wc -l`
    if [ $regCheck -ne 0 ];then
        echo -e "   domain name must include alphanumeric, hyphens (-) or underscore characters (_) and must not start with a number.\n"
        return 99
    else
        echo ""
        echo -e "   OK,you set domain name is '$dName'\n"
        return 66
    fi
}

# -------------------------------
# Begin Install Weblogic 12 c
# -------------------------------

echo ""
echo "##########################################################################"
echo "# The following operations will be performed:                            #"
echo "#  1. Close SELinux                                                      #"
echo "#  2. Check(Install) JDK                                                 #"
echo "#  3. Useradd weblogic,Goupadd oracle                                    #"
echo "#  4. Create OracleInvertory                                             #"
echo "#  5. Install Weblogic 12c                                               #"
echo "##########################################################################"
echo ""

# check user
checkRootUser
userSts=`echo $?`
if [ $userSts != "66" ]; then
    echo -e "The current user is not root, please switch to the root user.\n"
    exit 99
fi

echo -e "-> Close SELinux..........................................................\n"
closeSELinux
echo -e "   Close OK!\n"

# 1. 创建用户和组
echo -e "-> Create User And Group..................................................\n"
groupadd oracle
mkdir -p /opt/bea
useradd weblogic -g oracle -d /opt/bea/oracle -s /bin/bash
chown weblogic:oracle /opt/bea
echo "abc123" | passwd --stdin weblogic > /dev/null 2>&1
echo -e "   Create user:weblogic,group:oracle OK!\n"
echo -e "   User weblogic password is : abc123\n"

# 2. 创建Oracle inventory
echo -e "-> Creat Oracle Inventory.................................................\n"
createOracleInvertory /opt/bea/oracle/oraInventory oracle
echo -e "   Create user:weblogic,group:oracle OK!\n"

# 3. 创建安装目录（ORACLE_HOME）
echo -e "-> Creat Installation Folders.............................................\n"
mkdir -p /opt/bea/oracle/Middleware/12c && chown -R weblogic:oracle /opt/bea/oracle/Middleware
mkdir -p /srv/oracle/wls_domains && chown -R weblogic:oracle /srv/oracle
echo -e "   Create Done!!!\n"
echo -e "   Installation Folders: /opt/bea/oracle/Middleware/12c\n"
echo -e "   Domain Folder: /srv/oracle/wls_domains\n"

# 4. 创建响应文件
echo -e "-> Creat Response file....................................................\n"
rm -rf /opt/bea/oracle/wls.rsp
touch /opt/bea/oracle/wls.rsp
# 写入配置文件
cat << EOF > /opt/bea/oracle/wls.rsp
[ENGINE]
#DO NOT CHANGE THIS.
Response File Version=1.0.0.0.0

[GENERIC]
# The oracle home location. This can be an existing Oracle Home or a new Oracle Home
ORACLE_HOME=/opt/bea/oracle/Middleware/12c
# Set this variable value to the Installation Type selected. e.g. WebLogic Server,
# Coherence, Complete with Examples.
INSTALL_TYPE=WebLogic Server
# Provide the My Oracle Support Username. If you wish to ignore Oracle Configuration
# Manager configuration provide empty string for user name.
MYORACLESUPPORT_USERNAME=
# Provide the My Oracle Support Password
MYORACLESUPPORT_PASSWORD=
# Set this to true if you wish to decline the security updates. Setting this to
# true and providing empty string for My Oracle Support username will ignore the
# Oracle Configuration Manager configuration
DECLINE_SECURITY_UPDATES=true
# Set this to true if My Oracle Support Password is specified
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
# Provide the Proxy Host
PROXY_HOST=
# Provide the Proxy Port
PROXY_PORT=
# Provide the Proxy Username
PROXY_USER=
# Provide the Proxy Password
PROXY_PWD=
# Type String (URL format) Indicates the OCM Repeater URL which should be of the format [scheme[Http/Https]]://[repeater host]:[repeater port]
COLLECTOR_SUPPORTHUB_URL=
EOF
chown weblogic:oracle /opt/bea/oracle/wls.rsp
echo -e "   Create Response file Done,it is located /opt/bea/oracle/wls.rsp\n"

# 5. 检查JDK版本，设置JAVA环境变量
echo -e "-> Check JDK Version And Set JDK..........................................\n"
jdkNowVersion=`find / -name 'javac' | grep 'jdk' | awk -F '/' '{for(i=1;i<=NF;i++) {if(substr($i,1,3)=="jdk") {print substr($i,4,3)}}}' | xargs`

# 未找到任何版本的JDK
if [ -z "$jdkNowVersion" ]; then
    # 获取JDK 1.7
    findOrDownLoadFile jdk-7u80-linux-x64.tar.gz not
    # 为weblogic用户配置JDK
    echo -e "-> Set JDK For User weblogic..............................................\n"
    setJdk weblogic /usr/local/jdk1.7.0_80
# 已经存在JDK，需要判断版本是否大于1.7
else
    # 统计有几个空格，说明有+1个JDK
    findSpace=`echo $jdkNowVersion | grep -o ' ' | wc -l`
    numJdk=`expr $findSpace + 1`
    ltjdk=0
    for nowJdkVersion in $jdkNowVersion;  
    do  
        compareJavaVersion=`echo $nowJdkVersion | awk -v javaNeedVersion="1.7" '{print($1>=javaNeedVersion)?"1":"0"}'`
        # 版本不符合要求，要求最少1.7
        if [ $compareJavaVersion -eq 0 ];then
            ltjdk=`expr $ltjdk + 1`
        # 版本符合要求
        else
            # 使用当前jdk为weblogic用户进行设置
            jdkPath=`find / -name 'javac' | grep "jdk$nowJdkVersion" | sed  's/\/bin\/javac//g'`
            setJdk weblogic $jdkPath
            echo -e "   Check JDK Version Pass!!!\n"
            break
        fi
    done
    # 现有jdk版本全都小于1.7
    if [ $ltjdk == $numJdk ];then
        echo -e "   System JDK all not, weblogic12c need 1.7"
        # 获取JDK 1.7
        findOrDownLoadFile jdk-7u80-linux-x64.tar.gz not
        # 为weblogic用户配置JDK
        echo -e "-> Set JDK For User weblogic..............................................\n"
        setJdk weblogic /usr/local/jdk1.7.0_80
    fi
fi

# 6. 查找或下载安装文件和jdk文件
echo -e "-> Find Or Download fmw_12.1.3.0.0_wls.jar................................\n"
findOrDownLoadFile not fmw_12.1.3.0.0_wls.jar

# 7. 安装weblogic 12c
echo -e "-> Begin Install Weblogic 12c.............................................\n"
su - weblogic -c "java -jar /opt/bea/oracle/fmw_12.1.3.0.0_wls.jar -silent -responseFile /opt/bea/oracle/wls.rsp -invPtrLoc /etc/oraInst.loc"
rm -rf /opt/bea/oracle/fmw_12.1.3.0.0_wls.jar /opt/bea/oracle/wls.rsp
echo -e "   Weblogic12c Install done,now set domains!!!\n"

# 8. 创建域
echo -e "-> Begin Set Weblogic 12c Domains.........................................\n"
domainName=`hostname -I | awk -F '.' '{print "Domains"$4}'`
if [ "$domainName" == "" ];then
    domainName="Domains"
fi
# domain name
while true; do
    read -p "   Input new domains name(press ENTER,default name is $domainName): "
    if [[ "$REPLY" == "" ]];then
        echo ""
        echo -e "   OK,you set domain name is $domainName\n"
        break
    else
        newDomainName=$REPLY
    fi
    checkDomainName $newDomainName
    [ $? -eq 66 ] && domainName=$newDomainName && break
done

# password
domainPasswd="weblogic123"
while true; do
    read -p "   Input weblogic password(press ENTER,default is $domainPasswd): "
    if [[ "$REPLY" == "" ]];then
        echo ""
        echo -e "   OK,you set domain password is $domainPasswd\n"
        break
    else
        newDomainPasswd=$REPLY
    fi
    checkPasswd $newDomainPasswd
    [ $? -eq 66 ] && domainPasswd=$newDomainPasswd && break
done
# port
domainPort="17001"
read -p "   Input weblogic port(press ENTER,default is $domainPort): "
if [[ "$REPLY" == "" ]];then
    echo ""
    echo -e "   OK,you set domain port is $domainPort\n"
else
    domainPort=$REPLY
    echo ""
    echo -e "   OK,you set domain port is '$domainPort'\n"
fi

mkdir -p /srv/oracle/wls_domains/$domainName
chown weblogic:oracle /srv/oracle/wls_domains/$domainName
rm -rf /srv/oracle/wls_domains/$domainName/basicWLSDomain.py
touch /srv/oracle/wls_domains/$domainName/basicWLSDomain.py
# 写入配置文件
cat << EOF > /srv/oracle/wls_domains/$domainName/basicWLSDomain.py
# Weblogic Domain Template 
# Use Basic Domain Template
readTemplate("/opt/bea/oracle/Middleware/12c/wlserver/common/templates/wls/wls.jar")

# Config AdminServer Listen Address and Port
cd('Servers/AdminServer')
set('ListenAddress','')
set('ListenPort', $domainPort)

# Config username and password of Console User
cd('/')
# 'Security/base_domain/User/weblogic' The 'weblogic' is username
cd('Security/base_domain/User/weblogic')
cmo.setPassword('$domainPasswd')

# If the domain already exists, overwrite the domain
setOption('OverwriteDomain', 'true')
# Config home directory for the JVM to be used when starting the weblogic server
setOption('JavaHome', '$wlJDKPath')
# Config the Domain folder path
writeDomain('/srv/oracle/wls_domains/$domainName')

# Close Template
closeTemplate()

# Exit script
exit()
EOF

chmod +x /srv/oracle/wls_domains/$domainName/basicWLSDomain.py
chown weblogic:oracle /srv/oracle/wls_domains/$domainName/basicWLSDomain.py
su - weblogic -c "/opt/bea/oracle/Middleware/12c/wlserver/common/bin/wlst.sh /srv/oracle/wls_domains/$domainName/basicWLSDomain.py"
echo -e "   Set Weblogic 12c Domains Done!!!\n"

echo ""
echo "##########################################################################"
echo "# Please note the following information :                                #"
echo "#  1. user:weblogic,password:abc123,group:oracle                         #"
echo "#  2. Installation Folders: /opt/bea/oracle/Middleware/12c               #"
echo "#  3. Domain Folder: /srv/oracle/wls_domains                             #"
echo "#  4. Domain user: weblogic, password: $domainPasswd                     #"
echo "##########################################################################"
echo ""
