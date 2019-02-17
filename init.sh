#!/bin/bash

CONFIG_PATH='/etc/ss-tproxy'
touch /etc/ss-tproxy/gfwlist.txt
touch /etc/ss-tproxy/chnroute.txt
touch /etc/ss-tproxy/chnroute.set
NEED_EXIT=0
[ ! -f "$CONFIG_PATH"/ss-tproxy.conf ] && { cp /copy_config/ss-tproxy.conf "$CONFIG_PATH"; echo "[ERR] No ss-tproxy.conf, sample file copied, please config it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/v2ray.conf ] && { cp /copy_config/v2ray.conf "$CONFIG_PATH"; echo "[ERR] no v2ray.conf, sample file copied, please config it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/gfwlist.ext ] && { cp /copy_config/gfwlist.ext "$CONFIG_PATH"; }
[ "$NEED_EXIT" = 1 ] && { exit 1; }
source "$CONFIG_PATH"/ss-tproxy.conf
if [ "$mode" = chnroute ]; then
  echo "`date +%Y-%m-%d\ %T` updating chnroute.."
  /usr/local/bin/ss-tproxy update-chnroute
fi
if [ "$mode" = gfwlist ]; then
  echo "`date +%Y-%m-%d\ %T` updating gfwlist.."
  /usr/local/bin/ss-tproxy update-gfwlist
fi
if [ "$mode" = chnonly ]; then
  echo "`date +%Y-%m-%d\ %T` updating chnonly.."
  /usr/local/bin/ss-tproxy update-chnonly
fi
echo "`date +%Y-%m-%d\ %T` flushing iptables.."
/usr/local/bin/ss-tproxy flush-iptables
echo "`date +%Y-%m-%d\ %T` flushing gfwlist.."
/usr/local/bin/ss-tproxy flush-gfwlist
echo "`date +%Y-%m-%d\ %T` flushing dnscache.."
/usr/local/bin/ss-tproxy flush-dnscache
killall crond
grep -n '^[^#]*/init.sh' /etc/crontabs/root && crond
echo "`date +%Y-%m-%d\ %T` staring tproxy-gateway.."
/usr/local/bin/ss-tproxy restart && \
echo -e "IPv4 gateway & dns server: \n`ip addr show eth0 |grep 'inet ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
echo -e "IPv6 dns server: \n`ip addr show eth0 |grep 'inet6 ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
tail -f /dev/null
