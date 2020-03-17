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
apt install wget git snapd ssl-cert debconf-utils -y

snap install rocketchat-server
snap set rocketchat-server port=4443
systemctl restart snap.rocketchat-server.rocketchat-server.service

wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list"
apt update

secret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
authpass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
jvbsecret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
vidsecret=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)

echo "jitsi-meet-prosody	jicofo/jicofosecret	password	${secret}" | debconf-set-selections
echo "jitsi-meet-prosody	jicofo/jicofo-authpassword	password	${authpass}" | debconf-set-selections
echo "jitsi-meet-prosody	jitsi-videobridge/jvbsecret	password	${jvbsecret}" | debconf-set-selections
echo "jitsi-videobridge	jitsi-videobridge/jvbsecret	password	${vidsecret}" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/cert-path-crt	string" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/cert-choice	select	Generate a new self-signed certificate (You will later get a chance to obtain a Let's encrypt certificate)" | debconf-set-selections
echo "jitsi-meet-prosody	jicofo/jicofo-authuser	string	focus" | debconf-set-selections
echo "jicofo	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-prosody	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-videobridge	jitsi-videobridge/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/jvb-serve	boolean	false" | debconf-set-selections
echo "jitsi-meet-web-config	jitsi-meet/cert-path-key	string" | debconf-set-selections
echo "jitsi-meet-prosody	jitsi-meet-prosody/jvb-hostname	string	meet.${IP}.xip.io" | debconf-set-selections

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

