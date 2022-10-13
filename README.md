# Tanzu Application Platform on microk8s on Vagrant


## Install Vagrant and VirtualBox


```
brew install vagrant virtualbox virtualbox-extension-pack
# or
sudo apt install -y virtualbox virtualbox-ext-pack vagrant
```

```
vagrant plugin install vagrant-hosts
vagrant plugin install vagrant-disksize
```

## Provision k8s vms


```
git clone https://github.com/making/vagrant-tap.git
mkdir -p share
rm -f share/microk8s-add-node
vagrant up --provision
```

Retrieve k8s configs.

```
vagrant ssh tap-view -c "microk8s config | sed \"s/10.0.2.15/\$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/)/\"" | sed  's/microk8s/tap-view/g' | sed  's/admin/admin-view/g' > kubeconfig-view
vagrant ssh tap-build -c "microk8s config | sed \"s/10.0.2.15/\$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/)/\"" | sed  's/microk8s/tap-build/g' | sed  's/admin/admin-build/g' > kubeconfig-build
vagrant ssh tap-run -c "microk8s config | sed \"s/10.0.2.15/\$(ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/)/\"" | sed  's/microk8s/tap-run/g' | sed  's/admin/admin-run/g'> kubeconfig-run
KUBECONFIG=kubeconfig-run:kubeconfig-build:kubeconfig-view kubectl config view --flatten > kubeconfig
```

Check the node and pod status on each cluster.

```
kubectl get node,pod -A -owide --kubeconfig kubeconfig-view
kubectl get node,pod -A -owide --kubeconfig kubeconfig-build
kubectl get node,pod -A -owide --kubeconfig kubeconfig-run
```

Install kapp-controller and secretgen-controller on each cluster.

```
curl -sL https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-view
curl -sL https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-view
curl -sL https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-build
curl -sL https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-build
curl -sL https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-run
curl -sL https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml | kubectl apply -f- --kubeconfig kubeconfig-run
```

## Create Service Account for TAP GUI in Run/Build cluster


```yaml
mkdir -p tap-gui
cat <<EOF > tap-gui/tap-gui-viewer-service-account-rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
- kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
- apiGroups: ['']
  resources: ['pods', 'pods/log', 'services', 'configmaps']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['apps']
  resources: ['deployments', 'replicasets']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['autoscaling']
  resources: ['horizontalpodautoscalers']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.k8s.io']
  resources: ['ingresses']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.internal.knative.dev']
  resources: ['serverlessservices']
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'autoscaling.internal.knative.dev' ]
  resources: [ 'podautoscalers' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['serving.knative.dev']
  resources:
  - configurations
  - revisions
  - routes
  - services
  verbs: ['get', 'watch', 'list']
- apiGroups: ['carto.run']
  resources:
  - clusterconfigtemplates
  - clusterdeliveries
  - clusterdeploymenttemplates
  - clusterimagetemplates
  - clusterruntemplates
  - clustersourcetemplates
  - clustersupplychains
  - clustertemplates
  - deliverables
  - runnables
  - workloads
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.toolkit.fluxcd.io']
  resources:
  - gitrepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.apps.tanzu.vmware.com']
  resources:
  - imagerepositories
  - mavenartifacts
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.carto.run']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kpack.io']
  resources:
  - images
  - builds
  verbs: ['get', 'watch', 'list']
- apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
- apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  verbs: ['get', 'watch', 'list']
EOF
```

```
kubectl apply -f tap-gui/tap-gui-viewer-service-account-rbac.yaml --kubeconfig kubeconfig-build
kubectl apply -f tap-gui/tap-gui-viewer-service-account-rbac.yaml --kubeconfig kubeconfig-run
```

```
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' --kubeconfig kubeconfig-build > tap-gui/cluster-url-build
kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=jsonpath='{.secrets[0].name}' --kubeconfig kubeconfig-build) --kubeconfig kubeconfig-build -otemplate='{{index .data "token" | base64decode}}' > tap-gui/cluster-token-build
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --kubeconfig kubeconfig-build > tap-gui/cluster-ca-build

kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' --kubeconfig kubeconfig-run > tap-gui/cluster-url-run
kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=jsonpath='{.secrets[0].name}' --kubeconfig kubeconfig-run) --kubeconfig kubeconfig-run -otemplate='{{index .data "token" | base64decode}}' > tap-gui/cluster-token-run
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' --kubeconfig kubeconfig-run > tap-gui/cluster-ca-run
```


## Generate default CA cert

```
mkdir -p certs
rm -f certs/*
docker run --rm -v ${PWD}/certs:/certs hitch openssl req -new -nodes -out /certs/ca.csr -keyout /certs/ca.key -subj "/CN=default-ca/O=TAP/C=JP"
chmod og-rwx ca.key
docker run --rm -v ${PWD}/certs:/certs hitch openssl x509 -req -in /certs/ca.csr -days 3650 -extfile /etc/ssl/openssl.cnf -extensions v3_ca -signkey /certs/ca.key -out /certs/ca.crt
```

## Instll View Cluster


```
TANZUNET_USERNAME=...
TANZUNET_PASSWORD=...

kubectl create ns tap-install --kubeconfig kubeconfig-view

tanzu secret registry add tap-registry \
  --username "${TANZUNET_USERNAME}" \
  --password "${TANZUNET_PASSWORD}" \
  --server registry.tanzu.vmware.com \
  --export-to-all-namespaces \
  --yes \
  --namespace tap-install \
  --kubeconfig kubeconfig-view

tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.3.0 \
  --namespace tap-install \
  --kubeconfig kubeconfig-view
```

```yaml
ENVOY_IP_VIEW=$(vagrant ssh tap-view -c "ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/" | awk -F '.' '{print $1 "." $2 "." $3}').220
DOMAIN_NAME_VIEW=$(echo ${ENVOY_IP_VIEW} | sed 's/\./-/g').sslip.io

mkdir -p overlays/view
cat <<EOF > overlays/view/contour-loadbalancer-ip.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"kind": "Service", "metadata": {"name": "envoy"}})
---
spec:
  #@overlay/match missing_ok=True
  loadBalancerIP: ${ENVOY_IP_VIEW}
EOF


cat <<EOF > overlays/view/contour-default-tls.yml                                                                                                                                                                                                                          
#@ load("@ytt:data", "data")
#@ load("@ytt:overlay", "overlay")
#@ namespace = data.values.namespace
---
apiVersion: v1
kind: Secret
metadata:
  name: default-ca
  namespace: #@ namespace
type: kubernetes.io/tls
stringData:
  tls.crt: |
$(cat certs/ca.crt | sed 's/^/    /g')
  tls.key: |
$(cat certs/ca.key | sed 's/^/    /g')
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: default-ca-issuer
  namespace: #@ namespace
spec:
  ca:
    secretName: default-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tap-default-tls
  namespace: #@ namespace
spec:
  dnsNames:
  - #@ "*.${DOMAIN_NAME_VIEW}"
  issuerRef:
    kind: Issuer
    name: default-ca-issuer
  secretName: tap-default-tls
---
apiVersion: projectcontour.io/v1
kind: TLSCertificateDelegation
metadata:
  name: contour-delegation
  namespace: #@ namespace
spec:
  delegations:
  - secretName: tap-default-tls
    targetNamespaces:
    - "*"
EOF


cat <<'EOF' > overlays/view/tap-gui-db.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"kind":"Deployment","metadata":{"name":"server"}})
---
spec:
  #@overlay/match missing_ok=True
  template:
    spec:
      containers:
      #@overlay/match by="name"
      - name: backstage
        #@overlay/match missing_ok=True
        envFrom:
         - secretRef:
             name: tap-gui-db
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tap-gui-db
  namespace: tap-gui
  labels:
    app.kubernetes.io/part-of: tap-gui-db
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tap-gui-db
  namespace: tap-gui
  labels:
    app.kubernetes.io/part-of: tap-gui-db
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: tap-gui-db
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/part-of: tap-gui-db
    spec:
      initContainers:
      - name: remove-lost-found
        image: busybox
        command:
        - sh
        - -c
        - |
          rm -fr /bitnami/postgresql/data/lost+found
        volumeMounts:
        - name: tap-gui-db
          mountPath: /bitnami/postgresql
      containers:
      - image: bitnami/postgresql:14
        name: postgres
        envFrom:
        - secretRef:
            name: tap-gui-db
        ports:
        - containerPort: 5432
          name: tap-gui-db
        volumeMounts:
        - name: tap-gui-db
          mountPath: /bitnami/postgresql
      volumes:
      - name: tap-gui-db
        persistentVolumeClaim:
          claimName: tap-gui-db
---
apiVersion: v1
kind: Service
metadata:
  name: tap-gui-db
  namespace: tap-gui
  labels:
    app.kubernetes.io/part-of: tap-gui-db
spec:
  ports:
  - port: 5432
  selector:
    app.kubernetes.io/part-of: tap-gui-db
---
apiVersion: secretgen.k14s.io/v1alpha1
kind: Password
metadata:
  name: tap-gui-db
  namespace: tap-gui
  labels:
    app.kubernetes.io/part-of: tap-gui-db
spec:
  secretTemplate:
    type: servicebinding.io/postgresql
    stringData:
      POSTGRES_USER: tap-gui
      POSTGRES_PASSWORD: $(value)
EOF

cat <<EOF > overlays/view/tap-telemetry-remove.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"namespace":"tap-telemetry"}}), expects="1+"
#@overlay/remove
---
EOF
```

```yaml
cat <<EOF > tap-values-view.yml
profile: view

ceip_policy_disclosed: true

shared:
  ingress_domain: ${DOMAIN_NAME_VIEW}

contour:
  infrastructure_provider: "vsphere"
  contour:
    replicas: 1
    configFileContents:
      accesslog-format: json  
  envoy:
    service:
      type: LoadBalancer

tap_gui:
  service_type: ClusterIP
  tls:
    secretName: tap-default-tls
    namespace: tanzu-system-ingress
  app_config:
    app:
      baseUrl: https://tap-gui.${DOMAIN_NAME_VIEW}
    backend:
      baseUrl: https://tap-gui.${DOMAIN_NAME_VIEW}
      cors:
        origin: https://tap-gui.${DOMAIN_NAME_VIEW}
      database:
        client: pg
        connection:
          host: \${TAP_GUI_DB_SERVICE_HOST}
          port: \${TAP_GUI_DB_SERVICE_PORT}
          user: \${POSTGRES_USER}
          password: \${POSTGRES_PASSWORD}
    catalog:
      locations:
      - type: url
        target: https://github.com/sample-accelerators/tanzu-java-web-app/blob/main/catalog/catalog-info.yaml        
    kubernetes:
      serviceLocatorMethod:
        type: multiTenant
      clusterLocatorMethods:
      - type: config
        clusters:
        - url: $(cat tap-gui/cluster-url-run)
          name: run
          authProvider: serviceAccount
          serviceAccountToken: $(cat tap-gui/cluster-token-run)
          skipTLSVerify: false
          caData: $(cat tap-gui/cluster-ca-run)
      - type: config
        clusters:
        - url: $(cat tap-gui/cluster-url-build)
          name: build
          authProvider: serviceAccount
          serviceAccountToken: $(cat tap-gui/cluster-token-build)
          skipTLSVerify: false
          caData: $(cat tap-gui/cluster-ca-build)

appliveview:
  ingressEnabled: true
  tls:
    secretName: tap-default-tls
    namespace: tanzu-system-ingress

accelerator:
  ingress:
    include: true    
    enable_tls: true  
  tls:
    secret_name: tap-default-tls
    namespace: tanzu-system-ingress

package_overlays:
- name: contour
  secrets:
  - name: contour-loadbalancer-ip
  - name: contour-default-tls
- name: tap-gui
  secrets:
  - name: tap-gui-db
- name: tap-telemetry
  secrets:
  - name: tap-telemetry-remove

excluded_packages:
- learningcenter.tanzu.vmware.com
- workshops.learningcenter.tanzu.vmware.com
- api-portal.tanzu.vmware.com
EOF
```

```
kubectl -n tap-install create secret generic contour-loadbalancer-ip \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/view/contour-loadbalancer-ip.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-view

kubectl -n tap-install create secret generic contour-default-tls \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/view/contour-default-tls.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-view

kubectl -n tap-install create secret generic tap-gui-db \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/view/tap-gui-db.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-view

kubectl -n tap-install create secret generic tap-telemetry-remove \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/view/tap-telemetry-remove.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-view
```

```
tanzu package install tap \
  -p tap.tanzu.vmware.com \
  -v 1.3.0 \
  --values-file tap-values-view.yml \
  -n tap-install \
  --kubeconfig kubeconfig-view \
  --wait=false
```

```
while [ "$(kubectl -n tap-install get app tap -o=jsonpath='{.status.friendlyDescription}' --kubeconfig kubeconfig-view)" != "Reconcile succeeded" ];do
  date
  kubectl get app -n tap-install --kubeconfig kubeconfig-view
  echo "---------------------------------------------------------------------"
  sleep 30
done
echo "✅ Install succeeded"
```


```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-view 


  NAME            PACKAGE-NAME                          PACKAGE-VERSION  STATUS               
  tap-telemetry   tap-telemetry.tanzu.vmware.com        0.3.1            Reconcile succeeded  
  appliveview     backend.appliveview.tanzu.vmware.com  1.3.0            Reconcile succeeded  
  cert-manager    cert-manager.tanzu.vmware.com         1.7.2+tap.1      Reconcile succeeded  
  tap-gui         tap-gui.tanzu.vmware.com              1.3.2            Reconcile succeeded  
  contour         contour.tanzu.vmware.com              1.22.0+tap.4     Reconcile succeeded  
  tap             tap.tanzu.vmware.com                  1.3.0            Reconcile succeeded  
  metadata-store  metadata-store.apps.tanzu.vmware.com  1.3.3            Reconcile succeeded  
  accelerator     accelerator.apps.tanzu.vmware.com     1.3.1            Reconcile succeeded  
```

## Instll Build Cluster

```
TANZUNET_USERNAME=...
TANZUNET_PASSWORD=...

kubectl create ns tap-install --kubeconfig kubeconfig-build

tanzu secret registry add tap-registry \
  --username "${TANZUNET_USERNAME}" \
  --password "${TANZUNET_PASSWORD}" \
  --server registry.tanzu.vmware.com \
  --export-to-all-namespaces \
  --yes \
  --namespace tap-install \
  --kubeconfig kubeconfig-build

tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.3.0 \
  --namespace tap-install \
  --kubeconfig kubeconfig-build

tanzu package repository add tbs-full-deps-repository \
  --url registry.tanzu.vmware.com/build-service/full-tbs-deps-package-repo:1.7.1 \
  --namespace tap-install \
  --kubeconfig kubeconfig-build
```


```yaml
cat <<'EOF' > create-repository-secret.sh
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
EOF
chmod +x create-repository-secret.sh
```

```
mkdir -p overlays/build
cat <<EOF > overlays/build/tap-telemetry-remove.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"namespace":"tap-telemetry"}}), expects="1+"
#@overlay/remove
---
EOF
```

```yaml
GITHUB_USERNAME=...
GITHUB_API_TOKEN=...

cat <<EOF > tap-values-build.yml
profile: build

ceip_policy_disclosed: true

buildservice:
  kp_default_repository: ghcr.io/${GITHUB_USERNAME}/build-service
  kp_default_repository_secret:
    name: repository-secret
    namespace: tap-install  
  exclude_dependencies: true

supply_chain: basic

ootb_supply_chain_basic:
  registry:
    server: ghcr.io
    repository: ${GITHUB_USERNAME}/supply-chain
  gitops:
    ssh_secret: ""

scanning:
  metadataStore:
    url: "" # Disable embedded integration since it's deprecated

package_overlays:
- name: tap-telemetry
  secrets:
  - name: tap-telemetry-remove

excluded_packages:
- grype.scanning.apps.tanzu.vmware.com
- contour.tanzu.vmware.com
EOF

./create-repository-secret.sh ghcr.io ${GITHUB_USERNAME} ${GITHUB_API_TOKEN} kubeconfig-build
```

```

kubectl -n tap-install create secret generic tap-telemetry-remove \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/build/tap-telemetry-remove.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-build
```


```
tanzu package install tap \
  -p tap.tanzu.vmware.com \
  -v 1.3.0 \
  --values-file tap-values-build.yml \
  -n tap-install \
  --kubeconfig kubeconfig-build \
  --wait=false

tanzu package install full-tbs-deps \
  -p full-tbs-deps.tanzu.vmware.com \
  -v 1.7.1 \
  -n tap-install \
  --kubeconfig kubeconfig-build \
  --wait=false
```

```
while [ "$(kubectl -n tap-install get app tap -o=jsonpath='{.status.friendlyDescription}' --kubeconfig kubeconfig-build)" != "Reconcile succeeded" ];do
  date
  kubectl get app -n tap-install --kubeconfig kubeconfig-build
  echo "---------------------------------------------------------------------"
  sleep 30
done
echo "✅ Install succeeded"
```

```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-build


  NAME                      PACKAGE-NAME                                  PACKAGE-VERSION  STATUS               
  tap-auth                  tap-auth.tanzu.vmware.com                     1.1.0            Reconcile succeeded  
  tap-telemetry             tap-telemetry.tanzu.vmware.com                0.3.1            Reconcile succeeded  
  appliveview-conventions   conventions.appliveview.tanzu.vmware.com      1.3.0            Reconcile succeeded  
  spring-boot-conventions   spring-boot-conventions.tanzu.vmware.com      0.5.0            Reconcile succeeded  
  tekton-pipelines          tekton.tanzu.vmware.com                       0.39.0+tap.2     Reconcile succeeded  
  ootb-supply-chain-basic   ootb-supply-chain-basic.tanzu.vmware.com      0.10.2           Reconcile succeeded  
  ootb-templates            ootb-templates.tanzu.vmware.com               0.10.2           Reconcile succeeded  
  fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com     0.27.0+tap.1     Reconcile succeeded  
  cartographer              cartographer.tanzu.vmware.com                 0.5.3            Reconcile succeeded  
  scanning                  scanning.apps.tanzu.vmware.com                1.3.0            Reconcile succeeded  
  source-controller         controller.source.apps.tanzu.vmware.com       0.5.0            Reconcile succeeded  
  conventions-controller    controller.conventions.apps.tanzu.vmware.com  0.7.1            Reconcile succeeded  
  full-tbs-deps             full-tbs-deps.tanzu.vmware.com                1.7.1            Reconcile succeeded  
  buildservice              buildservice.tanzu.vmware.com                 1.7.2            Reconcile succeeded  
  tap                       tap.tanzu.vmware.com                          1.3.0            Reconcile succeeded  
  cert-manager              cert-manager.tanzu.vmware.com                 1.7.2+tap.1      Reconcile succeeded 
```


## Instll Run Cluster

```
TANZUNET_USERNAME=...
TANZUNET_PASSWORD=...

kubectl create ns tap-install --kubeconfig kubeconfig-run

tanzu secret registry add tap-registry \
  --username "${TANZUNET_USERNAME}" \
  --password "${TANZUNET_PASSWORD}" \
  --server registry.tanzu.vmware.com \
  --export-to-all-namespaces \
  --yes \
  --namespace tap-install \
  --kubeconfig kubeconfig-run

tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.3.0 \
  --namespace tap-install \
  --kubeconfig kubeconfig-run
```

```yaml
ENVOY_IP_RUN=$(vagrant ssh tap-run -c "ip a show enp0s8 | grep inet | grep -v inet6 | awk '{print \$2}' | cut -f1 -d/" | awk -F '.' '{print $1 "." $2 "." $3}').240
DOMAIN_NAME_RUN=$(echo ${ENVOY_IP_RUN} | sed 's/\./-/g').sslip.io

mkdir -p overlays/run
cat <<EOF > overlays/run/contour-loadbalancer-ip.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"kind": "Service", "metadata": {"name": "envoy"}})
---
spec:
  #@overlay/match missing_ok=True
  loadBalancerIP: ${ENVOY_IP_RUN}
EOF


cat <<EOF > overlays/run/contour-default-tls.yml                                                                                                                                                                                                                          
#@ load("@ytt:data", "data")
#@ load("@ytt:overlay", "overlay")
#@ namespace = data.values.namespace
---
apiVersion: v1
kind: Secret
metadata:
  name: default-ca
  namespace: #@ namespace
type: kubernetes.io/tls
stringData:
  tls.crt: |
$(cat certs/ca.crt | sed 's/^/    /g')
  tls.key: |
$(cat certs/ca.key | sed 's/^/    /g')
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: default-ca-issuer
  namespace: #@ namespace
spec:
  ca:
    secretName: default-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tap-default-tls
  namespace: #@ namespace
spec:
  dnsNames:
  - #@ "*.${DOMAIN_NAME_RUN}"
  issuerRef:
    kind: Issuer
    name: default-ca-issuer
  secretName: tap-default-tls
---
apiVersion: projectcontour.io/v1
kind: TLSCertificateDelegation
metadata:
  name: contour-delegation
  namespace: #@ namespace
spec:
  delegations:
  - secretName: tap-default-tls
    targetNamespaces:
    - "*"
EOF

cat <<EOF > overlays/run/cnrs-https.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"name":"config-network"}, "kind": "ConfigMap"})
---
data:
  #@overlay/match missing_ok=True
  default-external-scheme: https
EOF

cat <<EOF > overlays/run/tap-telemetry-remove.yml
#@ load("@ytt:overlay", "overlay")
#@overlay/match by=overlay.subset({"metadata":{"namespace":"tap-telemetry"}}), expects="1+"
#@overlay/remove
---
EOF
```

```yaml
cat <<EOF > tap-values-run.yml
---
profile: run

ceip_policy_disclosed: true

shared:
  ingress_domain: ${DOMAIN_NAME_RUN}

contour:
  infrastructure_provider: "vsphere"
  contour:
    replicas: 1
    configFileContents:
      accesslog-format: json
  envoy:
    service:
      type: LoadBalancer

cnrs:
  domain_template: "{{.Name}}-{{.Namespace}}.{{.Domain}}"
  default_tls_secret: tanzu-system-ingress/tap-default-tls
  provider: local

supply_chain: basic

appliveview_connector:
  backend:
    ingressEnabled: true
    host: appliveview.${DOMAIN_NAME_VIEW}
    caCertData: |
$(cat certs/ca.crt | sed 's/^/      /g')
api_auto_registration:
  tap_gui_url: https://tap-gui.${DOMAIN_NAME_VIEW}
  cluster_name: run
  ca_cert_data: |
$(cat certs/ca.crt | sed 's/^/    /g')

package_overlays:
- name: contour
  secrets:
  - name: contour-loadbalancer-ip
  - name: contour-default-tls
- name: cnrs
  secrets:
  - name: cnrs-https
- name: tap-telemetry
  secrets:
  - name: tap-telemetry-remove

excluded_packages:
- image-policy-webhook.signing.apps.tanzu.vmware.com
- eventing.tanzu.vmware.com
EOF
```

```
kubectl -n tap-install create secret generic contour-loadbalancer-ip \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/run/contour-loadbalancer-ip.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-run

kubectl -n tap-install create secret generic contour-default-tls \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/run/contour-default-tls.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-run

kubectl -n tap-install create secret generic cnrs-https \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/run/cnrs-https.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-run

kubectl -n tap-install create secret generic tap-telemetry-remove \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/run/tap-telemetry-remove.yml \
  | kubectl apply -f- --kubeconfig kubeconfig-run
```

```
tanzu package install tap \
  -p tap.tanzu.vmware.com \
  -v 1.3.0 \
  --values-file tap-values-run.yml \
  -n tap-install \
  --kubeconfig kubeconfig-run \
  --wait=false
```

```
while [ "$(kubectl -n tap-install get app tap -o=jsonpath='{.status.friendlyDescription}' --kubeconfig kubeconfig-run)" != "Reconcile succeeded" ];do
  date
  kubectl get app -n tap-install --kubeconfig kubeconfig-run
  echo "---------------------------------------------------------------------"
  sleep 30
done
echo "✅ Install succeeded"
```


```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-run 


  NAME                      PACKAGE-NAME                               PACKAGE-VERSION  STATUS               
  ootb-delivery-basic       ootb-delivery-basic.tanzu.vmware.com       0.10.2           Reconcile succeeded  
  tap-telemetry             tap-telemetry.tanzu.vmware.com             0.3.1            Reconcile succeeded  
  tap-auth                  tap-auth.tanzu.vmware.com                  1.1.0            Reconcile succeeded  
  ootb-templates            ootb-templates.tanzu.vmware.com            0.10.2           Reconcile succeeded  
  services-toolkit          services-toolkit.tanzu.vmware.com          0.8.0            Reconcile succeeded  
  service-bindings          service-bindings.labs.vmware.com           0.8.0            Reconcile succeeded  
  source-controller         controller.source.apps.tanzu.vmware.com    0.5.0            Reconcile succeeded  
  cert-manager              cert-manager.tanzu.vmware.com              1.7.2+tap.1      Reconcile succeeded  
  cartographer              cartographer.tanzu.vmware.com              0.5.3            Reconcile succeeded  
  fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com  0.27.0+tap.1     Reconcile succeeded  
  appsso                    sso.apps.tanzu.vmware.com                  2.0.0            Reconcile succeeded  
  policy-controller         policy.apps.tanzu.vmware.com               1.1.2            Reconcile succeeded  
  cnrs                      cnrs.tanzu.vmware.com                      2.0.1            Reconcile succeeded  
  contour                   contour.tanzu.vmware.com                   1.22.0+tap.4     Reconcile succeeded  
  tap                       tap.tanzu.vmware.com                       1.3.0            Reconcile succeeded  
  api-auto-registration     apis.apps.tanzu.vmware.com                 0.1.1            Reconcile succeeded  
  appliveview-connector     connector.appliveview.tanzu.vmware.com     1.3.0            Reconcile succeeded
```

## Deploy a workload

```yaml
cat <<EOF > rbac.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
- name: registry-credentials
imagePullSecrets:
- name: registry-credentials
- name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
- kind: ServiceAccount
  name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
- kind: ServiceAccount
  name: default
EOF
```

```
kubectl create ns demo --kubeconfig kubeconfig-build
kubectl apply -f rbac.yaml -n demo --kubeconfig kubeconfig-build
```

```
tanzu secret registry add registry-credentials --server ghcr.io --username ${GITHUB_USERNAME} --password ${GITHUB_API_TOKEN} --namespace demo --kubeconfig kubeconfig-build
```

```
tanzu apps workload apply tanzu-java-web-app \
  --app tanzu-java-web-app \
  --git-repo https://github.com/sample-accelerators/tanzu-java-web-app \
  --git-branch main \
  --type web \
  --annotation autoscaling.knative.dev/minScale=1 \
  -n demo \
  --kubeconfig kubeconfig-build \
  -y
```

```
tanzu apps workload get tanzu-java-web-app -n demo --kubeconfig kubeconfig-build
```

```
stern -n demo tanzu-java-web-app --kubeconfig kubeconfig-build
# or
tanzu apps workload tail tanzu-java-web-app -n demo --since 1h --kubeconfig kubeconfig-build
```

```
$ tanzu apps workload get tanzu-java-web-app -n demo --kubeconfig kubeconfig-build

---
# tanzu-java-web-app: Ready
---
Source
type:     git
url:      https://github.com/sample-accelerators/tanzu-java-web-app
branch:   main

Supply Chain
name:          source-to-url
last update:   25m
ready:         True

RESOURCE          READY   TIME
source-provider   True    64m
deliverable       True    64m
image-builder     True    27m
config-provider   True    27m
app-config        True    27m
config-writer     True    25m

Issues
No issues reported.

Pods
NAME                                         STATUS      RESTARTS   AGE
tanzu-java-web-app-build-1-build-pod         Succeeded   0          64m
tanzu-java-web-app-config-writer-29qzd-pod   Succeeded   0          27m

To see logs: "tanzu apps workload tail tanzu-java-web-app --namespace demo"
```

```
$ kubectl get workload,deliverable -n demo --kubeconfig kubeconfig-build 
NAME                                    SOURCE                                                      SUPPLYCHAIN     READY   REASON   AGE
workload.carto.run/tanzu-java-web-app   https://github.com/sample-accelerators/tanzu-java-web-app   source-to-url   True    Ready    7h51m

NAME                                       SOURCE                                                                                            DELIVERY   READY   REASON             AGE
deliverable.carto.run/tanzu-java-web-app   ghcr.io/making/supply-chain/tanzu-java-web-app-demo-bundle:6b8251bc-1afb-4875-9b1e-cbcebf62215c              False   DeliveryNotFound   7h51m
```

```
kubectl create ns demo --kubeconfig kubeconfig-run
kubectl apply -f rbac.yaml -n demo --kubeconfig kubeconfig-run
```

```
tanzu secret registry add registry-credentials --server ghcr.io --username ${GITHUB_USERNAME} --password ${GITHUB_API_TOKEN} --namespace demo --kubeconfig kubeconfig-run
```

```
kubectl get deliverable -n demo --kubeconfig kubeconfig-build tanzu-java-web-app -oyaml \
| kubectl neat \
| kubectl apply -f - --kubeconfig kubeconfig-run
```


```
$ kubectl get deliverable -n demo --kubeconfig kubeconfig-run
NAME                 SOURCE                                                                                            DELIVERY         READY   REASON   AGE
tanzu-java-web-app   ghcr.io/making/supply-chain/tanzu-java-web-app-demo-bundle:6b8251bc-1afb-4875-9b1e-cbcebf62215c   delivery-basic   True    Ready    26s
```

```
$ kubectl get ksvc,pod -n demo                                                                       
NAME                                             URL                                                       LATESTCREATED              LATESTREADY                READY   REASON
service.serving.knative.dev/tanzu-java-web-app   https://tanzu-java-web-app-demo.192-168-11-220.sslip.io   tanzu-java-web-app-00001   tanzu-java-web-app-00001   True    

NAME                                                       READY   STATUS    RESTARTS   AGE
pod/tanzu-java-web-app-00001-deployment-7b58699fdc-b4s2j   2/2     Running   0          27m
```

```
$ curl -k $(kubectl get ksvc -n demo tanzu-java-web-app  -ojsonpath='{.status.url}' --kubeconfig kubeconfig-run) 
Greetings from Spring Boot + Tanzu!
```

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/193465359-7031b1ec-5a6d-4a84-b558-9674a774032d.png">

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/193465661-9acde09c-071f-4da1-972d-652eb3997ffb.png">

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/193468064-b35d4375-dcd0-4312-885f-e522732cd60e.png">
