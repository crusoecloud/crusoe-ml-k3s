#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update && apt install python3-pip jq -y
pip3 install --no-input flask

priv_ip=`jq ".network_interfaces[0].ips[0].private_ipv4.address" /root/k3-0-main.json | tr -d '"'`
pub_ip=`jq ".network_interfaces[0].ips[0].public_ipv4.address" /root/k3-0-main.json | tr -d '"'`

while [ ! -e "/root/k3-lb-main.json" ]; do echo "Waiting for metadata file to be present..."; sleep 2; done;
lb_host=`jq ".network_interfaces[0].ips[0].public_ipv4.address" /root/k3-lb-main.json | tr -d '"'`

curl -sfL https://get.k3s.io | sh -s - server --cluster-init --write-kubeconfig-mode=654 --tls-san $pub_ip,$lb_host

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

python3 /opt/k3-0-serve-token.py &
