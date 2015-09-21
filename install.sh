#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS6.x (32bit/64bit) or Ubuntu
#   Description:  Install CHN ROUTE VPN for CentOS and Ubuntu
#   Author: bazingaterry
#   thanks to teddysun/shadowsocks_install & quericy/one-key-ikev2-vpn shell script
#    thanks to strongswan project and shadowsocks project
#===============================================================================================

clear
echo "#############################################################"
echo "# Install CHN ROUTE VPN for CentOS6.x (32bit/64bit) or Ubuntu"
echo "#"
echo "# Author : bazingaterry"
echo "#"
echo "#############################################################"
echo ""

function install_CHN_ROUTE_VPN()
{
    rootness
    disable_selinux
    get_my_ip
    get_system
    pre_install
    install_ss_libev
    install_strongswan
    set_iptables
}

# Make sure only root can run our script
function rootness()
{
    if [[ $EUID -ne 0 ]]; then
       echo "Error:This script must be run as root!" 1>&2
       exit 1
    fi
}

# Disable selinux
function disable_selinux()
{
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Get IP address of the server
function get_my_ip()
{
    echo "Preparing, Please wait a moment..."
    IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $IP ]; then
        IP=`curl -s ifconfig.me/ip`
    fi
}

# Ubuntu or CentOS
function get_system()
{
    get_system_str=`cat /etc/issue`
    echo "$get_system_str" |grep -q "CentOS"
    if  [ $? -eq 0 ]
    then
        system_str="0"
    else
        echo "$get_system_str" |grep -q "Ubuntu"
        if [ $? -eq 0 ]
        then
            system_str="1"
        else
            echo "This Script must be running at the CentOS or Ubuntu!"
            exit 1
        fi
    fi  
}

# Pre-installation settings
function pre_install()
{
    echo "please choose the type of your VPS:"
    echo "1) Xen、KVM"
    echo "2) OpenVZ"
    read -p "your choice(1 or 2):" os_choice
    if [ "$os_choice" = "1" ]; then
        os="1"
        os_str="Xen、KVM"
    else
        if [ "$os_choice" = "2" ]; then
            os="2"
            os_str="OpenVZ"
        else
            echo "wrong choice!"
            exit 1
        fi
    fi
    echo ""
    echo "please input the IP of your shadowsocks server:"
    read -p "IP of shadowsocks server:" server
    if [ "$server" = "" ]; then
        exit 1
    fi
    if [ "$os" = "1" ]; then
        echo ""
        echo "Please input name of public network:"
        read -p "(Default eth0):" ethX
        if [ "$ethX" = "" ]; then
            ethX="eth0"
        fi
    fi
    echo ""
    echo "Please input password for shadowsocks:"
    read -p "(Default password: myss):" shadowsockspwd
    if [ "$shadowsockspwd" = "" ]; then
        shadowsockspwd="myss"
    fi
    echo ""
    echo -e "Please input port for shadowsocks:"
    read -p "(Default password: 443):" shadowsocksport
    if [ "$shadowsocksport" = "" ]; then
        shadowsocksport="443"
    fi
    echo ""
    echo -e "Please input method for shadowsocks:"
    read -p "(Default method: chacha20):" shadowsocksmethod
    if [ "$shadowsocksmethod" = "" ]; then
        shadowsocksmethod="chacha20"
    fi
    echo ""
    echo "please input the ip (or domain) of your China VPS:"
    read -p "ip or domain(default_vale:${IP}):" vps_ip
    if [ "$vps_ip" = "" ]; then
        vps_ip=$IP
    fi
    echo ""
    echo "please input the cert country(C):"
    read -p "C(default value:com):" my_cert_c
    if [ "$my_cert_c" = "" ]; then
        my_cert_c="com"
    fi
    echo ""
    echo "please input the cert organization(O):"
    read -p "O(default value:myvpn):" my_cert_o
    if [ "$my_cert_o" = "" ]; then
        my_cert_o="myvpn"
    fi
    echo ""
    echo "please input the cert common name(CN):"
    read -p "CN(default value:VPN CA):" my_cert_cn
    if [ "$my_cert_cn" = "" ]; then
        my_cert_cn="VPN CA"
    fi
    echo ""
    # update necessary lib
    if [ "$system_str" = "0" ]; then
        yum -y update
        yum -y install pam-devel make gcc wget unzip openssl-devel gcc swig 
        yum -y install python python-devel python-setuptools autoconf libtool libevent
        yum -y install automake make curl curl-devel zlib-devel 
        yum -y install perl perl-devel cpio expat-devel gettext-devel
    else
        apt-get -y update
        apt-get -y install libpam0g-dev libssl-dev make gcc wget 
        apt-get -y install unzip curl build-essential autoconf libtool
    fi
    # get Current folder
    cur_dir=`pwd`
    cd $cur_dir
    # add ss config
    if [ ! -d /etc/shadowsocks-libev ];then
        mkdir /etc/shadowsocks-libev
    fi
    cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"${server}",
    "server_port":${shadowsocksport},
    "local_address":"0.0.0.0",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":600,
    "method":"${shadowsocksmethod}"
}
EOF
}

function install_ss_libev()
{
    cd $cur_dir/shadowsocks-libev-master/
    if [ "$system_str" = "0" ]; then
        install_ss_libev_CentOS
    else
        install_ss_libev_Ubuntu
    fi
}

function install_ss_libev_CentOS()
{
    # Build and Install shadowsocks-libev
    if [ -s /usr/local/bin/ss-redir ];then
        echo "shadowsocks-libev has been installed!"
        exit 0
    else
        # download ss
        cd $cur_dir
        if [ -f shadowsocks-libev.zip ];then
            echo "shadowsocks-libev.zip [found]"
        else
            if ! wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/master.zip -O shadowsocks-libev.zip;then
                echo "Failed to download shadowsocks-libev.zip"
                exit 1
            fi
        fi
        unzip shadowsocks-libev.zip
        if [ $? -eq 0 ];then
            echo "Unzip success"
        else
            echo "Unzip shadowsocks-libev failed!"
            exit 1
        fi
        # Download start script
        if ! wget --no-check-certificate https://raw.githubusercontent.com/bazingaterry/CHN_ROUTER_VPN/master/shadowsocks-libev; then
            echo "Failed to download shadowsocks-libev start script!"
            exit 1
        fi
        # compile ss
        cd shadowsocks-libev-master
        ./configure
        make && make install
        if [ $? -eq 0 ]; then
            mv $cur_dir/shadowsocks-libev /etc/init.d/shadowsocks
            chmod +x /etc/init.d/shadowsocks
            # Add run on system start up
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
            # Start shadowsocks
            /etc/init.d/shadowsocks start
            if [ $? -eq 0 ]; then
                echo "Shadowsocks-libev start success!"
            else
                echo "Shadowsocks-libev start failure!"
            fi
        else
            echo ""
            echo "Shadowsocks-libev install failed!"
            exit 1
        fi
    fi
    cd $cur_dir
    # Delete shadowsocks-libev floder
    rm -rf $cur_dir/shadowsocks-libev-master/
    # Delete shadowsocks-libev zip file
    rm -f shadowsocks-libev.zip
    clear
}

function install_ss_libev_Ubuntu()
{
    # Build and Install shadowsocks-libev
    if [ -s /usr/local/bin/ss-redir ];then
        echo "shadowsocks-libev has been installed!"
        exit 0
    else
        # download ss
        if [ -f shadowsocks-libev.zip ];then
            echo "shadowsocks-libev.zip [found]"
        else
            if ! wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/master.zip -O shadowsocks-libev.zip;then
                echo "Failed to download shadowsocks-libev.zip"
                exit 1
            fi
        fi
        unzip shadowsocks-libev.zip
        if [ $? -eq 0 ];then
            echo "Unzip success"
            if ! wget --no-check-certificate https://raw.githubusercontent.com/bazingaterry/CHN_ROUTER_VPN/master/shadowsocks-libev-ubuntu; then
                echo "Failed to download shadowsocks-libev start script!"
                exit 1
            fi
        else
            echo "Unzip shadowsocks-libev failed!"
            exit 1
        fi
        # compile ss
        ./configure
        make && make install
        if [ $? -eq 0 ]; then
            # Add run on system start up
            mv $cur_dir/shadowsocks-libev-ubuntu /etc/init.d/shadowsocks
            chmod +x /etc/init.d/shadowsocks
            update-rc.d shadowsocks defaults
            # Run shadowsocks in the background
            /etc/init.d/shadowsocks start
            # Run success or not
            if [ $? -eq 0 ]; then
                echo "Shadowsocks-libev start success!"
            else
                echo "Shadowsocks-libev start failure!"
            fi
        else
            echo ""
            echo "Shadowsocks-libev install failed!"
            exit 1
        fi
    fi
    cd $cur_dir
    # Delete shadowsocks-libev floder
    rm -rf $cur_dir/shadowsocks-libev-master/
    # Delete shadowsocks-libev zip file
    rm -f shadowsocks-libev.zip
    clear
}

install_strongswan()
{
    if [ "$system_str" = "0" ]; then
        install_strongswan_CentOS
    else
        install_strongswan_Ubuntu
    fi
}

function install_strongswan_CentOS()
{
    yum install strongswan -y
    cat > /etc/strongswan/ipsec.conf<<-EOF
config setup
    uniqueids=never 

conn iOS_cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add

EOF

# configure the strongswan.conf
cat > /etc/strongswan/strongswan.conf<<-EOF
 charon {
        load_modular = yes
        duplicheck.enable = no
        compress = yes
        plugins {
                include strongswan.d/charon/*.conf
        }
        dns1 = 115.28.26.197
        dns2 = 203.195.236.79
        nbns1 = 8.8.8.8
        nbns2 = 8.8.4.4
}
include strongswan.d/*.conf
EOF

# configure the ipsec.secrets
    cat > /etc/strongswan/ipsec.secrets<<-EOF
: RSA server.pem
: PSK "myPSKkey"
: XAUTH "myXAUTHPass"
myUserName %any : EAP "myUserPass"
EOF

    chkconfig strongswan on
    service strongswan start
}

function install_strongswan_Ubuntu()
{
    #download strongswan
    if [ -f strongswan.tar.gz ];then
        echo -e "strongswan.tar.gz [\033[32;1mfound\033[0m]"
    else
        if ! wget http://download.strongswan.org/strongswan.tar.gz;then
            echo "Failed to download strongswan.tar.gz"
            exit 1
        fi
    fi
    tar xzf strongswan.tar.gz
    if [ $? -eq 0 ];then
        echo "unzip succeess"
    else
        echo "Unzip strongswan.tar.gz failed!"
        exit 1
    fi
    #compile strongswan
    cd $cur_dir/strongswan-*/
    if [ "$os" = "1" ]; then
        ./configure  --enable-eap-identity --enable-eap-md5 \
--enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  \
--enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap  \
--enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity  \
--enable-certexpire --enable-radattr --enable-tools --enable-openssl --disable-gmp

    else
        ./configure  --enable-eap-identity --enable-eap-md5 \
--enable-eap-mschapv2 --enable-eap-tls --enable-eap-ttls --enable-eap-peap  \
--enable-eap-tnc --enable-eap-dynamic --enable-eap-radius --enable-xauth-eap  \
--enable-xauth-pam  --enable-dhcp  --enable-openssl  --enable-addrblock --enable-unity  \
--enable-certexpire --enable-radattr --enable-tools --enable-openssl --disable-gmp --enable-kernel-libipsec

    fi
    make; make install

    #set key
    cd $cur_dir
    if [ -f ca.pem ];then
        echo -e "ca.pem [\033[32;1mfound\033[0m]"
    else
        echo -e "ca.pem [\033[32;1mauto create\032[0m]"
        echo "auto create ca.pem ..."
        ipsec pki --gen --outform pem > ca.pem
    fi
    
    if [ -f ca.cert.pem ];then
        echo -e "ca.cert.pem [\033[32;1mfound\033[0m]"
    else
        echo -e "ca.cert.pem [\032[33;1mauto create\032[0m]"
        echo "auto create ca.cert.pem ..."
        ipsec pki --self --in ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${my_cert_cn}" --ca --outform pem >ca.cert.pem
    fi
    if [ ! -d my_key ];then
        mkdir my_key
    fi
    mv ca.pem my_key/ca.pem
    mv ca.cert.pem my_key/ca.cert.pem
    cd my_key
    ipsec pki --gen --outform pem > server.pem  
    ipsec pki --pub --in server.pem | ipsec pki --issue --cacert ca.cert.pem \
--cakey ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=${vps_ip}" \
--san="${vps_ip}" --flag serverAuth --flag ikeIntermediate \
--outform pem > server.cert.pem
    ipsec pki --gen --outform pem > client.pem  
    ipsec pki --pub --in client.pem | ipsec pki --issue --cacert ca.cert.pem --cakey ca.pem --dn "C=${my_cert_c}, O=${my_cert_o}, CN=VPN Client" --outform pem > client.cert.pem
    echo "configure the pkcs12 cert password(Can be empty):"
    openssl pkcs12 -export -inkey client.pem -in client.cert.pem -name "client" -certfile ca.cert.pem -caname "${my_cert_cn}"  -out client.cert.p12
    cp -r ca.cert.pem /usr/local/etc/ipsec.d/cacerts/
    cp -r server.cert.pem /usr/local/etc/ipsec.d/certs/
    cp -r server.pem /usr/local/etc/ipsec.d/private/
    cp -r client.cert.pem /usr/local/etc/ipsec.d/certs/
    cp -r client.pem  /usr/local/etc/ipsec.d/private/
    
    #configure the ipsec.conf
    cat > /usr/local/etc/ipsec.conf<<-EOF
config setup
    uniqueids=never 

conn iOS_cert
    keyexchange=ikev1
    fragmentation=yes
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn android_xauth_psk
    keyexchange=ikev1
    left=%defaultroute
    leftauth=psk
    leftsubnet=0.0.0.0/0
    right=%any
    rightauth=psk
    rightauth2=xauth
    rightsourceip=10.31.2.0/24
    auto=add

conn networkmanager-strongswan
    keyexchange=ikev2
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=pubkey
    rightsourceip=10.31.2.0/24
    rightcert=client.cert.pem
    auto=add

conn windows7
    keyexchange=ikev2
    ike=aes256-sha1-modp1024!
    rekey=no
    left=%defaultroute
    leftauth=pubkey
    leftsubnet=0.0.0.0/0
    leftcert=server.cert.pem
    right=%any
    rightauth=eap-mschapv2
    rightsourceip=10.31.2.0/24
    rightsendcert=never
    eap_identity=%any
    auto=add

EOF

# configure the strongswan.conf
cat > /usr/local/etc/strongswan.conf<<-EOF
 charon {
        load_modular = yes
        duplicheck.enable = no
        compress = yes
        plugins {
                include strongswan.d/charon/*.conf
        }
        dns1 = 115.28.26.197
        dns2 = 203.195.236.79
        nbns1 = 8.8.8.8
        nbns2 = 8.8.4.4
}
include strongswan.d/*.conf
EOF

# configure the ipsec.secrets
    cat > /usr/local/etc/ipsec.secrets<<-EOF
: RSA server.pem
: PSK "myPSKkey"
: XAUTH "myXAUTHPass"
myUserName %any : EAP "myUserPass"
EOF

    ipsec start
}

function set_iptables()
{
    # set ss iptables
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT

    # set strongswan
    sysctl -w net.ipv4.ip_forward=1
    if [ "$os" = "1" ]; then
        iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -s 10.31.0.0/24  -j ACCEPT
        iptables -A FORWARD -s 10.31.1.0/24  -j ACCEPT
        iptables -A FORWARD -s 10.31.2.0/24  -j ACCEPT
        iptables -A INPUT -i $ethX -p esp -j ACCEPT
        iptables -A INPUT -i $ethX -p udp --dport 500 -j ACCEPT
        iptables -A INPUT -i $ethX -p tcp --dport 500 -j ACCEPT
        iptables -A INPUT -i $ethX -p udp --dport 4500 -j ACCEPT
        iptables -A INPUT -i $ethX -p udp --dport 1701 -j ACCEPT
        iptables -A INPUT -i $ethX -p tcp --dport 1723 -j ACCEPT
        iptables -A FORWARD -j REJECT
        iptables -t nat -A POSTROUTING -s 10.31.0.0/24 -o $ethX -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 10.31.1.0/24 -o $ethX -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o $ethX -j MASQUERADE
    else
        iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -s 10.31.0.0/24  -j ACCEPT
        iptables -A FORWARD -s 10.31.1.0/24  -j ACCEPT
        iptables -A FORWARD -s 10.31.2.0/24  -j ACCEPT
        iptables -A INPUT -i venet0 -p esp -j ACCEPT
        iptables -A INPUT -i venet0 -p udp --dport 500 -j ACCEPT
        iptables -A INPUT -i venet0 -p tcp --dport 500 -j ACCEPT
        iptables -A INPUT -i venet0 -p udp --dport 4500 -j ACCEPT
        iptables -A INPUT -i venet0 -p udp --dport 1701 -j ACCEPT
        iptables -A INPUT -i venet0 -p tcp --dport 1723 -j ACCEPT
        iptables -A FORWARD -j REJECT
        iptables -t nat -A POSTROUTING -s 10.31.0.0/24 -o venet0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 10.31.1.0/24 -o venet0 -j MASQUERADE
        iptables -t nat -A POSTROUTING -s 10.31.2.0/24 -o venet0 -j MASQUERADE
    fi

    # set chn route
    iptables -t nat -N SHADOWSOCKS
    iptables -t nat -N SHADOWSOCKS
    iptables -t nat -A SHADOWSOCKS -d $server -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A SHADOWSOCKS -d 240.0.0.0/4 -j RETURN

    wget -O- 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | awk -F\| '/CN\|ipv4/ { printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > $cur_dir/ignore.list

    while read -r line
    do
       sudo iptables -t nat -A SHADOWSOCKS -d $line -j RETURN
    done < $cur_dir/ignore.list

    iptables -t nat -A SHADOWSOCKS -p tcp -j REDIRECT --to-ports 1080
    iptables -t nat -A OUTPUT -p tcp -j SHADOWSOCKS
    iptables -t nat -A PREROUTING -p tcp -j SHADOWSOCKS

    # save iptables
    if [ "$system_str" = "0" ]; then
        service iptables save
    else
        iptables-save > /etc/iptables.rules
        cat > /etc/network/if-up.d/iptables<<EOF
#!/bin/sh
iptables-restore < /etc/iptables.rules
EOF
        chmod +x /etc/network/if-up.d/iptables
    fi
}

install_CHN_ROUTE_VPN
