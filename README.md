# 说明
v2ray版ss-tproxy项目的docker，加入koolproxy，实现docker中的透明网关及广告过滤，目前有`x86_64`及`aarch64`两个版本，`aarch64`适用于PHICOMM N1。
# 快速开始
```bash
# 配置文件目录
mkdir -p ~/docker/tproxy-gateway
echo "0       2       *       *       *       /init.sh" > ~/docker/tproxy-gateway/crontab

# 下载gfwlist.ext黑名单文件
wget -p ~/docker/tproxy-gateway https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/gfwlist.ext

# 下载ss-config.conf配置文件
wget -P ~/docker/tproxy-gateway https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/ss-tproxy.conf

# 配置ss-config.conf
vi ~/docker/tproxy-gateway/ss-config.conf

# 下载v2ray.conf配置文件
wget -P ~/docker/tproxy-gateway https://raw.githubusercontent.com/lisaac/tproxy-gateway/master/v2ray.conf 

# 配置v2ray.conf
vi ~/docker/tproxy-gateway/v2ray.conf

# 创建docker network
docker network create -d macvlan \
    --subnet=10.1.1.0/24 --gateway=10.1.1.1 \
    --ipv6 --subnet=fe80::/10 --gateway=fe80::1 \
    -o parent=eth0 \
    -o macvlan_mode=bridge \
    dMACvLan

# 拉取docker镜像
docker pull lisaac/tproxy-gateway:`arch`

# 运行容器
docker run -d --name tproxy-gateway \
    -e TZ=Asia/Shanghai \
    --network dMACvLan --ip 10.1.1.254 \
    --privileged \
    --restart unless-stopped \
    -v $HOME/docker/tproxy-gateway:/etc/ss-tproxy \
    -v $HOME/docker/tproxy-gateway/crontab:/etc/crontabs/root \
    lisaac/tproxy-gateway:`arch`

# 查看网关运行情况
docker logs tproxy-gateway
```
配置客户端网关及DNS

# 配置文件
本容器由ss-tproxy + v2ray 组成，配置文件放至`/to/path/config`，并挂载至容器，主要配置文件为：
```bash
/to/ptah/config
    |- ss-tproxy.conf：配置文件
    |- gfwlist.ext：gfwlsit 黑名单文件，可配置
    |- v2ray.conf: v2ray 配置文件
```

## `ss-tproxy`
[ss-tproxy](https://github.com/zfl9/ss-tproxy)是基于`dnsmasq + ipset`实现的透明代理解决方案。

具体配置方法见[ss-tproxy项目主页](https://github.com/zfl9/ss-tproxy)。

### ss-tproxy.conf 配置文件示例：
```bash
## mode
#mode='global'
mode='gfwlist'
#mode='chnroute'

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
```
## `v2ray`
### v2ray.con配置文件vmess协议(tls+ws)示例:
```json
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
### v2ray配置文件ss协议示例:
```json
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
          "tproxy": "redirect"
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
## `koolproxy`
容器中包含`koolproxy`，需要在`ss-tproxy.conf`最后加入一下脚本，则会随容器启动，若不需要，则删除这段脚本即可：
```bash
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
### 开启 HTTPS 过滤
默认没有启用https过滤，如需要启用https过滤，需要运行:
```bash
docker exec tproxy-gateway /koolproxy/koolproxy --cert -b /etc/ss-proxy/koolproxydata
```
并重启容器，证书文件在宿主机的`/to/path/config/koolproxydata/cert`目录下。

# 运行tproxy-gateway容器
新建docker macvlan网络，配置网络地址为内网lan地址及默认网关:
```bash
docker network create -d macvlan \
    --subnet=10.1.1.0/24 --gateway=10.1.1.1 \
    --ipv6 --subnet=fe80::/10 --gateway=fe80::1 \
    -o parent=eth0 \
    -o macvlan_mode=bridge \
    dMACvLan
```
运行容器:
```bash
docker run -d --name tproxy-gateway \
    -e TZ=Asia/Shanghai \
    --network dMACvLan --ip 10.1.1.254 --ip6 fe80::fe80 \
    --privileged \
    --restart unless-stopped \
    -v /to/path/config:/etc/ss-tproxy \
    -v /to/path/crontab:/etc/crontabs/root \
    lisaac/tproxy-gateway:`arch`
```
 - `--ip 10.1.1.254` 指定容器ipv4地址
 - `--ip6 fe80::fe80 ` 指定容器ipv6地址，如不指定自动分配，建议自动分配。若指定，容器重启后会提示ip地址被占用，只能重启docker服务才能启动，原因未知。
 - `-v /to/path/config:/etc/ss-tproxy` 指定配置文件目录，至少需要ss-tproxy.conf及v2ray.conf
 - `-v /to/path/crontab:/etc/crontabs/root` 指定crontab文件，详情查看规则更新

启动后会自动更新规则，根据网络情况，启动可能有所滞后，可以使用`docker logs tproxy-gateway`查看容器情况。

# 规则自动更新
若在使用中需要更新规则，则只需要重启容器即可：
```
docker restart tproxy-gateway
```

自动更新，更新时会临时断网，需在创建容器时，加入`-v /to/path/crontab:/etc/crontabs/root`参数。
以下为每天2点自动更新的`crontab`示例：
```bash
# do daily/weekly/monthly maintenance
# min   hour    day     month   weekday command
0       2       *       *       *       /init.sh
```

# 设置客户端
设置客户端（或设置路由器DHCP）默认网关及DNS服务器为容器IP:10.1.1.254

以openwrt为例，在`/etc/config/dhcp`中`config dhcp 'lan'`段加入：

```
  list dhcp_option '6,10.1.1.254'
  list dhcp_option '3,10.1.1.254'
```
# 关于IPv6 DNS
使用过程中发现，若启用了IPv6，某些客户端(Android)会自动将DNS服务器地址指向默认网关(路由器)的ipv6地址，导致客户端不走docker中的dns服务器。

解决方案是修改路由器中ipv6的`通告dns服务器`为容器ipv6地址。

以openwrt为例，在`/etc/config/dhcp`中`config dhcp 'lan'`段加入：
```
  list dns 'fe80::fe80'
```

# 关于宿主机出口
由于docker网络采用`macvlan`的`bridge`模式，宿主机虽然与容器在同一网段，但是相互之间是无法通信的，所以无法通过`tproxy-gateway`透明代理。

解决方案1是让宿主机直接走主路由，不经过代理网关：
```bash
ip route add default via 10.1.1.1 dev eth0 # 设置静态路由
echo "nameserver 10.1.1.1" > /etc/resolv.conf # 设置静态dns服务器
```
解决方案2是利用多个macvlan接口之间是互通的原理，新建一个macvlan虚拟接口：
```bash
ip link add link eth0 mac0 type macvlan mode bridge # 在eth0接口下添加一个macvlan虚拟接口
ip addr add 10.1.1.250/24 brd + dev mac0 # 为mac0 分配ip地址
ip link set mac0 up
ip route add default via 10.1.1.254 dev mac0 # 设置静态路由

# ip addr add 10.1.1.250/24 brd + dev eth0 # eth0的ip地址设为静态地址：
# echo "nameserver 10.1.1.254" > /etc/resolv.conf # 设置静态dns服务器
```
ENJOY
