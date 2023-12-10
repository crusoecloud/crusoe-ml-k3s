#!/bin/bash

export DEBIANFRONTEND=noninteractive

apt update && apt upgrade -y
apt install haproxy -y
echo -e "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf

cp /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg

systemctl restart haproxy

