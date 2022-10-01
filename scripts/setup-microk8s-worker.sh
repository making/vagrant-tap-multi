#!/bin/bash
set -exuo pipefail

CP_NAME=$1
VAGRANT_PROVISION=/var/vagrant/provision

IPADDR=$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)

if [ ! -f ${VAGRANT_PROVISION}/microk8s-join ];then
  /share/microk8s-add-node-${CP_NAME}
  touch ${VAGRANT_PROVISION}/microk8s-join  
fi
