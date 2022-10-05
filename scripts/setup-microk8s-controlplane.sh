#!/bin/bash
set -exuo pipefail

CP_NAME=$1
VAGRANT_PROVISION=/var/vagrant/provision

IPADDR=$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)

if [ ! -f /share/microk8s-add-node-${CP_NAME} ];then
  microk8s add-node --token-ttl 3600 | grep ${IPADDR} | tee /tmp/microk8s-add-node
  echo "$(cat /tmp/microk8s-add-node) --worker --skip-verify" | tee /share/microk8s-add-node-${CP_NAME}
  chmod +x /share/microk8s-add-node-${CP_NAME}
fi

if [ ! -f ${VAGRANT_PROVISION}/microk8s-addons ];then
  sudo microk8s enable helm3
  sudo microk8s enable rbac
  sudo microk8s enable dns
  sudo microk8s enable metrics-server
  N=$(echo $CP_NAME | sed 's/controlplane-//')
  sudo microk8s enable metallb:$(echo $IPADDR | awk -F '.' '{print $1 "." $2 "." $3}').$(echo $((N * 10 + 210)))-$(echo $IPADDR | awk -F '.' '{print $1 "." $2 "." $3}').$(echo $((N * 10 + 219)))
  touch ${VAGRANT_PROVISION}/microk8s-addons
fi


if [ ! -f ${VAGRANT_PROVISION}/microk8s-nfs ];then
  sudo microk8s helm3 repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
  sudo microk8s helm3 repo update
  sudo microk8s helm3 install csi-driver-nfs csi-driver-nfs/csi-driver-nfs \
      --namespace kube-system \
      --set kubeletDir=/var/snap/microk8s/common/var/lib/kubelet
  cat <<EOF | sudo microk8s kubectl apply -f-
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-csi
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  
provisioner: nfs.csi.k8s.io
parameters:
  server: nfs
  share: /srv/nfs
reclaimPolicy: Delete
volumeBindingMode: Immediate
mountOptions:
- hard
- nfsvers=4.1
EOF
  touch ${VAGRANT_PROVISION}/microk8s-nfs      
fi
