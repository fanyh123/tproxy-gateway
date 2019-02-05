### 说明
v2ray版ss-tproxy项目的docker，加入koolproxy，实现docker中的透明网关及广告过滤，目前为aarch64版本，用于PHICOMM N1。
#### ss-tproxy
[ss-tproxy](https://github.com/zfl9/ss-tproxy)是基于dnsmasq + ipset实现的透明代理解决方案。
将配置好的ss-tproxy配置文件存放至/to/ptah/config：
```
ss-tproxy.conf：配置文件
gfwlist.txt：gfwlist 域名文件，不可配置
gfwlist.ext：gfwlsit 黑名单文件，可配置
chnroute.set：chnroute for ipset，不可配置
chnroute.txt：chnroute for chinadns，不可配置
```
具体配置方法见ss-proxy项目主页
#### v2ray：
请将v2ray配置文件命名为v2ray.conf存放至ss-tproxy配置目录（启动docker时配置的/to/path/config）
##### vmess协议配置文件示例:
```
{
  "log": {
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
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
              "security": "aes-128-gcm"
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
    "access": "/var/log/v2ray/access.log",
    "error": "/var/log/v2ray/error.log",
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
          //"tproxy": "tproxy" // tproxy + tproxy
          "tproxy": "redirect" // redirect + tproxy
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
##### koolproxy
容器中包含koolproxy，默认没有启动，需要在/to/path/config/ss-tproxy.conf最后加入：
```
function post_start {
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
    --network dMACvLan --ip 10.1.1.254\
    --privileged \
    -v /to/path/config:/etc/ss-tproxy \
    lisaac/tproxy-gateway
```

### 设置客户端
设置客户端（或设置路由器DHCP）默认网关及DNS服务器为容器IP:10.1.1.254

ENJOY
