#!/bin/bash
if [ "${USER}" != "team-urgence" ]; then
    which sudo >/dev/null && prefix="sudo"
    
    if [ "$USER" != "root" ]; then
        groups | grep sudo >/dev/null
        if [ "$?" != "0" ]; then
            echo "You user isn't in sudo group"
            echo "Please add that user in sudo group with an administator account"
            echo "with the command: usermod -aG sudo $USER"
            exit 1
        fi
    fi

    [ ${USER} == "root" ] && prefix=""
    echo -e "\E[031mPLEASE, NOTE THAT IMPORTANT INFORMATION\E[0m"
    cat <<EOF
This script is a simple automation to install meet.jit.si and mattermost
on a server in urgence mode. That means that:
- you will use the domain name "xip.io" (e.g. meet.your.ip.address.xip.xio)
- certificates are not validate, so the users will need to accept default certificate

It will install docker and docker-compose if they are not already installed.
It will write configuration for nginx in /etc/nginx/sites-available/
It will create a user named team-urgence that will be in "docker" group
to launch mattermost and meet.jit.si

I'm not responsible on you server and how you use the script !

In the next futre, the author of that easy script will provide you a new script that will
help you to change you domain name and use let's encrypt to have a valid certificate.

Keep informed on https://github.com/metal3d/team-urgence

Enjoy !
Press any key to continue, or CTRL+C to cancel...
EOF

    read

    exit
    $prefix apt update
    $prefix apt install sudo
    $prefix useradd -m -s /bin/bash team-urgence
    $prefix usermod -aG sudo team-urgence
    $prefix cp team-urgence.sh /home/team-urgence/team-urgence.sh
    $prefix chown team-urgence /home/team-urgence/team-urgence.sh
    # and create a password for that user:
    # with a strong password
    echo "Give a password for team-urgene user please:"
    $prefix passwd team-urgence
    exec sudo -u team-urgence bash -c "bash /home/team-urgence/team-urgence.sh"
fi

_PUBLICIP=$(wget -qO- http://whatismyip.akamai.com/)
_PRIVATEIP=$(ip r get 1 | grep -Po '(\d+.){4}' | tail -n1)


echo "Choose how to connect your services:"
echo "1 - With private IP, only users in you local network via xxx.${_PRIVATEIP}.xip.io"
echo "2 - With public IP, users can see your services on internet via xxx.${_PUBLICIP}.xip.io"

RESP="-"
while [ "$RESP" != '1' ] && [ "$RESP" != '2' ]; do
    echo -n "Choose 1 or 2: "
    read -a RESP
done

case $RESP in
    1)
        IP=${_PRIVATEIP}
        ;;
    2)
        IP=${_PUBLICIP}
        ;;
esac

echo "After installation, you will be able to connect:"
echo "https://meet.${IP}.xip.io to make visioconference"
echo "http://chat.${IP}.xip.io to chat with team, exchange files..."
for i in in {1..10}; do
    printf "\rYou have 10s to cancel by pressing CTRL+C: %1d " "$((10-i))"
    sleep 1
done
echo

cd $HOME
sudo apt update
sudo apt install ssl-cert git nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

# install docker
which docker
if [ "$?" != 0 ]; then
	wget -O- https://get.docker.com | bash -
fi
groups | grep docker || sudo usermod -aG docker ${USER}
newgrp docker

# install docker-compose
which docker-compose
if [ "$?" != 0 ]; then
	wget https://github.com/docker/compose/releases/download/1.26.0-rc3/docker-compose-Linux-x86_64
	sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
	sudo chmod +x /usr/local/bin/docker-compose
fi

# install mattermost
git clone https://github.com/mattermost/mattermost-docker.git
cd mattermost-docker
docker-compose build
mkdir -pv ./volumes/app/mattermost/{data,logs,config,plugins,client-plugins}
sudo chown -R 2000:2000 ./volumes/app/mattermost/
cat 1> docker-compose.yml <<EOF
version: "3"

services:
  db:
    build: db
    read_only: true
    restart: unless-stopped
    volumes:
      - ./volumes/db/var/lib/postgresql/data:/var/lib/postgresql/data
      - /etc/localtime:/etc/localtime:ro
    environment:
      - POSTGRES_USER=mmuser
      - POSTGRES_PASSWORD=mmuser_password
      - POSTGRES_DB=mattermost
  app:
    build:
      context: app
      args:
        - edition=team
    restart: unless-stopped
    ports:
      - 8000:8000
    volumes:
      - ./volumes/app/mattermost/config:/mattermost/config:rw
      - ./volumes/app/mattermost/data:/mattermost/data:rw
      - ./volumes/app/mattermost/logs:/mattermost/logs:rw
      - ./volumes/app/mattermost/plugins:/mattermost/plugins:rw
      - ./volumes/app/mattermost/client-plugins:/mattermost/client/plugins:rw
      - /etc/localtime:/etc/localtime:ro
    environment:
      - MM_USERNAME=mmuser
      - MM_PASSWORD=mmuser_password
      - MM_DBNAME=mattermost
      - MM_SQLSETTINGS_DATASOURCE=postgres://mmuser:mmuser_password@db:5432/mattermost?sslmode=disable&connect_timeout=10
EOF

docker-compose up -d

cat 1> mattermost.conf <<EOF
map \$http_x_forwarded_proto \$proxy_x_forwarded_proto {
  default \$http_x_forwarded_proto;
  ''       \$scheme;
}


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

    location ~ /api/v[0-9]+/(users/)?websocket$ {
        proxy_set_header Upgrade  \$http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 50M;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$proxy_x_forwarded_proto;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        proxy_read_timeout 600s;
        proxy_pass http://127.0.0.1:8000;
    }

    location / {
        gzip on;
        client_max_body_size 50M;
        proxy_set_header Connection "";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$proxy_x_forwarded_proto;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        proxy_read_timeout 600s;
	proxy_pass http://127.0.0.1:8000;
    }
}
EOF
sudo mv mattermost.conf /etc/nginx/sites-available/mattermost.conf
sudo ln -sf /etc/nginx/sites-available/mattermost.conf /etc/nginx/sites-enabled/mattermost.conf
sudo nginx -s reload


cd $HOME
# now install rocketchat
grep "chat.${IP}.xip.io" /etc/hosts || echo "127.0.0.1 chat.${IP}.xip.io" | sudo tee -a /etc/hosts
git clone https://github.com/jitsi/docker-jitsi-meet
cd docker-jitsi-meet
cp env.example .env
sed -i 's/#DISABLE_HTTPS=1/DISABLE_HTTPS=1/' .env
sed -i 's,#PUBLIC_URL="https://meet.example.com",#PUBLIC_URL="https://meet.'${IP}'.xip.io",' .env
sed -i 's/HTTP_PORT=8000/HTTP_PORT=8080/' .env

mkdir -p ~/.jitsi-meet-cfg/{web/letsencrypt,transcripts,prosody,jicofo,jvb}
docker-compose up -d

cat 1> jitsi.conf <<EOF
server {
    listen 80;
    server_name meet.${IP}.xip.io;
    return 301 https://\$host\$request_uri;
}

server {
    server_name meet.${IP}.xip.io;
    listen 443 ssl;
    ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
	proxy_set_header Host \$http_host;
	proxy_set_header X-Real-IP \$remote_addr;
	proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	proxy_set_header X-Forwarded-Proto \$scheme;
    }

}
EOF

sudo mv jitsi.conf /etc/nginx/sites-available/jitsi.conf
sudo ln -sf /etc/nginx/sites-available/jitsi.conf /etc/nginx/sites-enabled/jitsi.conf
sudo nginx -s reload
sudo gpasswd -d team-urgence sudo

cat <<EOF
You can now visit:
- https://meet.${IP}.xip.io to use meet jitsi for video conferences
- https://chat.${IP}.xip.io to use mattermost and configure your team chat
EOF
