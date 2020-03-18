# team-urgence
Team urgence - temporary install mattermost and meet jitsi.

The usage is pretty simple.

- create a Debian >= 9 server or virtual machine (please create a new machine for that, it's preferable)
- be sure you're not "root", if not, create a standard user that **can use `sudo` command**


Then:
```
# change ip to your own, public or private
export IP=1.2.3.4
wget -qO- http://bit.ly/team-urgence | bash
```

The script will install nginx, docker, and docker-compose if there are not already there. Add your user in docker group.

Then it will pull mattermost and meet jitsi repository.

It will configure both tools and start them.

Finally, it will create 2 nginx configuration to be able to contact:
- https://meet.YOUR_IP.xip.io to make visio conference (like Google meet)
- https://chat.YOUR_IP.xip.io to have a team chat system (like Slack or Microsoft Team)

