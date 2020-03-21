domain=$1

prefix=""

if [ $USER != 'root' ]; then
    prefix="sudo"
    groups | grep sudo
    if [ "$?" != "0" ]; then
        echo "Your user is not in sudo group, pleae use root user or a user that have sudo rights."
        exit 1
    fi
fi

if [ "$domain" == "" ]; then
    echo "You need to sepcify a domain name."
    echo "e.g. $0 mydomain.com"
    exit 1
fi


cat <<EOF
This script will help to certify meet.$domain and chat.$domain whit certbot.

Be sure that you have configured DNS with that domain names to point on this server.

Then, press any key to continue, or CTRL+C to cancel.
EOF
read
echo

echo "==> Backup configurationtion if needed"
[ -f /etc/sites-available/rocket-chat.conf.xip ] || $prefix cp /etc/sites-available/rocket-chat.conf /etc/sites-available/rocket-chat.conf.xip
[ -f /etc/sites-available/jitsi-meet.conf.xip ] || $prefix cp /etc/sites-available/jitsi-meet.conf /etc/sites-available/jitsi-meet.conf.xip



echo "==> Installing certbot"
$prefix apt install -y certbot python-certbot-nginx


echo "==> Configure nginx"
cat 1> /tmp/jitsi-meet.conf <<EOF
server {
    server_name meet.$domain;
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

cat 1> /tmp/rocket-chat.conf <<EOF
server {
    server_name chat.$domain;
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;

        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forward-Proto http;
        proxy_set_header X-Nginx-Proxy true;

        proxy_redirect off;
    }
}
EOF

$prefix mv /tmp/jitsi-meet.conf /tmp/rocket-chat.conf /etc/nginx/sites-available/
$prefix nginx -s reload

echo "==> Reloading rocket.chat with new configuration."
$prefix sed -i 's,ROOT_URL=.*,ROOT_URL=https://chat.'$domain',' /opt/docker-rocket-chat/docker-compose.yml
sudo -u team-urgence bash -c "cd /opt/docker-rocket-chat && docker-compose restart rocketchat"

cat <<EOF
==> We will now try to certify your domain

Please, check that http://meet.$domain and http://chat.$domain respond to port 80 before to continue.
If it's not the case, please hit CTRL+C now and try to launch this script again when the domain name is correctly set up.
Certbot will ask you for email, and wich domains to certify, please select meet.$domain and chat.$domain domains.
Then, when certbot ask for redirection from 80 to 443 (http to https), say yes !
Ready ? Enter to continue or CTRL+C to cancel
EOF

read
echo

$prefix certbot --nginx

echo "Done ! On Debian, the system will renew the certificate before it expires."
echo "You can now use https://meet.$domain and https://chat.$domain - congratulations !"
