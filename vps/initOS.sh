#!/bin/bash

# Script Description
# ------------------------------------------------------------------
# Description : After the OS installation is complete, execute the
# script for initialization, including the following operations : 
#   1. Close SELinux
#   2. Add yum repo, include : EPEL, ELRepo
#   3. Install net-tools, git, wget
#   4. Install 'oh my zsh', change zsh theme to 'ys'
#   5. System update by 'yum update'
#   6. Reboot system
# ------------------------------------------------------------------
# Create Date : 2017-06-05
# Author : Yingshf
# Notice : function return 66 is ok,return 99 is fail.
# ------------------------------------------------------------------
# ChangeLog
# 2020-05-11
# Update to CentOS 8 by Sun,Yu
# ------------------------------------------------------------------
INFO_PATH="/usr/src/scripts"
INFO_FILE="/usr/src/scripts/dymotd"
PROFILE_FILE="/etc/profile"

SSH_FOLDER="/root/.ssh/"
AUTHORIZED_KEYS="/root/.ssh/authorized_keys"
SSH_CONFIG="/etc/ssh/sshd_config"

# 检查是否为root用户
function checkRootUser ()
{
    if [ `id -u` -eq 0 ];then  
        return 66
    fi
}

# 错误处理
function errExit()
{
    echo -e "\n$1" 1>&2
    exit 99
}

# 查找命令是否存在
function findCmd ()
{
    if [ -x "$(command -v $1)" ]; then
        return 66
    fi
}

# 检查网络是否连通
function netStatus ()
{
    timeout=50
    targetUrl=baidu.com
    retCode=`curl -I -s --connect-timeout $timeout $targetUrl -w %{http_code} | tail -n1`

    if [ "x$retCode" = "x200" ]; then
        return 66
    fi
}

# 安装lsb_release（判断系统版本用的）
function installLsb_release ()
{
    source /etc/os-release
    case $ID in
    debian|ubuntu|devuan)
        return 99
        ;;
    centos|fedora|rhel)
        yumOrDnf="yum"
        findCmd bc
        bcCmdSts=`echo $?`
        if [ $bcCmdSts != "66" ]; then
            yum install -y bc >/dev/null 2>&1 || return 99
        fi
        # DNF became default package manager in "Fedora 22"
        if test "$(echo "$VERSION_ID >= 22" | bc)" -ne 0; then
            yumOrDnf="dnf"
        fi
        $yumOrDnf install -y redhat-lsb-core >/dev/null 2>&1 || return 99
        ;;
    *)
        return 99
        ;;
    esac
    return 66
}

# 通过lsb_release检查系统是否为Centos8
function checkOSByLsb_release ()
{
    release=`lsb_release -si`
    version=`lsb_release -rs | cut -f1 -d.`

    if [[ $release = "CentOS" ]] && [[ $version = "8" ]]; then
        return 66
    fi
    return 99
}

# 通过检查指定文件判断系统是否为Centos8
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

    if [ "$main_ver" != "8" ] || [ "$release" != "centos" ]; then
        return 99
    fi
    return 66
}

# 关闭SELinux
function closeSELinux ()
{
    checkSELinux=$(grep SELINUX= /etc/selinux/config | grep -v "#")
    if [ "$checkSELinux" == "SELINUX=enforcing" ]; then
        setenforce 0
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# main function
function initMain ()
{
    # check user
    checkRootUser
    userSts=`echo $?`

    # check network
    netStatus
    netSts=`echo $?`
    
    # check OS version
    if [[ $userSts = "66" ]] && [[ $netSts = "66" ]]; then
        findCmd lsb_release
        cmdSts=`echo $?`
        if [ $cmdSts != "66" ]; then
            installLsb_release
            installSts=`echo $?`
        fi 
        
        if [[ $installSts = "66" ]] || [[ $cmdSts = "66" ]]; then
            checkOSByLsb_release
            releaseSts=`echo $?`
        else
            checkOSByFile
            releaseSts=`echo $?`
        fi
        if [ $releaseSts != "66" ]; then
            echo -e "\nScript only supports Centos8, exit."
            exit 99
        fi
    else
       if [ $userSts != "66" ]; then
           echo -e "\nThe current user is not the root, please switch to the root user."
       fi
       if [ $netSts != "66" ]; then
           echo -e "\nThe Network is unreachable, please check the network."
       fi
       exit 99
    fi
}

# 添加epel仓库
function addYumRepo ()
{
    if [[ ! -f /etc/yum.repos.d/epel.repo ]]; then
        yum install epel-release -y >/dev/null 2>&1 || errExit "Add EPEL fail, exit"
    fi
    yum install -y net-tools git wget >/dev/null 2>&1 || errExit "Install net-tools git fail, exit"
}

# 安装ohmyzsh
function installOhMyZsh ()
{
    if [[ ! -f /root/.zshrc ]]; then
        yum install -y zsh >/dev/null 2>&1 || errExit "Install zsh fail, exit"
        curl -s -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh >/dev/null 2>&1 || errExit "Install ohmyzsh fail, exit"
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /root/.zshrc 
    fi
}

# 延迟10秒重启系统
function delayedReboot()
{
    IFS=''
    echo -e "$1升级完毕,系统将于10秒后重启,立即重启请按ENTER,取消请按Ctrl+C"
    for (( i=10; i>0; i--)); do
        printf "\rStarting in $i seconds..."
        read -s -N 1 -t 1 key

        if [ "$key" == $'\x0a' ] ;then
            break
        fi
    done
    reboot
}

# 设置ssh key和ssh登录
function sshLogin()
{
    if [ ! -e "$AUTHORIZED_KEYS" ]; then
        read -p "是否需要为您生成SSH密钥?(y/n)"
        if [[ "$REPLY" == "y" ]];then
            while :
            do
                read -p "请输入你的Email:" email
                str=`echo $email | awk '/^([a-zA-Z0-9_\-\.\+]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$/{print $0}'`
                if [ ! -n "${str}" ];then
                    echo "Email格式错误,请重新输入!"
                    continue
                fi
                break
            done
            echo -e "请输入你想要的名称,该名称会和id_rsa一起形成最终的Key文件[id_rsa.你输入的名称]:"
            read keyname
            ssh-keygen -q -t rsa -b 4096 -f ~/.ssh/id_rsa."$keyname" -C "$email" -P ''
            echo "-##- ************************************************************** -##-"
            echo "已经为您生成了id_rsa.$keyname 和 id_rsa.$keyname.pub文件，他们放在~/.ssh目录下"
            touch $AUTHORIZED_KEYS
            chmod 600 $AUTHORIZED_KEYS
            cat ~/.ssh/id_rsa.$keyname.pub > $AUTHORIZED_KEYS
        elif [[ "$REPLY" == "n" ]];then
            read -p "请提供你自己的key,形如'ssh-rsa xxx...xxx:'"
            SSHKEY=$REPLY
            mkdir -p $SSH_FOLDER
            chmod 700 $SSH_FOLDER
            touch $AUTHORIZED_KEYS
            chmod 600 $AUTHORIZED_KEYS

            echo $SSHKEY >> $AUTHORIZED_KEYS
            echo >> $AUTHORIZED_KEYS
        else
            echo -e "\n无法识别您的输入,退出!!"
            exit 
        fi
        # Edit "/etc/ssh/sshd_config"
        echo -e "\n开始设置证书登录方式..."
        sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' $SSH_CONFIG
        sed -i 's/#StrictModes yes/StrictModes yes/g' $SSH_CONFIG
        sed -i 's/#RSAAuthentication yes/RSAAuthentication yes/g' $SSH_CONFIG
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' $SSH_CONFIG
        sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' $SSH_CONFIG
        
        # Restart Service
        echo -e "\n重启SSH服务..."
        systemctl restart sshd.service
        echo -e "\n搞定,退出!!"
    else
        echo -e "\n已经存在authorized_keys文件,可能配置过ssh登录,请核实,先退出!!"
        exit
    fi
}

# 启动信息
function modifyLoinInfo() {
    echo -e "\n开始执行,请耐心等待..."
    if [ `rpm -qa | grep figlet |wc -l` -eq 0 ]; then
        echo -e "\n正在安装figlet,请耐心等待....."
        wget ftp://ftp.pbone.net/mirror/ftp.freshrpms.net/pub/freshrpms/pub/dag/redhat/el5/en/x86_64/dries/RPMS/figlet-2.2.2-1.el5.rf.x86_64.rpm >/dev/null 2>&1 || error_exit "wget下载rpm失败,退出"
        rpm -ivh figlet-2.2.2-1.el5.rf.x86_64.rpm >/dev/null 2>&1 || error_exit "rpm安装figlet失败,退出!!"
        rm -f figlet-2.2.2-1.el5.rf.x86_64.rpm
    fi
    
    echo -e "\n正在创建相关目录和文件,请耐心等待......"
    if [ ! -d "$INFO_PATH" ]; then
        mkdir -p $INFO_PATH
    fi
    cd $INFO_PATH
    if [ ! -f "$INFO_FILE" ]; then
        wget https://raw.githubusercontent.com/sunyu1984/shell/master/resources/motd/dymotd
        chmod +x $INFO_FILE
    else
        mv $INFO_FILE $INFO_FILE"_bak"
        wget https://raw.githubusercontent.com/sunyu1984/shell/master/resources/motd/dymotd
        chmod +x $INFO_FILE
    fi
    
    sed -i 's/^[][ ]*//g' $INFO_FILE
    # Add boot
    tail -1 $PROFILE_FILE | grep $INFO_FILE >/dev/null
    if [ $? -ne 0 ]; then
        echo $INFO_FILE >> $PROFILE_FILE
    fi
    # notice
    echo -e "\n登录信息放在/usr/src/scripts/dymotd文件中,请自行查看相关内容"
}



# -------------------------------
# Begin InitCentos
# -------------------------------

clear
echo ""
echo "#############################################################"
echo "# The following operations will be performed                #"
echo "#  1. #Close SELinux                                        #"
echo "#  2. Add yum repo, include : EPEL                          #"
echo "#  3. Install net-tools, git, wget                          #"
echo "#  4. Install 'oh my zsh', change zsh theme to 'ys'         #"
echo "#  5. #Set SSH Key And SSH Login                            #"
echo "#  6. Add Login info                                        #"
echo "#############################################################"
echo ""

echo -e "Checking environment.........................................\n"
initMain
echo -e "Closing SELinux..............................................\n"
closeSELinux
echo -e "Add Yum Repo And Install net-tools, git, wget...\n"
addYumRepo
echo -e "Installing Oh My Zsh.........................................\n"
installOhMyZsh
# echo -e "Set SSH Key And SSH Login....................................\n"
# sshLogin
echo -e "Add Login info...............................................\n"
modifyLoinInfo