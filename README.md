# CHN_Router_VPN

## 架构

Client <—VPN—> China VPS <—Shadowsocks—>abroad VPS

## 优点

1. 兼容性好，VPN 干扰严重但大部分设备都支持，SS稳定但移动设备体验不够好。
2. 国内 VPS 中转，可选择出口线路优质的VPS，提高出口速度。
3. 可在国内 VPS 根据国内外IP地址分流，提高访问速度，节省流量。

## 注意事项

1. 只支持 CentOS 和 Ubuntu。CentOS 会使用 yum 安装。Ubuntu 会编译安装，耗时会稍长。
2. 有些 VPS 网卡 eth0 是内网，eth1 才是公网，例如阿里云，注意修改。
3. VPN 的 DNS 需要使用国内无污染的 DNS，脚本中提供的无污染 DNS 不保证长期有效。

## 使用方法

``` shell
wget https://raw.githubusercontent.com/bazingaterry/CHN_ROUTER_VPN/master/install.sh
chmod +x install.sh
sudo bash install.sh
```

注意选对VPS类型，填写公网网卡（如 eth0），Shadowsocks 的服务器地址、端口、密码、加密方式，其余可以保持默认值。

修改VPN的帐号密码，CentOS在 `/etc/strongswan/ipsec.secrets`，Ubuntu在 `/usr/local/etc/ipsec.secrets`。

## 参考项目

[teddysun](https://github.com/teddysun)/[**shadowsocks_install**](https://github.com/teddysun/shadowsocks_install/)

[quericy](https://github.com/quericy)/[**one-key-ikev2-vpn**](https://github.com/quericy/one-key-ikev2-vpn)
