#!/bin/bash

# Script Description
# ------------------------------------------------------------------
# Description :  
#   离网情况下，通过RPM包安装MySQL5.7.18
# ------------------------------------------------------------------
# Create Date : 2017-07-08
# Author : Yingshf
# Notice : function return 66 is ok,return 99 is fail.
# ------------------------------------------------------------------

clear

installPath="/tmp/installmysql"

mysqlVersion="5.7.18-1.el7.x86_64"
mysqlTarFile="mysql-5.7.18-1.el7.x86_64.rpm-bundle.tar"
mariadbVersion=`rpm -qa | grep mariadb`
nettoolsRpmFile="net-tools-2.0-0.17.20131004git.el7.x86_64.rpm"

mysqlSts=`rpm -qa | grep mysql-community-server- | wc -l`
netToolsSts=`rpm -qa | grep net-tools | wc -l`

ftpAddr="10.161.32.100"
ftpUser=""
ftpPasswd=""

# 错误退出
function errExit()
{
    echo -e "\n$1" 1>&2
    exit 99
}

function delayed()
{
    IFS=''
    echo -e "After 30 seconds execute, immediately press ENTER, cancel press Ctrl + C!"
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

# -------------------------------
# Begin Install MySQL5.7.18
# -------------------------------
####
echo ""
echo "##########################################################################"
echo "# The following operations will be performed:                            #"
echo "#  1. Close SELinux                                                      #"
echo "#  2. Install net-tools                                                  #"
echo "#  3. Install MySQL 5.7.18_X86_64                                        #"
echo "##########################################################################"
echo ""

# check user
checkRootUser
userSts=`echo $?`
if [ $userSts != "66" ]; then
    echo -e "The current user is not root, please switch to the root user.\n"
    exit 99
fi

findMysql=`find / -name $mysqlTarFile | wc -l`
findNetTools=`find / -name $nettoolsRpmFile | wc -l`
locateMysql=`find / -name $mysqlTarFile | sed "s/$mysqlTarFile//g"`
locateNetTools=`find / -name $nettoolsRpmFile | sed "s/$nettoolsRpmFile//g"`

delayed
mkdir -p $installPath
cd $installPath

echo -e "\n"
echo -e "-> Close SELinux..........................................................\n"
closeSELinux
echo -e "   Close OK!\n"

echo -e "-> Find Files.............................................................\n"

if [ $mysqlSts == 0 ];then
    if [ $findMysql == 0 ];then
        echo -e "   Not found MySQL file, Now download from ftp://10.161.32.100\n"
        read -p "   Please input ftp account: "
        ftpUser=$REPLY
        read -p "   Please input ftp account's password: "
        ftpPasswd=$REPLY
        echo -e "   Begin Download Mysql..............\n"
        wget ftp://$ftpUser:$ftpPasswd@$ftpAddr/$mysqlTarFile >/dev/null 2>&1 || errExit "   Download MySQL fail,Exit!!!"
        echo -e "   Download finished!................\n"
    else
        echo -e "   found MySQL file, Pass!!!\n"
        # 复制到/tmp/installmysql目录
        cp $locateMysql/$mysqlTarFile $installPath >/dev/null 2>&1
    fi

    if [ $netToolsSts == 0 ];then
        if [ $findNetTools == 0 ];then
            echo -e "   Not found net-tools rpm, Now download from ftp://10.161.32.100\n"
            if [ -z "$ftpUser" ]; then
                read -p "   Please input ftp account: "
                ftpUser=$REPLY
                read -p "   Please input ftp account's password: "
                ftpPasswd=$REPLY
            fi
            echo -e "   Begin Download net-tools..........\n"
            wget ftp://$ftpUser:$ftpPasswd@$ftpAddr/$nettoolsRpmFile >/dev/null 2>&1 || errExit "   Download net-tools fail,Exit!!!"
            echo -e "   Download finished!................\n"
            
        else
            echo -e "   found net-tools file, Pass!!!\n"
            # 复制到/tmp/installmysql目录
            cp $locateNetTools/$nettoolsRpmFile $installPath >/dev/null 2>&1
        fi
        echo -e "   Begin Install net-tools...........\n"
        rpm -ivh $nettoolsRpmFile --nodeps >/dev/null 2>&1 || errExit "   Install fail,Exit!!!"
        echo -e "   Install net-tools finished........\n"
    fi
else
    echo -e "   MySQL already installed,Exit!!!\n"
    exit 99
fi

echo -e "   Find OK!\n"
echo -e "-> Uninstall the system's own mariadb-lib.................................\n"
if [ `rpm -qa | grep mariadb |wc -l` -ne 0 ]; then
    echo -e "   Begin Uninstall Mariadb...........\n"
    rpm -e $mariadbVersion --nodeps >/dev/null 2>&1 || errExit "   Uninstall fail,Exit!!!"
    echo -e "   Uninstall OK!\n"
else
    echo -e "   Not found Mariadb,Pass!\n"
fi

# 解压文件
echo -e "-> Begin unzip............................................................\n"
rm -rf $installPath/mysql-community-*-$mysqlVersion.rpm
tar xvf $mysqlTarFile >/dev/null 2>&1 || errExit "  Unzip Fail,Exit!!!"
echo -e "   Unzip OK!\n"

# 开始安装，rpm包的安装有顺序要求
echo -e "-> Install MySQL 5.7.18...................................................\n"
rpm -ivh --replacepkgs mysql-community-common-$mysqlVersion.rpm >/dev/null 2>&1 || errExit "   Install mysql-community-common-$mysqlVersion.rpm Fail,Exit!!!"
rpm -ivh --replacepkgs mysql-community-libs-$mysqlVersion.rpm >/dev/null 2>&1 || errExit "   Install mysql-community-libs-$mysqlVersion.rpm Fail,Exit!!!"
rpm -ivh --replacepkgs mysql-community-client-$mysqlVersion.rpm >/dev/null 2>&1 || errExit "   Install mysql-community-client-$mysqlVersion.rpm Fail,Exit!!!"
rpm -ivh --replacepkgs mysql-community-server-$mysqlVersion.rpm >/dev/null 2>&1 || errExit "   Install mysql-community-server-$mysqlVersion.rpm Fail,Exit!!!"
echo -e "   Install OK!\n"

# 数据库初始化（如果是mysql用户，可以去掉--user）
echo -e "-> Init MySQL.............................................................\n"
mysqld --initialize --user=mysql >/dev/null 2>&1 || errExit "   Uninstall fail,Exit!!!"
echo -e "   Init MySQL OK!\n"
mysqlRootPasswd=`cat /var/log/mysqld.log | grep "temporary password" | sed 's/.*root@localhost: //g'`
echo -e "   MySQL root account temporary password is :$mysqlRootPasswd\n"

# 添加防火墙例外
firewallState=`systemctl status firewalld | grep 'inactive (dead)' | wc -l`
if [ $firewallState -eq 0 ];then
    echo -e "-> Set Firewalld..........................................................\n"
    firewall-cmd --add-service=mysql --permanent >/dev/null 2>&1 || errExit "   Set Firewalld Fail,Exit!!!"
    firewall-cmd --reload >/dev/null 2>&1 || errExit "   Reload Firewalld Fail,Exit!!!"
    echo -e "   Set Firewalld OK!\n"
    echo -e "-> Install Finished.......................................................\n"
fi

# 后续提醒进一步设置
read -p "   Input new root password you want: "
newRootPasswd=$REPLY

echo "##########################################################################"
echo "# Please perform the following settings manually : "
echo "#  1. Change root account password: "
echo "#     ->  systemctl start mysqld"
echo "#     ->  mysql -uroot -p ( The temp password is $mysqlRootPasswd )"
echo "#     ->  ALTER USER 'root'@'localhost' IDENTIFIED BY '$newRootPasswd';"
echo "#     ->  grant all privileges on *.* to root@'localhost' identified by '$newRootPasswd';"
echo "#     ->  systemctl restart mysqld"
echo "#  2. Set root remote access(If you want,I do not recommend it): "
echo "#     ->  mysql -uroot -p (The password is your set) "
echo "#     ->  use mysql;"
echo "#     ->  update user set host = '%' where user = 'root';"
echo "#     ->  flush privileges;"
echo "#     ->  exit;"
echo "##########################################################################"

rm -rf $installPath/mysql-community-*-$mysqlVersion.rpm
cd ~
