#!/bin/bash
set -exuo pipefail

VAGRANT_PROVISION=/var/vagrant/provision

if [ ! -d ${VAGRANT_PROVISION} ];then
  sudo timedatectl set-timezone Asia/Tokyo
  sudo apt-get update -y
  sudo apt-get upgrade -y
  mkdir -p ${VAGRANT_PROVISION}
fi

if [ ! -f ${VAGRANT_PROVISION}/snapd ];then
  sudo apt-get install -y snapd
  touch ${VAGRANT_PROVISION}/snapd  
fi