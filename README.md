# CHN_Router_VPN

## 架构

Client <—VPN—> China VPS <—Shadowsocks—>America VPS

## 优点

1. 兼容性好，VPN干扰严重但大部分设备都支持，SS稳定但移动设备体验不够好。
2. 国内VPS中转，可选择出口线路优质的VPS，提高出口速度。
3. 可在国内VPS根据国内外IP地址分流，提高访问速度，节省流量。

## 注意事项

1. 只支持CentOS和Ubuntu。CentOS会有小概率编译Strongswan失败，所以使用yum安装。Ubuntu会编译安装最新版，耗时会稍长。
2. 有些VPS网卡eth0是内网，eth1才是公网，例如阿里云，注意修改。
3. VPN的DNS需要使用国内无污染的DNS，脚本中提供的无污染DNS不保证长期有效。

## 参考项目

[teddysun](https://github.com/teddysun)/[**shadowsocks_install**](https://github.com/teddysun/shadowsocks_install/)

[quericy](https://github.com/quericy)/[**one-key-ikev2-vpn**](https://github.com/quericy/one-key-ikev2-vpn)