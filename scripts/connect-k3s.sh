#!/bin/bash
BASTION_IP="56.228.3.177"
K3S_MASTER_IP="10.0.3.53"

echo "Setting up K3s access..."
mkdir -p ~/.kube
scp -i modules/compute/keys/rss-key.pem ec2-user@$BASTION_IP:~/.kube/config ~/.kube/config-k3s
sed "s/$K3S_MASTER_IP/127.0.0.1/" ~/.kube/config-k3s > ~/.kube/config

echo "Starting SSH tunnel with metrics support (keep this running)..."
ssh -i modules/compute/keys/rss-key.pem \
  -L 6443:$K3S_MASTER_IP:6443 \
  -L 10250:$K3S_MASTER_IP:10250 \
  ec2-user@$BASTION_IP -N
