### 说明
v2ray版ss-tproxy项目的docker，加入koolproxy，实现docker中的透明网关及广告过滤，目前为aarch64版本，用于PHICOMM N1。
### 快速开始
```
mkdir -p ~/docker/tproxy-gateway
echo "0       2       *       *       *       /init.sh" > ~/docker/tproxy-gateway/crontab
wget -p ~/docker/tproxy-gateway https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf
# 编辑ss-config.conf

wget -p ~/docker/tproxy-gateway https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf
# 编辑v2ray.conf

docker network create -d macvlan --subnet=10.1.1.0/24 --gateway=10.1.1.1 -o parent=eth0 dMACvLan
docker pull lisaac/tproxy-gateway
docker run -d --name tproxy-gateway \
    -e TZ=Asia/Shanghai \
    --network dMACvLan --ip 10.1.1.254 \
    --privileged \
    restart unless-stopped \
    -v $HOME/docker/tproxy-gateway:/etc/ss-tproxy \
    -v $HOME/docker/tproxy-gateway/crontab:/etc/crontabs/root \
    lisaac/tproxy-gateway
```
#### ss-tproxy
[ss-tproxy](https://github.com/zfl9/ss-tproxy)是基于`dnsmasq + ipset`实现的透明代理解决方案。
将配置好的ss-tproxy配置文件存放至/to/ptah/config：
```
ss-tproxy.conf：配置文件
gfwlist.txt：gfwlist 域名文件，不可配置
gfwlist.ext：gfwlsit 黑名单文件，可配置
chnroute.set：chnroute for ipset，不可配置
chnroute.txt：chnroute for chinadns，不可配置
```
具体配置方法见[ss-tproxy项目主页](https://github.com/zfl9/ss-tproxy)
#### ss-tproxy.conf 配置文件示例：
```
## mode
#mode='global'
#mode='gfwlist'
mode='chnroute'

## proxy
proxy_tproxy='true'   # 纯TPROXY方式
proxy_server=(xx.xx.xx)   # 服务器的地址
proxy_dports=''        # 服务器的端口
proxy_tcport='60080'   # TCP 监听端口
proxy_udport='60080'   # UDP 监听端口
proxy_runcmd='/v2ray/v2ray -config /etc/ss-tproxy/v2ray.conf > /dev/null 2>&1 &'  # 启动的命令行
proxy_kilcmd='killall v2ray'  # 停止的命令行

## dnsmasq
dnsmasq_cache_size='10240'              # DNS 缓存条目
dnsmasq_cache_time='3600'               # DNS 缓存时间
dnsmasq_log_enable='false'              # 是否记录日志
dnsmasq_log_file='/var/log/dnsmasq.log' # 日志文件路径

## chinadns
chinadns_mutation='false'                # DNS 压缩指针
chinadns_verbose='false'                 # 记录详细日志
chinadns_logfile='/var/log/chinadns.log' # 日志文件路径

## dns
dns_modify='true'           # 直接修改 resolv.conf,建议为ture
dns_remote='8.8.8.8:53'      # 国外 DNS，必须指定端口
dns_direct='114.114.114.114' # 国内 DNS，不能指定端口

## ipts
ipts_rt_tab='100'              # iproute2 路由表名或 ID
ipts_rt_mark='0x2333'          # iproute2 策略路由的标记
ipts_non_snat='true'          # 不设置 SNAT iptables 规则
ipts_intranet=(10.0.0.0/8 192.168.0.0/16) # 内网网段，多个请用空格隔开

## opts
opts_ss_netstat="auto"  # 'auto|ss|netstat'，使用哪个端口检测命令

## file
file_gfwlist_txt='/etc/ss-tproxy/gfwlist.txt'   # gfwlist 黑名单文件 (默认规则)
file_gfwlist_ext='/etc/ss-tproxy/gfwlist.ext'   # gfwlist 黑名单文件 (扩展规则)
file_chnroute_txt='/etc/ss-tproxy/chnroute.txt' # chnroute 地址段文件 (chinadns)
file_chnroute_set='/etc/ss-tproxy/chnroute.set' # chnroute 地址段文件 (iptables)

## Koolproxy
function post_start {
    mkdir -p /etc/ss-tproxy/koolproxydata
    chown -R daemon:daemon /etc/ss-tproxy/koolproxydata
    su -s/bin/sh -c'/koolproxy/koolproxy -d -l2 -p65080 -b/etc/ss-tproxy/koolproxydata' daemon
    if [ "$proxy_tproxy" = 'true' ]; then
        iptables -t mangle -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j RETURN
        iptables -t nat    -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        for intranet in "${ipts_intranet[@]}"; do
            iptables -t mangle -I SSTP_PRE -m mark ! --mark $ipts_rt_mark -p tcp -m multiport --dports 80,443 -s $intranet ! -d $intranet -j RETURN
            iptables -t nat    -I SSTP_PRE -m mark ! --mark $ipts_rt_mark -p tcp -m multiport --dports 80,443 -s $intranet ! -d $intranet -j REDIRECT --to-ports 65080
        done
    else
        iptables -t nat -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        for intranet in "${ipts_intranet[@]}"; do
            iptables -t nat -I SSTP_PRE -s $intranet ! -d $intranet -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        done
    fi
}

function post_stop {
    kill -9 $(pidof koolproxy) &>/dev/null
}
```
#### v2ray：
请将v2ray配置文件命名为`v2ray.conf`存放至`ss-tproxy`配置目录（启动docker时配置的`/to/path/config`）
##### vmess协议配置文件示例:
```
{
  "log": {
    "access": "/var/log/v2ray-access.log",
    "error": "/var/log/v2ray-error.log",
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "listen": "0.0.0.0",
      "port": 60080,
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "tproxy": "tproxy"
      }
    }
  ],

  "outbound": {
    "tag": "agentout",
    "protocol": "vmess",
    "settings": {
      "vnext": [
        {
          "address": "xx.xx.xx",
          "port": 443,
          "users": [
            {
              "id": "xxxxxxxxxxxxxxxxxxx",
              "alterId": 64,
              "email": "xxxxx",
              "security": "auto"
            }
          ]
        }
      ],
      "servers": null
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "tlsSettings": {
        "allowInsecure": true,
        "serverName": null
      },
      "tcpSettings": null,
      "kcpSettings": null,
      "wsSettings": {
        "connectionReuse": true,
        "path": "/path",
        "headers": null
      },
      "httpSettings": null
    },
    "mux": {
      "enabled": false
    }
  }
}
```
##### ss协议配置文件示例:
```
{
  "log": {
    "access": "/var/log/v2ray-access.log",
    "error": "/var/log/v2ray-error.log",
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "protocol": "dokodemo-door",
      "listen": "0.0.0.0",
      "port": 60080,
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          # "tproxy": "tproxy" # tproxy + tproxy
          "tproxy": "redirect" # redirect + tproxy
        }
      }
    }
  ],

  "outbounds": [
    {
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "xx.xx.xx",
            "port": xxx,
            "method": "aes-128-gcm",
            "password": "xxxxxxx"
          }
        ]
      }
    }
  ]
}
```
#### koolproxy:
容器中包含koolproxy，默认没有启动，需要在`/to/path/config/ss-tproxy.conf`最后加入：
```
function post_start {
    mkdir -p /etc/ss-tproxy/koolproxydata
    chown -R daemon:daemon /etc/ss-tproxy/koolproxydata
    su -s/bin/sh -c'/koolproxy/koolproxy -d -l2 -p65080 -b/etc/ss-proxy/koolproxydata' daemon
    if [ "$proxy_tproxy" = 'true' ]; then
        iptables -t mangle -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j RETURN
        iptables -t nat    -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        for intranet in "${ipts_intranet[@]}"; do
            iptables -t mangle -I SSTP_PRE -m mark ! --mark $ipts_rt_mark -p tcp -m multiport --dports 80,443 -s $intranet ! -d $intranet -j RETURN
            iptables -t nat    -I SSTP_PRE -m mark ! --mark $ipts_rt_mark -p tcp -m multiport --dports 80,443 -s $intranet ! -d $intranet -j REDIRECT --to-ports 65080
        done
    else
        iptables -t nat -I SSTP_OUT -m owner ! --uid-owner daemon -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        for intranet in "${ipts_intranet[@]}"; do
            iptables -t nat -I SSTP_PRE -s $intranet ! -d $intranet -p tcp -m multiport --dports 80,443 -j REDIRECT --to-ports 65080
        done
    fi
}

function post_stop {
    kill -9 $(pidof koolproxy) &>/dev/null
}
```
默认没有启用https过滤，如需要启用https过滤，需要运行:
```docker exec tproxy-gateway /koolproxy/koolproxy --cert -b /etc/ss-proxy/koolproxydata```
并重启dokcer即可，证书文件在/etc/ss-proxy/koolproxydata/cert目录下

### 运行tproxy-gateway
新建docker macvlan网络，网络地址为内网lan地址及默认网关:
```
docker network create -d macvlan --subnet=10.1.1.0/24 --gateway=10.1.1.1 -o parent=eth0 dMACvLan
```
运行容器:
```
docker run -d --name tproxy-gateway \
    -e TZ=Asia/Shanghai \
    --network dMACvLan --ip 10.1.1.254 \
    --privileged \
    restart unless-stopped \
    -v /to/path/config:/etc/ss-tproxy \
    -v /to/path/crontab:/etc/crontabs/root \
    lisaac/tproxy-gateway
```
 - `--ip 10.1.1.254` 指定容器的地址
 - `-v /to/path/config:/etc/ss-tproxy` 指定配置文件目录，至少需要ss-tproxy.conf及v2ray.conf
 - `-v /to/path/crontab:/etc/crontabs/root` 指定crontab文件，详情查看规则更新
启动后会自动更新规则，根据网络情况，启动可能有所滞后，可以使用`docker logs tproxy-gateway`查看容器情况。

### 规则更新
若在使用中需要更新规则，则只需要重启容器即可：`docker restart tproxy-gateway`。
自动更新，只需要将此命令行加入系统crontab中即可。

另外容器中也包含了自动更新的钩子，在创建容器时，加入`-v /to/path/crontab:/etc/crontabs/root`参数。
以下为每天2点自动更新的crontab示例：
```
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
0       2       *       *       *       /init.sh

```

### 设置客户端
设置客户端（或设置路由器DHCP）默认网关及DNS服务器为容器IP:10.1.1.254
#### 关于IPv6 DNS
使用过程中发现，若有ipv6分配，Android端会自动分配ipv6默认网关(主路由)为dns服务器地址，导致不走docker中的dns服务器，解决方案为将主路由的dnsmasq的上游DNS指向容器(tproxy-gateway)。
将主路由的`dnsmasq.conf`中加入：
```
no-resolv
```
在主路由的`dnsmasq.servers`中加入：
```
server=10.1.1.254
server=114.114.114.114
```
重启dnsmasq。

ENJOY
