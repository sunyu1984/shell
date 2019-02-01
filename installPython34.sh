#!/bin/bash

# Script Description
# ------------------------------------------------------------------
# Description :  
#   提供源码或yum安装安装python3.4两种方式，根据机器性能自己选择
# ------------------------------------------------------------------
# Create Date : 2017-07-06
# Author : Yingshf
# Notice : function return 66 is ok,return 99 is fail.
# ------------------------------------------------------------------

# 错误处理
function errExit()
{
    echo -e "\n$1" 1>&2
    exit 99
}

# 延迟
function delayed()
{
    IFS=''
    echo -e "脚本将于30秒后执行,立即执行请按ENTER,取消请按Ctrl+C,不是Centos7的系统请取消执行!"
    for (( i=30; i>0; i--)); do
        printf "\rStarting in $i seconds..."
        read -s -N 1 -t 1 key

        if [ "$key" == $'\x0a' ] ;then
            break
        fi
    done
}

clear
shv=`env | grep SHELL | sed 's/SHELL=//g'`

echo ""
echo "####################################################################"
echo "# 脚本不检测操作系统类型和版本，但脚本仅适用于Centos7，不符请退出！#"
echo "# 单核CPU不建议选择源码方式安装                                    #"
echo "# Yum方式安装Python3.4需要添加EPEL源，不喜勿装                     #"
echo "####################################################################"
echo ""

delayed
echo ""

echo -e "将通过Yum安装依赖...................................................\n"
yum groupinstall -y 'Development Tools' >/dev/null 2>&1 || errExit "安装Development Tools失败，退出!"
yum install -y zlib-devel bzip2-devel openssl-devel ncurese-devel sqlite-devel gdbm-devel xz-devel tk-devel readline-devel wget >/dev/null 2>&1 || errExit "安装zlib-devel bzip2-devel openssl-devel ncurese-devel失败，退出!"
echo -e "安装依赖成功!.......................................................\n"

read -p "通过源码安装Python3.4请输入s，通过yum安装请输入y: "
if [[ "$REPLY" == "s" ]];then
    echo ""
    cd /tmp
    echo -e "下载Python3.4.6.....................................................\n"
    wget https://www.python.org/ftp/python/3.4.6/Python-3.4.6.tar.xz >/dev/null 2>&1 || errExit "下载Python3.4.6失败，退出!"
    tar Jxvf Python-3.4.6.tar.xz >/dev/null 2>&1 || errExit "解压缩Python3.4.6失败，退出!"
    cd Python-3.4.6/
    echo -e "开始编译安装........................................................\n"
    ./configure --silent --prefix=/usr/local/python3 >/dev/null 2>&1 || errExit "Configure Python3.4.6失败，退出!"
    make --silent && make install >/dev/null 2>&1 || errExit "编译安装Python3.4.6失败，退出!"
    echo -e "添加环境变量........................................................\n"
    # 添加到环境变量
    if [[ $shv == "/bin/bash" ]];then
        sed -i 's/PATH=.*/&:\/usr\/local\/python3\/bin/g' ~/.bash_profile
        echo -e "\n环境变量添加完成，请手工执行一下：source ~/.bash_profile"
    elif [[ $shv == "/bin/zsh" ]];then
        if [[ -f ~/.zshrc ]]; then
            echo '' >> ~/.zshrc
            echo 'export PATH=$HOME/bin:/usr/local/bin:$PATH:/usr/local/python3/bin' >> ~/.zshrc
            echo -e "\n环境变量添加完成，请手工执行一下：source ~/.zshrc"
        fi
    fi
    echo -e "安装成功,退出.......................................................\n"
elif [[ "$REPLY" == "y" ]];then
    echo ""
    if [[ ! -f /etc/yum.repos.d/epel.repo ]]; then
        echo -e "为您添加EPEL源......................................................\n"
        yum install -y epel-release >/dev/null 2>&1 || errExit "Add EPEL fail, exit"
    fi
    echo -e "开始安装Python34....................................................\n"
    yum install -y python34 >/dev/null 2>&1 || errExit "安装Python3.4失败，退出!"
    echo -e "开始安装Python34-setuptools.........................................\n"
    yum install -y python34-setuptools >/dev/null 2>&1 || errExit "安装python34-setuptools失败，退出!"
    echo -e "开始安装Pip3........................................................\n"
    cd /tmp
    curl -O https://bootstrap.pypa.io/get-pip.py >/dev/null 2>&1 || errExit "下载get-pip失败，退出!"
    python3.4 get-pip.py >/dev/null 2>&1 || errExit "安装Pip3失败，退出!"
    echo -e "安装成功，退出......................................................\n"
else
    echo "输入错误，退出!"
    exit 99
fi
