# Tanzu Application Platform on microk8s on Vagrant

```
brew install vagrant virtualbox virtualbox-extension-pack
# or
sudo apt install -y virtualbox virtualbox-ext-pack vagrant
```


```
vagrant plugin install vagrant-hosts
```

```
git clone https://github.com/making/vagrant-tap.git
mkdir -p share
rm -f share/microk8s-add-node
vagrant up --provision
```


```
vagrant ssh controlplane-1 -c "microk8s config | sed \"s/10.0.2.15/\$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/)/\"" > kubeconfig
```

```
kubectl get pod -A -owide --kubeconfig kubeconfig
```


```
curl -sL https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml | kubectl apply -f-
curl -sL https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml | kubectl apply -f-
```


```
TANZUNET_USERNAME=...
TANZUNET_PASSWORD=...

kubectl create ns tap-install

tanzu secret registry add tap-registry \
  --username "${TANZUNET_USERNAME}" \
  --password "${TANZUNET_PASSWORD}" \
  --server registry.tanzu.vmware.com \
  --export-to-all-namespaces \
  --yes \
  --namespace tap-install

tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.2.2 \
  --namespace tap-install
```

```
ENVOY_IP=$(vagrant ssh controlplane-1 -c "ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/" | awk -F '.' '{print $1 "." $2 "." $3}').240
mkdir -p overlays
cat <<EOF > overlays/contour-loadbalancer-ip.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"kind": "Service", "metadata": {"name": "envoy"}})
---
spec:
  #@overlay/match missing_ok=True
  loadBalancerIP: ${ENVOY_IP}
EOF


cat <<EOF > overlays/cnrs-default-tls.yml                                                                                                                                                                                                                          
#@ load("@ytt:data", "data")
#@ load("@ytt:overlay", "overlay")
#@ namespace = data.values.ingress.external.namespace
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cnrs-selfsigned-issuer
  namespace: #@ namespace
spec:
  selfSigned: { }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cnrs-ca
  namespace: #@ namespace
spec:
  commonName: cnrs-ca
  isCA: true
  issuerRef:
    kind: Issuer
    name: cnrs-selfsigned-issuer
  secretName: cnrs-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: cnrs-ca-issuer
  namespace: #@ namespace
spec:
  ca:
    secretName: cnrs-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: cnrs-default-tls
  namespace: #@ namespace
spec:
  dnsNames:
  - #@ "*.{}".format(data.values.domain_name)
  issuerRef:
    kind: Issuer
    name: cnrs-ca-issuer
  secretName: cnrs-default-tls
---
apiVersion: projectcontour.io/v1
kind: TLSCertificateDelegation
metadata:
  name: contour-delegation
  namespace: #@ namespace
spec:
  delegations:
  - secretName: cnrs-default-tls
    targetNamespaces:
    - "*"
#@overlay/match by=overlay.subset({"metadata":{"name":"config-network"}, "kind": "ConfigMap"})
---
data:
  #@overlay/match missing_ok=True
  default-external-scheme: https
EOF

cat <<EOF > overlays/cnrs-slim.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"namespace":"knative-eventing"}}), expects="1+"
#@overlay/remove
---
#@overlay/match by=overlay.subset({"metadata":{"namespace":"knative-sources"}}), expects="1+"
#@overlay/remove
---
#@overlay/match by=overlay.subset({"metadata":{"namespace":"triggermesh"}}), expects="1+"
#@overlay/remove
---
#@overlay/match by=overlay.subset({"metadata":{"namespace":"vmware-sources"}}), expects="1+"
#@overlay/remove
---
EOF


cat <<EOF > overlays/metadata-store-ingress-tls.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"name":"metadata-store-ingress"}, "kind": "HTTPProxy"})
---
spec:
  virtualhost:
    tls:
      secretName: tanzu-system-ingress/cnrs-default-tls
#@overlay/match by=overlay.subset({"metadata":{"name":"ingress-cert"}, "kind": "Certificate"})
#@overlay/remove
---
EOF
```


```
cat <<'EOF' > create-repository-secret.sh
#!/bin/bash
REGISTRY_SERVER=$1
REGUSTRY_USERNAME=$2
REGUSTRY_PASSWORD=$3
cat <<SCRIPT | kubectl apply -f -
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
EOF
chmod +x create-repository-secret.sh
```

```
GITHUB_USERNAME=...
GITHUB_API_TOKEN=...

DOMAIN_NAME=$(echo ${ENVOY_IP} | sed 's/\./-/g').sslip.io

cat <<EOF > tap-values.yml
profile: full

ceip_policy_disclosed: true

cnrs:
  domain_name: ${DOMAIN_NAME}  
  domain_template: "{{.Name}}-{{.Namespace}}.{{.Domain}}"
  default_tls_secret: tanzu-system-ingress/cnrs-default-tls
  provider: local

buildservice:
  kp_default_repository: ghcr.io/${GITHUB_USERNAME}/build-service
  kp_default_repository_secret:
    name: repository-secret
    namespace: tap-install  

supply_chain: basic

ootb_supply_chain_basic:
  registry:
    server: ghcr.io
    repository: ${GITHUB_USERNAME}/supply-chain
  gitops:
    ssh_secret: git-ssh

contour:
  infrastructure_provider: azure
  envoy:
    service:
      type: LoadBalancer

tap_gui:
  ingressEnabled: true
  ingressDomain: ${DOMAIN_NAME} 
  service_type: ClusterIP
  tls:
    secretName: cnrs-default-tls
    namespace: tanzu-system-ingress
  app_config:
    app:
      baseUrl: https://tap-gui.${DOMAIN_NAME}
    backend:
      baseUrl: https://tap-gui.${DOMAIN_NAME}
      cors:
        origin: https://tap-gui.${DOMAIN_NAME}
    catalog:
      locations:
      - type: url
        target: https://github.com/sample-accelerators/tanzu-java-web-app/blob/main/catalog/catalog-info.yaml
      - type: url
        target: https://github.com/sample-accelerators/spring-petclinic/blob/accelerator/catalog/catalog-info.yaml
      - type: url
        target: https://github.com/tanzu-japan/spring-music/blob/tanzu/catalog/catalog-info.yaml

accelerator:
  domain: ${DOMAIN_NAME}  
  ingress:
    include: true
    enable_tls: true
  tls:
    secret_name: cnrs-default-tls
    namespace: tanzu-system-ingress
  server:
    service_type: ClusterIP

metadata_store:
  app_service_type: ClusterIP
  ingress_enabled: "true"
  ingress_domain: ${DOMAIN_NAME}

scanning:
  metadataStore:
    url: "" # Disable embedded integration since it's deprecated

package_overlays:
- name: contour
  secrets:
  - name: contour-loadbalancer-ip
- name: cnrs
  secrets:
  - name: cnrs-default-tls
  - name: cnrs-slim
- name: metadata-store
  secrets:
  - name: metadata-store-ingress-tls

excluded_packages:
- grype.scanning.apps.tanzu.vmware.com
- learningcenter.tanzu.vmware.com
- workshops.learningcenter.tanzu.vmware.com
- api-portal.tanzu.vmware.com
- sso.apps.tanzu.vmware.com
EOF

./create-repository-secret.sh ghcr.io ${GITHUB_USERNAME} ${GITHUB_API_TOKEN}
```

```
kubectl -n tap-install create secret generic contour-loadbalancer-ip \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/contour-loadbalancer-ip.yml \
  | kubectl apply -f-

kubectl -n tap-install create secret generic cnrs-default-tls \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/cnrs-default-tls.yml \
  | kubectl apply -f-

kubectl -n tap-install create secret generic cnrs-slim \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/cnrs-slim.yml \
  | kubectl apply -f-

kubectl -n tap-install create secret generic metadata-store-ingress-tls \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/metadata-store-ingress-tls.yml \
  | kubectl apply -f-
```

```
tanzu package install tap \
  -p tap.tanzu.vmware.com \
  -v 1.2.2 \
  --values-file tap-values.yml \
  -n tap-install \
  --wait=false
```

```
while [ "$(kubectl -n tap-install get app tap -o=jsonpath='{.status.friendlyDescription}')" != "Reconcile succeeded" ];do
  date
  kubectl get app -n tap-install
  echo "---------------------------------------------------------------------"
  sleep 30
done
echo "✅ Install succeeded"
```