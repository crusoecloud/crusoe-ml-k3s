#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt update && apt install jq -y

host=`jq ".network_interfaces[0].ips[0].private_ipv4.address" /root/k3-0-main.json | tr -d '"'`

desired_status_code=200
url="http://$host:5500/k3-server-token" 
timeout=60

while ! curl -s --output /dev/null --head --fail --max-time $timeout $url; do :; done

k3_token=$(curl -s $url)

curl -sfL https://get.k3s.io | K3S_TOKEN=$k3_token sh -s - server --cluster-init --write-kubeconfig-mode=654 \
     --server https://$host:6443

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
