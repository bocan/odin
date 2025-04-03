#!/bin/bash

echo "Hello Terraform! `date`"

hostnamectl set-hostname odin

systemctl stop docker

while [ ! -e /dev/sdh1 ]
do
    sleep 5
done
mkdir -p /volume
mount /dev/sdh1 /volume

dd if=/dev/zero of=/swapfile bs=1G count=2
chmod 0600 /swapfile
mkswap /swapfile

grep -q sdh1 /etc/fstab
if [ $? != 0 ]
then
  echo "/dev/sdh1 /volume ext4 rw 0 1
/swapfile      swap    swap defaults 0 0 " >> /etc/fstab
fi

# I'm behind AWS security groups so it handles the main firewalling
# at the moment.  This is just a geoblock at the server level.
# An example script lives at:
# https://gist.github.com/bocan/ff82cbcbdc848aa34ff015e23ed866bf
echo '[Unit]
Description = Firewall Startup Script
After = network.target volume.mount docker.service

[Service]
Type = simple
User = root
ExecStartPre=/bin/sleep 30
ExecStart = /volume/firewall/build

[Install]
WantedBy = multi-user.target' > /etc/systemd/system/firewall.service

systemctl daemon-reload

swapon -a

until host download.docker.com; do echo "waiting for working dns"; sleep 1; done

systemctl enable firewall
systemctl start firewall

mkdir -p /etc/docker
echo '{
  "data-root": "/volume/docker",
  "metrics-addr": "0.0.0.0:9323"
}' > /etc/docker/daemon.json


systemctl start docker

echo "sudo su -" > ~admin/.profile

echo '*/15 * * * * docker exec --user www-data php /usr/local/bin/php /var/www/chris.funderburg.me/ttrss/update.php --feeds
*/31 * * * * docker exec --user 1000 php /usr/local/bin/php /var/www/chris.funderburg.me/nextcloud/cron.php
*/5 * * * * cd /volume/Websites && git pull && docker run -v $PWD/hugo-funderburg:/src bocan/hugo:latest --environment production
*/6 * * * * cd /volume/Websites && git pull && docker run -v $PWD/hugo-cloudcauldron:/src bocan/hugo:latest --environment production
1 * * * * docker system prune -f
0 0 * * * journalctl --vacuum-time=1d
' | crontab -

echo "
machine github.com
login ${GITHUB_USER}
password `aws secretsmanager get-secret-value --region eu-west-2 --secret-id githubToken --query SecretString --output text | jq -r .githubToken`

machine api.github.com
login ${GITHUB_USER}
password `aws secretsmanager get-secret-value --region eu-west-2 --secret-id githubToken --query SecretString --output text | jq -r .githubToken`
" > ~/.netrc

echo '
[DEFAULT]
logtarget = SYSTEMD-JOURNAL
backend = systemd

bantime = 24h

# default ban time using special formula, default it is banTime * 1, 2, 4, 8, 16, 32...
bantime.increment = true

ignoreip = 127.0.0.1/8 ::1 5.71.73.237

# "maxretry" is the number of failures before a host get banned.
maxretry = 3

[sshd]

mode   = agressive

[nginx-botsearch]
enabled = true
logpath = journalctl CONTAINER_NAME=nginx -f -o cat

[nginx-http-auth]
enabled = true
logpath = journalctl CONTAINER_NAME=nginx -f -o cat

[nginx-bad-request]
enabled = true
logpath = journalctl CONTAINER_NAME=nginx -f -o cat

' > /etc/fail2ban/jail.local

systemctl reload fail2ban

HOME=/root git config --global user.name "Chris Funderburg"
HOME=/root git config --global user.email chris@funderburg.me

echo "Goodbye Terraform! `date`"
