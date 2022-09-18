#!/bin/bash
set -exuo pipefail

VAGRANT_PROVISION=/var/vagrant/provision

IPADDR=$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)

if [ ! -f ${VAGRANT_PROVISION}/microk8s-join ];then
  /share/microk8s-add-node
  touch ${VAGRANT_PROVISION}/microk8s-join  
fi