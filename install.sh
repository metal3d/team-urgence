#!/bin/bash

if [ -n "$1" ]; then
	IP=$1
fi

if [ -z $IP ]; then
	echo "You must set IP environment variable"
	echo "e.g. export IP=1.2.3.4"
	exit 1
fi

if [ $(id -u) != "0" ]; then
    echo "Restart with root user"
    exec sudo bash $0 $IP
fi

apt update
apt install wget git snapd ssl-cert -y

snap install rocketchat-server

wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list"
apt update

apt -y install jitsi-meet

cat 1> /etc/nginx/sites-available/jitsi.conf <<EOF
server {
    listen 80;
    server_name jitsi.${IP}.xip.io;
    return 301 https://$host$request_uri;
}

server {
    server_name jitsi.${IP}.xip.io;
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:4443;
    }
}
EOF

nginx -s reload

