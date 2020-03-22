# team-urgence
Team urgence - temporary install rocket.chat and meet.jitsi.

**This script is made to work on a server or a virtual machine, standard AMD64 (x86_64) CPUs.**

**ARM CPUs are not supported for the moment.**

The usage is pretty simple.

- create a Debian >= 9 server or virtual machine (please create a new machine for that, it's preferable)
- be sure to have root access or a shell with a user that can use "sudo" command

Then:
```
wget -qO- http://bit.ly/team-urgence > team-urgence.sh && bash team-urgence.sh
```

The script will install nginx, docker, and docker-compose if there are not already there.
Then it will create a "team-urgence" user that will be in docker group.

Then it will pull rocket.chat and meet.jitsi docker repository in `/opt`.

It will configure both tools and start them.

Finally, it will create 2 nginx configuration to be able to contact:
- https://meet.YOUR-IP.xip.io to make visio conference (like Google meet)
- https://chat.YOUR-IP.xip.io to have a team chat system (like Slack or Microsoft Team)

Note that you'll need to create your administator account on rocket.chat instance, and potentially change visio conference settings
if you want to use the one you've installed.

**You need to finish installation on your rocket-chat installation, to create admin account, and use "hidden url" to invite users and to not use email verification**

**We've got a problem with Room name in meet jitsi, you should create roomname without space or special char**

# What is installed:

Packages and docker files:
- nginx and sudo packages
- docker-ce if it's not installed
- official docker-compose from Docker project (if docker-compose is not found on your system)
- a user named team-urgence with docker rights (no sudo)
- `/opt/docker-rocket-chat` and `/opt/docker-jitsi-meet` directories

And configuration for nginx here:
- `/etc/nginx/sites-enabled/rocket-chat.conf`
- `/etc/nginx/sites-available/rocket-chat.conf`
- `/etc/nginx/sites-enabled/jitsi-meet.conf`
- `/etc/nginx/sites-available/jitsi-meet.conf`

Exposed port are 80 and 443 by nginx => should need to be accessible by users to contact services.


# Let's encrypt certification

You need to have a domain name that is configure to point on your server. e.g. mydomain.com

**Warning** this script will rewrite rocket.chat and meet.jitsi nginx configuration.

The certification script makes backup here:

- `/etc/nginx/sites-available/rocket-chat.conf.xip`
- `/etc/nginx/sites-available/jitsi-meet.conf.xip`

Type:

```
# change mydomain.com by your own name
# without "meet." or "chat."
MYDOMAIN=mydomain.com
wget -qO- https://bit.ly/team-urgence-cert > certify.sh && bash certify.sh $MYDOMAIN
```

The script will:

- install `certbot`
- rewrite nginx configuration to bind meet.yourdomain.com and chat.yourdomain.com
- certify your domain with let's encrypt

On Debian, a cronjob will renew certificates before they expire.

**Important** You'll need to go in administation panel in your rocket.chat instance to change the old URL to your new one. Without that, invite code will not be corrected !

The site URL is in Administration ¬ General panel (in administation panel, you can type "URL" in search field). Change the old xip URL to `https://chat.yourdomain` (replace `yourdomain` by your own domain name).

# Uninstall

Type this:

```
sudo rm -f /etc/nginx/sites-enabled/rocket-chat.conf
sudo rm -f /etc/nginx/sites-available/rocket-chat.conf
sudo rm -f /etc/nginx/sites-enabled/jitsi-meet.conf
sudo rm -f /etc/nginx/sites-available/jitsi-meet.conf
sudo nginx -s reload

sudo rm -f /etc/nginx/sites-available/rocket-chat.conf.xip
sudo rm -f /etc/nginx/sites-available/jitsi-meet.conf.xip

# important to remove docker volumes
sudo -u team-urgence bash -c "cd /opt/docker-jitsi-meet/ && docker-compose down -v"
sudo -u team-urgence bash -c "cd /opt/docker-rocket-chat && docker-compose down -v"

sudo rm -rf /opt/docker-jitsi-meet /opt/docker-rocket-chat
```

# CentOS ? Fedora ?

Coming soon.

