#!/bin/bash

SQ_USER="myhttp"
SQ_PORT="3128"
SQ_PASSWD="Abcd,1234"
SQ_PASSWD_DIR="/etc/squid3/"
SQ_CONF="/etc/squid/squid.conf"
SQ_FIREWALLD_CONF="/etc/firewalld/services/squid.xml"

# ---------------------------------------------------
#   1. installSQ      : 安装Squid并添加到系统服务
# ---------------------------------------------------
installSQ() {
    # 通过yum安装
    echo -e "\n开始通过yum安装Squid......"
    yum -y install squid httpd-tools >/dev/null 2>&1 || error_exit "yum安装Squid失败,退出!!"    

    echo -e "\n安装完成，现在开始收集账号密码信息......"

    read -p "请输入您要设置的Http(s)代理的账号名(直接'回车'则默认为$SQ_USER): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认帐号："$SQ_USER
    else
        SQ_USER=$REPLY
        echo -e "\n您输入的帐号为："$SQ_USER
    fi

    # 生成密码文件
    if [ ! -d "$SQ_PASSWD_DIR" ]; then
        mkdir -p $SQ_PASSWD_DIR
    fi
    
    read -p "请输入您要设置的Http(s)代理的密码，注意密码不要超过8位(直接'回车'则默认为$SQ_PASSWD): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认密码："$SQ_PASSWD
    else
        SQ_PASSWD=$REPLY
        echo -e "\n您输入的密码为："$SQ_PASSWD
    fi
    # 生成加密的密码文件
    htpasswd -cb /etc/squid3/passwords $SQ_USER $SQ_PASSWD
    
    read -p "请输入您要设置的Http(s)代理的端口号(直接'回车'则默认为$SQ_PORT): "
    if [[ "$REPLY" == "" ]];then
        echo -e "\n将为您使用默认端口"$SQ_PORT
    else
        SQ_PORT=$REPLY
        echo -e "\n您输入的端口为："$SQ_PORT
    fi

    # 修改配置文件
    cp $SQ_CONF $SQ_CONF.bak
    sed -i 's/http_port 3128/#http_port 3128/g' $SQ_CONF 
    cat << EOF >> $SQ_CONF

    auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid3/passwords
    auth_param basic realm proxy
    acl authenticated proxy_auth REQUIRED
    http_access allow authenticated
    http_port $SQ_PORT
    acl localnet src 0.0.0.1-255.255.255.255
EOF
    # Delete the spaces
    sed -i 's/^[][ ]*//g' $SQ_CONF
    
    systemctl enable squid >/dev/null 2>&1
    systemctl start squid

    firewall-cmd --zone=public --add-port=$SQ_PORT/tcp --permanent
    firewall-cmd --zone=public --add-port=$SQ_PORT/udp --permanent
    firewall-cmd --reload

    # Add alias
    echo "alias sqs='systemctl status squid -l'" >> ~/.zshrc
    echo "alias sqstart='systemctl start squid'" >> ~/.zshrc
    echo "alias sqstop='systemctl stop squid'" >> ~/.zshrc
    # notice
    echo -e "\n已为您完成squid的安装和配置(随系统自启停)"
    echo -e "\n为您添加了sqs,sqstart,sqstop三个命令别名,分别是查看状态,启动,停止.详情请查看/etc/bashrc中的相关定义"
}

installSQ