#!/bin/bash

ss_tproxy_config='/etc/ss-tproxy/ss-tproxy.conf'
[ ! -f "$ss_tproxy_config"  ] && { echo "[ERR] No such file or directory: '$ss_tproxy_config'"  1>&2; exit 1;} || source "$ss_tproxy_config"
touch /etc/ss-tproxy/gfwlist.txt
touch /etc/ss-tproxy/gfwlist.ext
touch /etc/ss-tproxy/chnroute.txt
touch /etc/ss-tproxy/chnroute.set
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
echo "`date +%Y-%m-%d\ %T` staring tproxy-gateway.."
/usr/local/bin/ss-tproxy restart && tail -f /dev/null
