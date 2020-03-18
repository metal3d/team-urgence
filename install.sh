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
apt install ssl-cert -y

wget -qO - https://download.jitsi.org/jitsi-key.gpg.key | sudo apt-key add -
sh -c "echo 'deb https://download.jitsi.org stable/' > /etc/apt/sources.list.d/jitsi-stable.list"
apt update
apt install -y jitsi-meet

## install rocket chat

apt-get install -y dirmngr
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
echo "deb http://repo.mongodb.org/apt/debian stretch/mongodb-org/4.0 main" | tee /etc/apt/sources.list.d/mongodb-org-4.0.list
sudo apt update
sudo apt-get install -y curl
curl -sL https://deb.nodesource.com/setup_12.x | sudo bash -
apt install -y build-essential mongodb-org nodejs graphicsmagick
npm install -g inherits n
n 12.14.0
curl -L https://releases.rocket.chat/latest/download -o /tmp/rocket.chat.tgz
tar -xzf /tmp/rocket.chat.tgz -C /tmp
cd /tmp/bundle/programs/server && npm install
mv /tmp/bundle /opt/Rocket.Chat
useradd -M rocketchat
usermod -L rocketchat
chown -R rocketchat:rocketchat /opt/Rocket.Chat

# configure nginx for rocket chat

cat << EOF | tee -a /lib/systemd/system/rocketchat.service
[Unit]
Description=The Rocket.Chat server
After=network.target remote-fs.target nss-lookup.target nginx.target mongod.target
[Service]
ExecStart=/usr/local/bin/node /opt/Rocket.Chat/main.js
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=rocketchat
User=rocketchat
Environment=MONGO_URL=mongodb://localhost:27017/rocketchat?replicaSet=rs01 MONGO_OPLOG_URL=mongodb://localhost:27017/local?replicaSet=rs01 ROOT_URL=http://localhost:3000/ PORT=3000
[Install]
WantedBy=multi-user.target
EOF

sed -i "s/^#  engine:/  engine: mmapv1/"  /etc/mongod.conf
sed -i "s/^#replication:/replication:\n  replSetName: rs01/" /etc/mongod.conf
systemctl enable mongod
systemctl start mongod

systemctl enable rocketchat
systemctl start rocketchat

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
        proxy_pass http://127.0.0.1:3000;
    }
}
EOF

ln -sf /etc/nginx/sites-available/rocket-chat.conf /etc/nginx/sites-enabled/rocket-chat.conf
nginx -s reload

