#!/bin/bash

# Script Description
# ------------------------------------------------------------------
# Description : including the following operations 
#   1. Modify IP Address
#   2. Change HostName
#   3. Check Firewalld, If no, install it
#   4. Reboot system
# ------------------------------------------------------------------
# Create Date : 2017-06-09
# Author : Yingshf
# Notice : function return 66 is ok,return 99 is fail.
# ------------------------------------------------------------------

clear

# Global variables
ethConfigFile='/etc/sysconfig/network-scripts/ifcfg-'
ethNameIndex=0
ethNameArray[0]=''
# 声明字典
declare -A ethInfoDict

# 查找命令是否存在
function findCmd ()
{
    if [ -x "$(command -v $1)" ]; then
        return 66
    fi
}

# 错误处理
function errExit()
{
    echo -e "\n$1" 1>&2
    exit 99
}

# 检查IP格式
function checkIp() {
    local ipAddress=$1
    local VALID_CHECK=$(echo $ipAddress | awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')

    if echo $ipAddress | grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then
        if [[ $VALID_CHECK == "yes" ]]; then
            return 66
        else
            echo "输入的IP $ipAddress 不是有效的IP!"
            return 99
        fi
    else
        echo "IP格式不正确!"
        return 1
    fi
}

# 把数字转换为二进制数字  
numToBin()  
{  
    num="$1"  
    numToBin=`echo "obase=2;$num" | bc`  
    echo $numToBin  
}  

# IP地址字符串转整数
ipStrToInt()  
{  
    echo $1 | gawk '{c=256;split($0,ip,".");print ip[4]+ip[3]*c+ip[2]*c^2+ip[1]*c^3}'  
}  

# 验证子网掩码的正确性  
checkMaskFormat()  
{     
    echo $1 | grep "^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$" > /dev/null    
    if [ $? = 1 ]; then
        echo "掩码格式有问题!"  
        return 99  
    fi  
      
    a=`echo $1 | awk -F. '{print $1}'`  
    b=`echo $1 | awk -F. '{print $2}'`  
    c=`echo $1 | awk -F. '{print $3}'`  
    d=`echo $1 | awk -F. '{print $4}'`  
      
    a=`numToBin $a`  
    b=`numToBin $b`  
    c=`numToBin $c`  
    d=`numToBin $d`  
      
    for i in $a $b $c $d;do  
        [[ $i != 0 && ${#i} != 8 ]] && echo "掩码格式有问题!" && return 99  
    done  
    mask=$a$b$c$d  
    [[ "$mask" =~ ^1[1]*[0]*$ ]] || return 99 
      
    return 66  
}  

# IP、子网掩码和网关的有效性判断
isValidNet()  
{  
    ip=$1  
    mask=$2  
    gw=$3  
      
    #ip&mask == gw&mask while is a valid net  
    ipn=$(ipStrToInt $ip)  
    maskn=$(ipStrToInt $mask)  
    gwn=$(ipStrToInt $gw)  
      
    if [ $(($ipn & $maskn)) -ne $(($gwn & $maskn)) ];then
        echo "校验IP、掩码和网关的关系失败!脚本将退出!请重新检查并运行脚本!"  
        exit 99  
    fi  
} 

# 根据IP、子网掩码计算Prefix
maskToPrefix()  
{  
    ip=(${1//[![:digit:]]/ })
    mask=(${2//[![:digit:]]/ })
    
    for i in ${mask[*]}
    do
            j=7
            tag=1
            while [ $j -ge 0 ]
            do
              k=$((2**$j))          
              if [[ $(( $i & $k )) -eq $k ]]; then
                    if [ $tag -eq 1 ]; then
                       (( n += 1 ))
                    else
                       echo -e "\n$2 is a bad netamsk with holes\n"
                       exit
                    fi
               else
                    tag=0
               fi
               (( j -= 1 ))
              done
    done
    
    for i in 0 1 2 3
    do
    a=$a${a:+.}$((${ip[i]} & ${mask[i]}))
    b=$b${b:+.}$((${ip[i]} | (${mask[i]} ^ 255)))
    done
    echo $n  
} 

# 获取网络信息，包括：ip,netmask,gateway,status,dns,hostname
function printInfo ()
{
    ethNameList=`ifconfig -a | grep '^e.*: flags' | awk '{print $1}' | sed 's/://g'`
    # 网卡存在
    if ! [[ $ethNameList = '' ]]; then
        echo -e "   ------ ------------  --------------- -------- ---------- ------ ----- --------"
        echo -e "  | 网卡 | 是否插网线 | 是否有配置文件 | IP地址 | 子网掩码 | 网关 | DNS | 主机名 |"
        echo -e "   ------ ------------  --------------- -------- ---------- ------ ----- --------"
        for ethName in ${ethNameList}
        do
            spacestr='| '
            ethLinkSts=''
            ethInfoString=''
            ethIpAddress=''
            ipLength=''
            ethNetmask=''
            ethGateWay=''
            ethDns=''
            ethConfig=''
            configFileExist='yes'
    
            # 获取网卡配置文件
            ethConfig=$ethConfigFile$ethName
            if [ ! -f "$ethConfig" ]; then
                configFileExist="not"
            fi
            
            # get info
            ethLinkSts=`ethtool $ethName | grep 'Link detected:' | awk '{print $3}'`
            ethIpAddress=`ifconfig $ethName | grep 'inet '| awk '{print $2}'`
            ethNetmask=`ifconfig $ethName | grep 'netmask '| awk '{print $4}'`
            ethGateWay=`route -n | grep $ethName | grep UG | awk '{print $2}'`
            ethDns=`awk '/^nameserver [0-9]*[.]/{print $2}' /etc/resolv.conf | xargs | sed -e 's/ /\//g'`
            ethHostName=`hostname`
            
            # IP地址的长度,用于后续格式化输出时补充空格以便对齐
            ipLength=${#ethIpAddress}
            # IP地址xxx.xxx.xxx.xxx长度为15
            while (( ipLength < 15 ))
            do  
                spacestr=' '$spacestr
                let "ipLength++"  
            done
            ethIpAddress=$ethIpAddress$spacestr

            # concat string
            ethInfoString=$ethName' | '$ethLinkSts' | '$configFileExist' | '$ethIpAddress$ethNetmask' | '$ethGateWay' | '$ethDns' | '$ethHostName
            if ! [[ $ethName = '' ]] && ! [[ $ethInfoString = '' ]]; then
                # 保存到字典中
                ethInfoDict[$ethName]=$ethInfoString
                ethNameIndex=`expr $ethNameIndex + 1`
                # 不加双引号则输出时多个空格被合并为1个
                echo -e "$ethInfoString"
            fi
            if [ $ethNameIndex = 0 ]; then
                echo "生成字典异常,退出!"
                exit 99
            fi
        done
    else
        echo "未检测到系统网卡,退出!"
        exit 99
    fi
}

# -------------------------------
# Begin
# -------------------------------

# 查找依赖的bc命令
findCmd bc
bcCmdSts=`echo $?`
if [ $bcCmdSts != "66" ]; then
    echo -e "正在为您通过yum安装bc,bc是用于数值计算的!!!"
    yum install -y bc >/dev/null 2>&1 || errExit "Install bc fail, exit!!!"
fi

# 打印网络信息
printInfo

echo ""
read -p "输入想修改的[网卡名]开始进行修改,直接[回车]则代表您不想做任何修改: "
if [[ "$REPLY" == "" ]];then
    echo -e "\n退出!"
    exit 99
else
    inputEthName=$REPLY
    # 判断字典中是否存在输入的网卡，如果存在则进行处理
    if [[ ${!ethInfoDict[*]} == *$REPLY* ]]; then
        # 去掉字典中字符串的连续空格，并将|替换为单个空格
        dicEthInfo=`echo ${ethInfoDict["$REPLY"]} | sed 's/ //g' | sed 's/|/ /g'`
        dicEthLinkSts=`echo $dicEthInfo | awk '{print $2}'`
        dicEthConfigFiles=`echo $dicEthInfo | awk '{print $3}'`
        dicEthIpAddress=`echo $dicEthInfo | awk '{print $4}'`
        dicEthNetmask=`echo $dicEthInfo | awk '{print $5}'`
        dicEthGateWay=`echo $dicEthInfo | awk '{print $6}'`
        dicEthDns=`echo $dicEthInfo | awk '{print $7}'`
        dicEthHostName=`echo $dicEthInfo | awk '{print $8}'`
        # 统计DNS字符串中包含几个/,即有几个'/'+1个DNS
        dnsCount=`echo $dicEthDns | grep -o '/' | wc -l`

        ifs=$IFS
        IFS=
        
        echo ""
        while true; do
            read -p "请输入新的IPV4地址(直接'回车'则默认为$dicEthIpAddress): "
            if [[ "$REPLY" == "" ]];then
                newIp=$dicEthIpAddress
            else
                newIp=$REPLY
            fi
            checkIp $newIp
            [ $? -eq 66 ] && break
        done
        
        echo ""
        while true; do
            read -p "请输入新的子网掩码(直接'回车'则默认为$dicEthNetmask): "
            if [[ "$REPLY" == "" ]];then
                newMask=$dicEthNetmask
            else
                newMask=$REPLY
            fi
            checkMaskFormat $newMask
            [ $? -eq 66 ] && break
        done
        
        echo ""
        read -p "请输入新的网关(直接'回车'则默认为$dicEthGateWay): "
        if [[ "$REPLY" == "" ]];then
            newGate=$dicEthGateWay
        else
            newGate=$REPLY
        fi
        
        echo ""
        # 没有dns或只有1个dns
        if [[ $dnsCount -eq 0 ]]; then
            read -p "您当前DNS为$dicEthDns，不修改请直接‘回车’，追加请输入i，全部替换请输入a): "
            if [[ "$REPLY" == "" ]];then
                newDns=$dicEthDns
            elif [[ "$REPLY" == "i" ]];then
                echo ""
                read -p "请输入要追加的DNS，多个DNS以半角逗号分隔: "
                newDns=$dicEthDns"/"`echo $REPLY | sed 's/,/\//g'`
            elif [[ "$REPLY" == "a" ]];then
                echo ""
                read -p "请输入新的DNS，多个DNS以半角逗号分隔: "
                newDns=`echo $REPLY | sed 's/,/\//g'`
            else
                echo "您输入的有误，暂不为您修改DNS"
                newDns=$dicEthDns
            fi
        # 多个dns
        else
            dnsNum=`expr $dnsCount + 1`
            echo "您有$dnsNum个DNS，它们是[$dicEthDns]"
            read -p "保留原DNS请直接'回车'，全部替换请输入a，部分修改请输入p: "
            if [[ "$REPLY" == "" ]];then
                newDns=$dicEthDns
            elif [[ "$REPLY" == "a" ]];then
                echo ""
                read -p "请输入新的DNS，多个DNS以半角逗号分隔: "
                newDns=`echo $REPLY | sed 's/,/\//g'`
            elif [[ "$REPLY" == "p" ]];then
                echo ""
                read -p "您现在的DNS是$dicEthDns，您要修改哪个请输入对应数字，例如输入1则代表修改第1个DNS："
                dnsIndex=$REPLY
                keyCmd="f"$dnsIndex
                replaceDns=`echo $dicEthDns | cut -d "/" -$keyCmd`

                read -p "新的DNS是什么(只能输入一个)："
                tmpDns=$REPLY
                newDns=`echo $dicEthDns | sed "s/$replaceDns/$tmpDns/g"`
            else
                echo "您输入的有误，暂不为您修改DNS"
                newDns=$dicEthDns
            fi
        fi

        # 校验IP、掩码和网关的关系是否正确
        isValidNet $newIp $newMask $newGate
        # 计算Prefix
        ethPrefix=`ipcalc -p $newIp $newMask | sed 's/PREFIX=/''/g'`
        # 生成网卡UUID
        ethUUID=`uuidgen`

        echo ""
        read -p "请输入新的主机名(直接'回车'则默认为$dicEthHostName): "
        if [[ "$REPLY" == "" ]];then
            newHostname=$dicEthHostName
        else
            newHostname=$REPLY
        fi

        echo ""
        echo "#############################################################"
        echo "#  信息收集完毕，请核对网卡$inputEthName的如下新信息："
        echo "#  新地址   : $newIp "
        echo "#  新掩码   : $newMask "
        echo "#  新网关   : $newGate "
        echo "#  新DNS    : $newDns "
        echo "#  新主机名 : $newHostname "
        echo "#############################################################"
        echo ""

        echo -e "请核实上述信息,确认无误请按ENTER开始进行修改,取消请按Ctrl+C"
        for (( i=120; i>0; i--)); do
            printf "\rStarting in $i seconds..."
            read -s -N 1 -t 1 key
            if [ "$key" == $'\x0a' ] ;then
                break
            fi
        done

        echo ""
        if [[ $dicEthConfigFiles == "yes" ]]; then
            echo -e "\n开始进行修改......"
            mv $ethConfigFile$inputEthName $ethConfigFile$inputEthName".bak"
            touch $ethConfigFile$inputEthName
        elif [[ $dicEthConfigFiles == "not" ]]; then
            echo -e "\n开始进行修改，脚本发现网卡$inputEthName没有配置文件，将会同时为您生成配置文件......"
            touch $ethConfigFile$inputEthName
        fi
        # 写入配置文件
        cat << EOF > $ethConfigFile$inputEthName
        TYPE=Ethernet
        BOOTPROTO=static
        DEFROUTE=yes
        IPV4_FAILURE_FATAL=no
        IPV6INIT=yes
        IPV6_AUTOCONF=yes
        IPV6_DEFROUTE=yes
        IPV6_FAILURE_FATAL=no
        IPV6_ADDR_GEN_MODE=stable-privacy
        IPV6_PEERDNS=yes
        IPV6_PEERROUTES=yes
        IPV6_PRIVACY=no
        NAME=$inputEthName
        UUID=$ethUUID
        DEVICE=$inputEthName
        ONBOOT=yes
        IPADDR=$newIp
        PREFIX=$ethPrefix
        GATEWAY=$newGate
EOF
        # Delete the 8 spaces
        sed -i 's/^[][ ]*//g' $ethConfigFile$inputEthName
        # 写入DNS，另一块网卡（如果有的话）也需要更新一下，否则/etc/resolv.conf里的dns和网卡配置文件里的对应不上
        for ethDns in ${ethNameList}
        do
            if [[ $inputEthName == $ethDns ]]; then
                echo $newDns | awk -F "/" '{for (i=1;i<=NF;i++) {print "DNS"i"=" $i}}' >> $ethConfigFile$inputEthName
            else
                # 如果另一块网卡有配置文件
                if [[ -f $ethConfigFile$ethDns ]]; then
                    sed -i -e '/DNS.=/d' $ethConfigFile$ethDns
                    echo $newDns | awk -F "/" '{for (i=1;i<=NF;i++) {print "DNS"i"=" $i}}' >> $ethConfigFile$ethDns
                fi 
            fi
        done
        
        # 修改主机名
        hostnamectl set-hostname $newHostname
        echo -e "\n已完成修改，即将重启网络服务......"
        systemctl restart network
        echo -e "\n重启完成，脚本退出!"
        echo -e "\n请退出后重新登录!"
        IFS=$ifs
    else
        echo -e "\n未找到您输入的网卡,退出!"
        exit 99
    fi
fi
