#!/bin/bash

echo "Hello Terraform! `date`"

hostnamectl set-hostname freyja

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

wget https://www.internic.net/domain/named.root -qO- > /var/lib/unbound/root.hints

echo 'server:
    log-queries: yes
    log-replies: yes
    root-hints: "/var/lib/unbound/root.hints"
    interface: 0.0.0.0
    harden-dnssec-stripped: yes

    private-address: 172.18.0.0/16
    private-address: 172.17.0.0/16
    private-address: 10.2.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10

    access-control: 127.0.0.1/32 allow_snoop
    access-control: ::1 allow_snoop
    access-control: 127.0.0.0/8 allow
    access-control: 172.18.0.0/24 allow_snoop
    access-control: 172.17.0.0/24 allow_snoop' > /etc/unbound/unbound.conf.d/odin.conf

systemctl restart unbound

echo '[Resolve]
DNSStubListener=no
DNS=127.0.0.1' > /etc/systemd/resolved.conf

systemctl  restart systemd-resolved.service

rm -f /etc/resolv.conf
echo 'nameserver 127.0.0.1
search .' > /etc/resolv.conf

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

echo '1 * * * * docker system prune -f
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
