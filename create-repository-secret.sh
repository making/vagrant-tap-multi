#!/bin/bash
REGISTRY_SERVER=$1
REGUSTRY_USERNAME=$2
REGUSTRY_PASSWORD=$3
KUBECONFIG=$4
cat <<SCRIPT | kubectl apply -f - --kubeconfig ${KUBECONFIG}
apiVersion: v1
kind: Secret
metadata:
  name: repository-secret
  namespace: tap-install
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "${REGISTRY_SERVER}": {
          "username": "${REGUSTRY_USERNAME}",
          "password": "${REGUSTRY_PASSWORD}"
        }
      }
    }
SCRIPT
