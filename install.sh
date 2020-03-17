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
apt install wget snapd ssl-cert debconf-utils -y

wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list"
apt update

echo "jitsi-meet-web-config	jitsi-meet/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/cert-choice	select	Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections
echo "jicofo	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-prosody	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-videobridge	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-prosody	jitsi-meet-prosody/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections

apt-get install -y jitsi-meet

snap install rocketchat-server
snap set rocketchat-server port=4443
systemctl restart snap.rocketchat-server.rocketchat-server.service
ps ax | grep jitsi | cut -f2 -d" " | xargs kill
systemctl restart snap.rocketchat-server.rocketchat-server.service

cat 1> /etc/nginx/sites-available/rocket-chat.conf <<EOF
server {
    listen 80;
    server_name chat.${IP}.xip.io;
    return 301 https://\$host\$request_uri;
}

server {
    server_name chat.${IP}.xip.io;
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:4443;
    }
}
EOF

ln -sf /etc/nginx/sites-available/rocket-chat.conf /etc/nginx/sites-enabled/rocket-chat.conf
nginx -s reload

