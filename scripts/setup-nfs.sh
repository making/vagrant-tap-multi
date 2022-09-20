#!/bin/bash
set -exuo pipefail

VAGRANT_PROVISION=/var/vagrant/provision

IPADDR=$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)

if [ ! -f ${VAGRANT_PROVISION}/nfs ];then
  sudo apt-get install -y nfs-kernel-server
  sudo mkdir -p /srv/nfs
  sudo chown nobody:nogroup /srv/nfs
  sudo chmod 0777 /srv/nfs
  sudo mv /etc/exports /etc/exports.bak
  echo "/srv/nfs 192.168.56.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports
  sudo systemctl restart nfs-kernel-server
  touch ${VAGRANT_PROVISION}/nfs  
fi