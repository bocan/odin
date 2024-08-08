#!/bin/bash

echo "Hello Terraform! `date`"
REGION=eu-west-2
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
SPOT_REQ_ID=$(aws --region $REGION ec2 describe-instances --instance-ids "$INSTANCE_ID"  --query 'Reservations[0].Instances[0].SpotInstanceRequestId' --output text)
if [ "$SPOT_REQ_ID" != "None" ] ; then
  TAGS=$(aws --region $REGION ec2 describe-spot-instance-requests --spot-instance-request-ids "$SPOT_REQ_ID" --query 'SpotInstanceRequests[0].Tags')
  aws --region $REGION ec2 create-tags --resources "$INSTANCE_ID" --tags "$TAGS"
fi
#aws ec2 modify-instance-metadata-options --instance-id $INSTANCE_ID --http-tokens required

systemctl stop docker

while [ ! -e /dev/nvme1n1p1 ]
do
    sleep 5
done
mkdir -p /volume
mount /dev/nvme1n1p1 /volume

dd if=/dev/zero of=/swapfile bs=1G count=2
chmod 0600 /swapfile
mkswap /swapfile

grep -q nvme1n1p1 /etc/fstab
if [ $? != 0 ]
then
  echo " /dev/nvme1n1p1 /volume ext4 rw 0 1
/swapfile      swap    swap defaults 0 0 " >> /etc/fstab
fi
systemctl daemon-reload
swapon -a

apt update
apt install lsb-release gnupg2 apt-transport-https ca-certificates curl software-properties-common wget default-mysql-client rsync cron git fail2ban jq strace pre-commit hugo aspell  -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor > /etc/apt/trusted.gpg.d/debian.gpg
add-apt-repository -y "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian bookworm stable"

mkdir -p /etc/docker
echo '{
  "data-root": "/volume/docker",
  "metrics-addr": "0.0.0.0:9323"
}' > /etc/docker/daemon.json


apt -y install docker.io docker-compose-plugin

sleep 5
systemctl start docker

echo "sudo su -" > ~admin/.profile

echo '*/15 * * * * docker exec --user www-data php /usr/local/bin/php /var/www/chris.funderburg.me/ttrss/update.php --feeds
*/31 * * * * docker exec --user 1000 php /usr/local/bin/php /var/www/chris.funderburg.me/nextcloud/cron.php
*/5 * * * * cd /volume/Websites && git pull && docker run -v $PWD/hugo-funderburg:/src  techstack-hugo  --environment production
*/6 * * * * cd /volume/Websites && git pull && docker run -v $PWD/hugo-cloudcaulron:/src  techstack-hugo  --environment production
' | crontab -

echo '
machine github.com
login ${GITHUB_USER}
password ${GITHUB_TOKEN}

machine api.github.com
login ${GITHUB_USER}
password ${GITHUB_TOKEN}
' > ~/.netrc

echo '
[DEFAULT]
bantime = 24h

# default ban time using special formula, default it is banTime * 1, 2, 4, 8, 16, 32...
bantime.increment = true

ignoreip = 127.0.0.1/8 ::1 5.71.73.237

# "maxretry" is the number of failures before a host get banned.
maxretry = 3

[sshd]

mode   = agressive' > /etc/fail2ban/jail.local

systemctl reload fail2ban


HOME=/root git config --global user.name "Chris Funderburg"
HOME=/root git config --global user.email chris@funderburg.me

echo "Goodbye Terraform! `date`"