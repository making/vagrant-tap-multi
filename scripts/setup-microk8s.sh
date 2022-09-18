#!/bin/bash
set -exuo pipefail

VAGRANT_PROVISION=/var/vagrant/provision

KUBERNETES_VERSION=1.23
IPADDR=$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)

if [ ! -f ${VAGRANT_PROVISION}/microk8s ];then
  sudo snap install microk8s --classic --channel=${KUBERNETES_VERSION}/stable
  sudo microk8s status --wait-ready
  cat <<EOF | sudo tee /etc/profile.d/microk8s.sh
alias kubectl='microk8s.kubectl'
EOF
  touch ${VAGRANT_PROVISION}/microk8s
fi

if [ ! -f ${VAGRANT_PROVISION}/microk8s-join-group ];then
  sudo usermod -a -G microk8s vagrant
  sudo mkdir -p /home/vagrant/.kube
  sudo chown -f -R vagrant:vagrant /home/vagrant/.kube
  touch ${VAGRANT_PROVISION}/microk8s-join-group  
fi

if [ ! -f ${VAGRANT_PROVISION}/microk8s-config ];then
  sed -i.bak "s/#MOREIPS/IP.3 = ${IPADDR}\nDNS.6 = *.sslip.io\nDNS.7 = *.maki.lol\nDNS.8 = *.ik.am/g" /var/snap/microk8s/current/certs/csr.conf.template
  echo "--advertise-address ${IPADDR}" | sudo tee -a /var/snap/microk8s/current/args/kube-apiserver
  echo "--node-ip ${IPADDR}" | sudo tee -a /var/snap/microk8s/current/args/kubelet
  # echo "--hostname-override ${IPADDR}" | sudo tee -a /var/snap/microk8s/current/args/kubelet
  sudo microk8s refresh-certs --cert ca.crt
  sudo snap restart microk8s
  touch ${VAGRANT_PROVISION}/microk8s-config
fi