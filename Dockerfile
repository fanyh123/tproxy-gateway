FROM arm64v8/alpine

RUN ["cross-build-start"]

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
    apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add curl bash iptables pcre openssl dnsmasq ipset iproute2 && \
    sed -i 's/mirrors.aliyun.com/dl-cdn.alpinelinux.org/g' /etc/apk/repositories

COPY iplist.txt chnroute.txt  /tmp

RUN cd /tmp && \
	wget https://raw.githubusercontent.com/wxlg1117/ss-tun2socks/master/chinadns/chinadns.arm64 && \
	mv chinadns.arm64 chinadns && \
	wget https://raw.githubusercontent.com/wxlg1117/ss-tun2socks/master/dnsforwarder/dnsforwarder.arm64 && \
	mv dnsforwarder.arm64 dnsforwarder && \
	install -c /tmp/chinadns /usr/local/bin && \
	install -c -m 644 /tmp/iplist.txt /tmp/chnroute.txt /usr/local/share && \
	install -c /tmp/dnsforwarder /usr/local/bin && \
	rm -rf /tmp/*

RUN mkdir -p /v2ray && \
    cd /v2ray && \
    wget https://raw.githubusercontent.com/v2ray/dist/master/v2ray-linux-arm64.zip && \
    unzip v2ray-linux-arm64.zip && \
    rm config.json v2ray-linux-arm64.zip && \
    chmod +x v2ray v2ctl

RUN cd / && mkdir -p /ss-tproxy &&\
	wget https://github.com/zfl9/ss-tproxy/archive/v3-master.zip && \
	unzip -jd ss-tproxy v3-master.zip && rm v3-master.zip && \
	install -c /ss-tproxy/ss-tproxy /usr/local/bin && \
	mkdir -m 0755 -p /etc/ss-tproxy && chown -R root:root /etc/ss-tproxy && \
	install -c /ss-tproxy/ss-tproxy.conf /ss-tproxy/gfwlist.* /ss-tproxy/chnroute.* /etc/ss-tproxy

RUN mkdir -p /koolproxy && cd /koolproxy && \
	wget https://koolproxy.com/downloads/arm && \
	mv arm koolproxy && \
	chmod +x koolproxy && \
	./koolproxy --cert && \
	chown -R daemon:daemon /koolproxy

RUN ["cross-build-end"]
ENTRYPOINT ["/usr/local/bin/ss-tproxy start"]
