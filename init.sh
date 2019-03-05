#!/bin/bash

CONFIG_PATH='/etc/ss-tproxy'
NEED_EXIT=0
[ ! -f "$CONFIG_PATH"/ss-tproxy.conf ] && { cp /sample_config/ss-tproxy.conf "$CONFIG_PATH"; echo "[ERR] No ss-tproxy.conf, sample file copied, please configure it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/v2ray.conf ] && { cp /sample_config/v2ray.conf "$CONFIG_PATH"; echo "[ERR] no v2ray.conf, sample file copied, please configure it."  1>&2; NEED_EXIT=1; }
[ ! -f "$CONFIG_PATH"/gfwlist.ext ] && { cp /sample_config/gfwlist.ext "$CONFIG_PATH"; }
if [ "$NEED_EXIT" = 1 ]; then
  exit 1;
fi

source "$CONFIG_PATH"/ss-tproxy.conf
[ ! -f "$file_gfwlist_txt"  ] && touch $file_gfwlist_txt
[ ! -f "$file_chnroute_txt"  ] && touch $file_chnroute_txt
[ ! -f "$file_chnroute_set"  ] && touch $file_chnroute_set
[ ! -f "$dnsmasq_addn_hosts"  ] && touch $dnsmasq_addn_hosts

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
kill -9 $(pidof crond) &>/dev/null
grep -n '^[^#]*/init.sh' /etc/crontabs/root && crond
echo "`date +%Y-%m-%d\ %T` staring tproxy-gateway.."
/usr/local/bin/ss-tproxy restart && \
echo -e "IPv4 gateway & dns server: \n`ip addr show eth0 |grep 'inet ' | awk '{print $2}' |sed 's/\/.*//g'`" && \
echo -e "IPv6 dns server: \n`ip addr show eth0 |grep 'inet6 ' | awk '{print $2}' |sed 's/\/.*//g'`"
if [ "$1" = daemon ]; then
  tail -f /dev/null
fi