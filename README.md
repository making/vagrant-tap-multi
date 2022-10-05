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
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.2.2 \
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
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: tap-selfsigned-issuer
  namespace: #@ namespace
spec:
  selfSigned: { }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tap-ca
  namespace: #@ namespace
spec:
  commonName: tap-ca
  isCA: true
  issuerRef:
    kind: Issuer
    name: tap-selfsigned-issuer
  secretName: tap-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: tap-ca-issuer
  namespace: #@ namespace
spec:
  ca:
    secretName: tap-ca
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
    name: tap-ca-issuer
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
          rm -fr /var/lib/postgresql/data/lost+found
        volumeMounts:
        - name: tap-gui-db
          mountPath: /var/lib/postgresql/data
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
          mountPath: /var/lib/postgresql/data
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
  namespace: tanzu-system-ingress
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
  server:
    service_type: ClusterIP

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
- fluxcd.source.controller.tanzu.vmware.com
- controller.source.apps.tanzu.vmware.com
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
  -v 1.2.2 \
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
$ kubectl get pod,svc,httpproxy -A --kubeconfig kubeconfig-view -owide
NAMESPACE              NAME                                                  READY   STATUS      RESTARTS   AGE     IP              NODE       NOMINATED NODE   READINESS GATES
kube-system            pod/calico-node-nrs2q                                 1/1     Running     0          94m     192.168.11.60   tap-view   <none>           <none>
metallb-system         pod/speaker-rt8kx                                     1/1     Running     0          91m     192.168.11.60   tap-view   <none>           <none>
kube-system            pod/coredns-64c6478b6c-hmp8c                          1/1     Running     0          91m     10.1.11.3       tap-view   <none>           <none>
kube-system            pod/metrics-server-679c5f986d-s5qsd                   1/1     Running     0          91m     10.1.11.1       tap-view   <none>           <none>
metallb-system         pod/controller-558b7b958-xc9d5                        1/1     Running     0          91m     10.1.11.2       tap-view   <none>           <none>
kube-system            pod/calico-kube-controllers-6d89d85f8d-8sg54          1/1     Running     0          94m     10.1.11.4       tap-view   <none>           <none>
kube-system            pod/csi-nfs-controller-94b9c7bc6-95tsd                3/3     Running     0          91m     192.168.11.60   tap-view   <none>           <none>
kube-system            pod/csi-nfs-node-lg7jm                                3/3     Running     0          91m     192.168.11.60   tap-view   <none>           <none>
kapp-controller        pod/kapp-controller-6944b4ff88-rgnxc                  2/2     Running     0          23m     10.1.11.5       tap-view   <none>           <none>
secretgen-controller   pod/secretgen-controller-7b77c88b9b-78ntp             1/1     Running     0          23m     10.1.11.6       tap-view   <none>           <none>
cert-manager           pod/cert-manager-webhook-654f8798d8-x4m4d             1/1     Running     0          12m     10.1.11.7       tap-view   <none>           <none>
cert-manager           pod/cert-manager-cainjector-59876d677f-kp7rk          1/1     Running     0          12m     10.1.11.8       tap-view   <none>           <none>
cert-manager           pod/cert-manager-6549557777-bhjss                     1/1     Running     0          12m     10.1.11.9       tap-view   <none>           <none>
tanzu-system-ingress   pod/contour-546b89686b-67hl9                          1/1     Running     0          11m     10.1.11.10      tap-view   <none>           <none>
tanzu-system-ingress   pod/envoy-wrjmq                                       2/2     Running     0          11m     10.1.11.11      tap-view   <none>           <none>
app-live-view          pod/application-live-view-server-8b457b77c-n879b      1/1     Running     0          10m     10.1.11.12      tap-view   <none>           <none>
tap-gui                pod/server-7f67f8c46-7zsbf                            1/1     Running     0          10m     10.1.11.13      tap-view   <none>           <none>
accelerator-system     pod/acc-engine-59b6df8f79-gnwjb                       1/1     Running     0          10m     10.1.11.15      tap-view   <none>           <none>
accelerator-system     pod/acc-server-685bd55557-b2rpb                       1/1     Running     0          10m     10.1.11.16      tap-view   <none>           <none>
metadata-store         pod/metadata-store-db-0                               1/1     Running     0          10m     10.1.11.18      tap-view   <none>           <none>
metadata-store         pod/metadata-store-app-56b85745b7-w54jb               2/2     Running     0          2m30s   10.1.11.21      tap-view   <none>           <none>
housekeeping           pod/housekeeping-27748507-b7jw5                       0/1     Completed   0          63s     10.1.11.23      tap-view   <none>           <none>
accelerator-system     pod/accelerator-controller-manager-79474f4579-5n277   0/1     Running     0          2s      10.1.11.25      tap-view   <none>           <none>
housekeeping           pod/housekeeping-27748508-bcktg                       0/1     Completed   0          3s      10.1.11.24      tap-view   <none>           <none>

NAMESPACE              NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE   SELECTOR
default                service/kubernetes                   ClusterIP      10.152.183.1     <none>           443/TCP                      94m   <none>
kube-system            service/kube-dns                     ClusterIP      10.152.183.10    <none>           53/UDP,53/TCP,9153/TCP       92m   k8s-app=kube-dns
kube-system            service/metrics-server               ClusterIP      10.152.183.41    <none>           443/TCP                      92m   k8s-app=metrics-server
kapp-controller        service/packaging-api                ClusterIP      10.152.183.138   <none>           443/TCP                      23m   app=kapp-controller
cert-manager           service/cert-manager                 ClusterIP      10.152.183.79    <none>           9402/TCP                     12m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager,kapp.k14s.io/app=1664909702154750971
cert-manager           service/cert-manager-webhook         ClusterIP      10.152.183.157   <none>           443/TCP                      12m   app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook,kapp.k14s.io/app=1664909702154750971
tanzu-system-ingress   service/envoy                        LoadBalancer   10.152.183.182   192.168.11.220   80:31888/TCP,443:30233/TCP   11m   app=envoy,kapp.k14s.io/app=1664909796010311222
tanzu-system-ingress   service/contour                      ClusterIP      10.152.183.183   <none>           8001/TCP                     11m   app=contour,kapp.k14s.io/app=1664909796010311222
app-live-view          service/application-live-view-7000   ClusterIP      10.152.183.21    <none>           7000/TCP                     10m   app=application-live-view-server,kapp.k14s.io/app=1664909857180071324
app-live-view          service/application-live-view-5112   ClusterIP      10.152.183.7     <none>           80/TCP                       10m   app=application-live-view-server,kapp.k14s.io/app=1664909857180071324
metadata-store         service/metadata-store-app           ClusterIP      10.152.183.46    <none>           8443/TCP                     10m   app=metadata-store-app,kapp.k14s.io/app=1664909857530665799
tap-gui                service/server                       ClusterIP      10.152.183.73    <none>           7000/TCP                     10m   app=backstage,component=backstage-server,kapp.k14s.io/app=1664909857571002828
metadata-store         service/metadata-store-db            ClusterIP      10.152.183.134   <none>           5432/TCP                     10m   app=metadata-store-db,kapp.k14s.io/app=1664909857530665799,tier=postgres
accelerator-system     service/acc-engine                   ClusterIP      10.152.183.42    <none>           80/TCP                       10m   app.kubernetes.io/name=acc-engine,kapp.k14s.io/app=1664909857650065989
accelerator-system     service/acc-server                   ClusterIP      10.152.183.223   <none>           80/TCP                       10m   app.kubernetes.io/name=acc-server,kapp.k14s.io/app=1664909857650065989

NAMESPACE            NAME                                                 FQDN                                     TLS SECRET                             STATUS   STATUS DESCRIPTION
app-live-view        httpproxy.projectcontour.io/appliveview              appliveview.192-168-11-220.sslip.io      tanzu-system-ingress/tap-default-tls   valid    Valid HTTPProxy
tap-gui              httpproxy.projectcontour.io/tap-gui                  tap-gui.192-168-11-220.sslip.io          tanzu-system-ingress/tap-default-tls   valid    Valid HTTPProxy
accelerator-system   httpproxy.projectcontour.io/accelerator              accelerator.192-168-11-220.sslip.io      tanzu-system-ingress/tap-default-tls   valid    Valid HTTPProxy
metadata-store       httpproxy.projectcontour.io/metadata-store-ingress   metadata-store.192-168-11-220.sslip.io   ingress-cert                           valid    Valid HTTPProxy
```

```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-view 


  NAME            PACKAGE-NAME                          PACKAGE-VERSION  STATUS               
  tap-telemetry   tap-telemetry.tanzu.vmware.com        0.2.1            Reconcile succeeded  
  cert-manager    cert-manager.tanzu.vmware.com         1.5.3+tap.2      Reconcile succeeded  
  appliveview     backend.appliveview.tanzu.vmware.com  1.2.1            Reconcile succeeded  
  tap-gui         tap-gui.tanzu.vmware.com              1.2.5            Reconcile succeeded  
  contour         contour.tanzu.vmware.com              1.18.2+tap.2     Reconcile succeeded  
  metadata-store  metadata-store.apps.tanzu.vmware.com  1.2.4            Reconcile succeeded  
  accelerator     accelerator.apps.tanzu.vmware.com     1.2.2            Reconcile succeeded  
  tap             tap.tanzu.vmware.com                  1.2.2            Reconcile succeeded  
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
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.2.2 \
  --namespace tap-install \
  --kubeconfig kubeconfig-build

tanzu package repository add tbs-full-deps-repository \
  --url registry.tanzu.vmware.com/build-service/full-tbs-deps-package-repo:1.6.3 \
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
  -v 1.2.2 \
  --values-file tap-values-build.yml \
  -n tap-install \
  --kubeconfig kubeconfig-build \
  --wait=false

tanzu package install full-tbs-deps \
  -p full-tbs-deps.tanzu.vmware.com \
  -v 1.6.3 \
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
$ kubectl get pod -A --kubeconfig kubeconfig-build -owide 
NAMESPACE                   NAME                                                           READY   STATUS        RESTARTS   AGE     IP              NODE             NOMINATED NODE   READINESS GATES
kube-system                 csi-nfs-node-z5z24                                             3/3     Running       0          26h     192.168.11.62   controlplane-2   <none>           <none>
kube-system                 calico-node-kggn2                                              1/1     Running       0          25h     192.168.11.72   worker-2         <none>           <none>
kube-system                 calico-node-vkz55                                              1/1     Running       0          25h     192.168.11.62   controlplane-2   <none>           <none>
kube-system                 csi-nfs-node-r5ldl                                             3/3     Running       0          25h     192.168.11.72   worker-2         <none>           <none>
metallb-system              speaker-ftrfp                                                  1/1     Running       0          25h     192.168.11.72   worker-2         <none>           <none>
metallb-system              controller-558b7b958-w59f7                                     1/1     Running       0          25h     10.1.133.193    worker-2         <none>           <none>
kube-system                 csi-nfs-controller-94b9c7bc6-72m2f                             3/3     Running       0          25h     192.168.11.72   worker-2         <none>           <none>
kube-system                 calico-kube-controllers-59ccbc986f-kbl6n                       1/1     Running       0          25h     10.1.133.194    worker-2         <none>           <none>
kube-system                 coredns-64c6478b6c-9jhvj                                       1/1     Running       0          25h     10.1.133.195    worker-2         <none>           <none>
kube-system                 metrics-server-679c5f986d-6klt8                                1/1     Running       0          25h     10.1.133.196    worker-2         <none>           <none>
metallb-system              speaker-7mf76                                                  1/1     Running       0          24h     192.168.11.62   controlplane-2   <none>           <none>
kapp-controller             kapp-controller-6944b4ff88-5l2kw                               2/2     Running       0          24h     10.1.133.197    worker-2         <none>           <none>
secretgen-controller        secretgen-controller-7b77c88b9b-cw89s                          1/1     Running       0          24h     10.1.133.198    worker-2         <none>           <none>
cert-manager                cert-manager-5784c547db-bj99w                                  1/1     Running       0          21m     10.1.133.223    worker-2         <none>           <none>
cert-manager                cert-manager-webhook-5d68896fdc-2ksm9                          1/1     Running       0          21m     10.1.133.222    worker-2         <none>           <none>
scan-link-system            scan-link-controller-manager-6f947d9fd7-lxdw6                  2/2     Running       0          21m     10.1.133.219    worker-2         <none>           <none>
tekton-pipelines            tekton-pipelines-controller-585469dd89-trdsr                   1/1     Running       0          21m     10.1.133.220    worker-2         <none>           <none>
kpack                       kpack-controller-5dd7bccc87-mpq2s                              1/1     Running       0          21m     10.1.201.147    controlplane-2   <none>           <none>
flux-system                 source-controller-64fd6dd4c8-szg7x                             1/1     Running       0          21m     10.1.133.218    worker-2         <none>           <none>
cert-manager                cert-manager-cainjector-87d6cbff8-mzv52                        1/1     Running       0          21m     10.1.133.221    worker-2         <none>           <none>
tekton-pipelines            tekton-pipelines-webhook-6f484cd696-nvspw                      1/1     Running       0          21m     10.1.201.145    controlplane-2   <none>           <none>
build-service               warmer-controller-6c97c8877d-w57b2                             1/1     Running       0          21m     10.1.201.146    controlplane-2   <none>           <none>
cert-injection-webhook      cert-injection-webhook-59f89fc868-4vpm4                        1/1     Running       0          21m     10.1.133.226    worker-2         <none>           <none>
build-service               dependency-updater-controller-6c744895b8-k6hmv                 1/1     Running       0          21m     10.1.133.224    worker-2         <none>           <none>
build-service               secret-syncer-controller-656c9d7658-bgd7j                      1/1     Running       0          21m     10.1.133.225    worker-2         <none>           <none>
kpack                       kpack-webhook-ff958b4db-ffxbj                                  1/1     Running       0          21m     10.1.201.148    controlplane-2   <none>           <none>
stacks-operator-system      controller-manager-685d7b84cc-qls8t                            1/1     Running       0          21m     10.1.201.150    controlplane-2   <none>           <none>
build-service               build-pod-image-fetcher-gtpkx                                  5/5     Running       0          21m     10.1.133.227    worker-2         <none>           <none>
conventions-system          conventions-controller-manager-6585dbb558-nnr4g                1/1     Running       0          20m     10.1.133.228    worker-2         <none>           <none>
build-service               build-pod-image-fetcher-9w58l                                  5/5     Running       0          21m     10.1.201.149    controlplane-2   <none>           <none>
app-live-view-conventions   appliveview-webhook-8bcb48ddb-85dqx                            1/1     Running       0          19m     10.1.133.229    worker-2         <none>           <none>
spring-boot-convention      spring-boot-webhook-7d977565b8-z99vd                           1/1     Running       0          19m     10.1.201.151    controlplane-2   <none>           <none>
cartographer-system         cartographer-controller-dd5bddfdd-xjzbn                        1/1     Running       0          20m     10.1.133.230    worker-2         <none>           <none>
cartographer-system         cartographer-conventions-controller-manager-686569d467-c7wz8   1/1     Running       0          20m     10.1.201.152    controlplane-2   <none>           <none>
source-system               source-controller-manager-77ffd7444c-4kcgt                     1/1     Running       0          20m     10.1.133.231    worker-2         <none>           <none>
build-service               smart-warmer-image-fetcher-g56zp                               0/1     Terminating   0          2m22s   10.1.201.153    controlplane-2   <none>           <none>
build-service               smart-warmer-image-fetcher-p572f                               0/1     Terminating   0          2m22s   10.1.133.232    worker-2         <none>           <none>
```

```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-build


  NAME                      PACKAGE-NAME                                  PACKAGE-VERSION  STATUS               
  tap-auth                  tap-auth.tanzu.vmware.com                     1.0.1            Reconcile succeeded  
  tap-telemetry             tap-telemetry.tanzu.vmware.com                0.2.1            Reconcile succeeded  
  scanning                  scanning.apps.tanzu.vmware.com                1.2.3            Reconcile succeeded  
  fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com     0.16.4           Reconcile succeeded  
  cert-manager              cert-manager.tanzu.vmware.com                 1.5.3+tap.2      Reconcile succeeded  
  tekton-pipelines          tekton.tanzu.vmware.com                       0.33.5           Reconcile succeeded  
  buildservice              buildservice.tanzu.vmware.com                 1.6.3            Reconcile succeeded  
  conventions-controller    controller.conventions.apps.tanzu.vmware.com  0.7.0            Reconcile succeeded  
  spring-boot-conventions   spring-boot-conventions.tanzu.vmware.com      0.4.1            Reconcile succeeded  
  cartographer              cartographer.tanzu.vmware.com                 0.4.3            Reconcile succeeded  
  ootb-templates            ootb-templates.tanzu.vmware.com               0.8.1            Reconcile succeeded  
  source-controller         controller.source.apps.tanzu.vmware.com       0.4.1            Reconcile succeeded  
  ootb-supply-chain-basic   ootb-supply-chain-basic.tanzu.vmware.com      0.8.1            Reconcile succeeded  
  tap                       tap.tanzu.vmware.com                          1.2.2            Reconcile succeeded  
  full-tbs-deps             full-tbs-deps.tanzu.vmware.com                1.6.3            Reconcile succeeded  
  appliveview-conventions   conventions.appliveview.tanzu.vmware.com      1.2.1            Reconcile succeeded 
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
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.2.2 \
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
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: tap-selfsigned-issuer
  namespace: #@ namespace
spec:
  selfSigned: { }
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tap-ca
  namespace: #@ namespace
spec:
  commonName: tap-ca
  isCA: true
  issuerRef:
    kind: Issuer
    name: tap-selfsigned-issuer
  secretName: tap-ca
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: tap-ca-issuer
  namespace: #@ namespace
spec:
  ca:
    secretName: tap-ca
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
    name: tap-ca-issuer
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

cat <<EOF > overlays/run/cnrs-slim.yml
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

contour:
  infrastructure_provider: "vsphere"
  namespace: tanzu-system-ingress
  contour:
    replicas: 1
    configFileContents:
      accesslog-format: json
  envoy:
    service:
      type: LoadBalancer

cnrs:
  domain_name: ${DOMAIN_NAME_RUN}
  domain_template: "{{.Name}}-{{.Namespace}}.{{.Domain}}"
  default_tls_secret: tanzu-system-ingress/tap-default-tls
  provider: local

supply_chain: basic

appliveview_connector:
  backend:
    sslDisabled: false
    host: appliveview.${DOMAIN_NAME_VIEW}

package_overlays:
- name: contour
  secrets:
  - name: contour-loadbalancer-ip
  - name: contour-default-tls
- name: cnrs
  secrets:
  - name: cnrs-slim
  - name: cnrs-https
- name: tap-telemetry
  secrets:
  - name: tap-telemetry-remove
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

kubectl -n tap-install create secret generic cnrs-slim \
  -o yaml \
  --dry-run=client \
  --from-file=overlays/run/cnrs-slim.yml \
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
  -v 1.2.2 \
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
$ kubectl get pod,svc -A --kubeconfig kubeconfig-run -owide  
NAMESPACE                 NAME                                                               READY   STATUS    RESTARTS   AGE     IP              NODE             NOMINATED NODE   READINESS GATES
kube-system               pod/csi-nfs-node-s8chs                                             3/3     Running   0          21h     192.168.11.61   controlplane-1   <none>           <none>
kube-system               pod/calico-node-qs8dd                                              1/1     Running   0          21h     192.168.11.71   worker-1         <none>           <none>
kube-system               pod/calico-node-fw28r                                              1/1     Running   0          21h     192.168.11.61   controlplane-1   <none>           <none>
kube-system               pod/csi-nfs-node-pmt9b                                             3/3     Running   0          21h     192.168.11.71   worker-1         <none>           <none>
kube-system               pod/calico-node-k6kp5                                              1/1     Running   0          20h     192.168.11.74   worker-4         <none>           <none>
kube-system               pod/csi-nfs-node-5sq4p                                             3/3     Running   0          20h     192.168.11.74   worker-4         <none>           <none>
metallb-system            pod/speaker-mnxg7                                                  1/1     Running   0          20h     192.168.11.71   worker-1         <none>           <none>
metallb-system            pod/speaker-7vntz                                                  1/1     Running   0          20h     192.168.11.74   worker-4         <none>           <none>
metallb-system            pod/controller-558b7b958-dvg2q                                     1/1     Running   0          20h     10.1.226.65     worker-1         <none>           <none>
kube-system               pod/csi-nfs-controller-94b9c7bc6-4lzqx                             3/3     Running   0          20h     192.168.11.74   worker-4         <none>           <none>
kube-system               pod/metrics-server-679c5f986d-f26qx                                1/1     Running   0          20h     10.1.226.66     worker-1         <none>           <none>
kube-system               pod/calico-kube-controllers-74dbb97ff-hj57p                        1/1     Running   0          20h     10.1.38.65      worker-4         <none>           <none>
kube-system               pod/coredns-64c6478b6c-c7v7s                                       1/1     Running   0          20h     10.1.38.66      worker-4         <none>           <none>
metallb-system            pod/speaker-sd5wh                                                  1/1     Running   0          20h     192.168.11.61   controlplane-1   <none>           <none>
secretgen-controller      pod/secretgen-controller-7b77c88b9b-tr2f7                          1/1     Running   0          20h     10.1.38.67      worker-4         <none>           <none>
kapp-controller           pod/kapp-controller-6944b4ff88-dj8p4                               2/2     Running   0          20h     10.1.226.67     worker-1         <none>           <none>
app-live-view-connector   pod/application-live-view-connector-5sp5q                          1/1     Running   0          16m     10.1.38.73      worker-4         <none>           <none>
app-live-view-connector   pod/application-live-view-connector-fbrk4                          1/1     Running   0          16m     10.1.226.72     worker-1         <none>           <none>
app-live-view-connector   pod/application-live-view-connector-cj6kj                          1/1     Running   0          16m     10.1.13.198     controlplane-1   <none>           <none>
service-bindings          pod/manager-5b49497b6d-j48mf                                       1/1     Running   0          15m     10.1.38.75      worker-4         <none>           <none>
services-toolkit          pod/services-toolkit-controller-manager-6bdf7f799f-b47fp           1/1     Running   0          15m     10.1.38.76      worker-4         <none>           <none>
cert-manager              pod/cert-manager-7bcbb59545-pfjt6                                  1/1     Running   0          15m     10.1.226.75     worker-1         <none>           <none>
flux-system               pod/source-controller-5fd676f9fd-pz8h5                             1/1     Running   0          16m     10.1.38.74      worker-4         <none>           <none>
cert-manager              pod/cert-manager-cainjector-74b9c9c447-559p5                       1/1     Running   0          15m     10.1.226.74     worker-1         <none>           <none>
services-toolkit          pod/resource-claims-apiserver-6cb677f48d-mtwj4                     1/1     Running   0          15m     10.1.226.73     worker-1         <none>           <none>
cert-manager              pod/cert-manager-webhook-765b8f548-9rg86                           1/1     Running   0          15m     10.1.38.77      worker-4         <none>           <none>
appsso                    pod/operator-5d6dd4b59-rgrqk                                       1/1     Running   0          15m     10.1.38.78      worker-4         <none>           <none>
cosign-system             pod/policy-webhook-89dd8bd87-z248r                                 1/1     Running   0          14m     10.1.226.76     worker-1         <none>           <none>
cartographer-system       pod/cartographer-controller-5878694559-j24cd                       1/1     Running   0          14m     10.1.226.78     worker-1         <none>           <none>
cartographer-system       pod/cartographer-conventions-controller-manager-5757995fc6-k4zsb   1/1     Running   0          14m     10.1.38.81      worker-4         <none>           <none>
cosign-system             pod/webhook-9fcffc88b-k88c4                                        1/1     Running   0          14m     10.1.38.80      worker-4         <none>           <none>
image-policy-system       pod/image-policy-controller-manager-6f7495b7dd-p75xj               2/2     Running   0          14m     10.1.226.77     worker-1         <none>           <none>
source-system             pod/source-controller-manager-5fb655d5c9-s4djj                     1/1     Running   0          14m     10.1.38.79      worker-4         <none>           <none>
tanzu-system-ingress      pod/contour-57597844b6-x24th                                       1/1     Running   0          14m     10.1.38.82      worker-4         <none>           <none>
tanzu-system-ingress      pod/envoy-nd7jm                                                    2/2     Running   0          14m     10.1.226.79     worker-1         <none>           <none>
tanzu-system-ingress      pod/envoy-c9c7z                                                    2/2     Running   0          14m     10.1.13.199     controlplane-1   <none>           <none>
tanzu-system-ingress      pod/envoy-pmg4w                                                    2/2     Running   0          14m     10.1.38.83      worker-4         <none>           <none>
knative-serving           pod/controller-86754f79fc-5vhk9                                    1/1     Running   0          2m18s   10.1.38.84      worker-4         <none>           <none>
knative-serving           pod/net-certmanager-webhook-67d6bc8846-vk5hs                       1/1     Running   0          2m15s   10.1.226.80     worker-1         <none>           <none>
knative-serving           pod/domainmapping-webhook-66f874f678-645fg                         1/1     Running   0          2m18s   10.1.38.86      worker-4         <none>           <none>
knative-serving           pod/domain-mapping-656f685b5-f6btg                                 1/1     Running   0          2m17s   10.1.38.87      worker-4         <none>           <none>
knative-serving           pod/autoscaler-fb57cc788-v27b2                                     1/1     Running   0          2m18s   10.1.38.88      worker-4         <none>           <none>
knative-serving           pod/activator-75f5cc8cb9-9d2k4                                     1/1     Running   0          2m18s   10.1.38.85      worker-4         <none>           <none>
knative-serving           pod/autoscaler-hpa-8458c9c4c9-8p79p                                1/1     Running   0          2m17s   10.1.38.89      worker-4         <none>           <none>
knative-serving           pod/webhook-bdb96c65b-qnlbf                                        1/1     Running   0          2m16s   10.1.38.90      worker-4         <none>           <none>
knative-serving           pod/net-certmanager-controller-578c556dc5-9jg2k                    1/1     Running   0          2m16s   10.1.38.91      worker-4         <none>           <none>
knative-serving           pod/net-contour-controller-74d49ff66f-tztj2                        1/1     Running   0          2m16s   10.1.38.92      worker-4         <none>           <none>

NAMESPACE              NAME                                                                  TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                           AGE     SELECTOR
default                service/kubernetes                                                    ClusterIP      10.152.183.1     <none>           443/TCP                           21h     <none>
kube-system            service/kube-dns                                                      ClusterIP      10.152.183.10    <none>           53/UDP,53/TCP,9153/TCP            21h     k8s-app=kube-dns
kube-system            service/metrics-server                                                ClusterIP      10.152.183.132   <none>           443/TCP                           21h     k8s-app=metrics-server
kapp-controller        service/packaging-api                                                 ClusterIP      10.152.183.38    <none>           443/TCP                           20h     app=kapp-controller
flux-system            service/source-controller                                             ClusterIP      10.152.183.51    <none>           80/TCP                            16m     app=source-controller,kapp.k14s.io/app=1664680200007669114
service-bindings       service/webhook                                                       ClusterIP      10.152.183.233   <none>           443/TCP                           15m     kapp.k14s.io/app=1664680200872311234,role=manager
services-toolkit       service/resource-claims-apiserver                                     ClusterIP      10.152.183.82    <none>           443/TCP                           15m     app.kubernetes.io/name=resource-claims-apiserver,kapp.k14s.io/app=1664680199859281091
cert-manager           service/cert-manager-webhook                                          ClusterIP      10.152.183.139   <none>           443/TCP                           15m     app.kubernetes.io/component=webhook,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=webhook,kapp.k14s.io/app=1664680201113707617
cert-manager           service/cert-manager                                                  ClusterIP      10.152.183.27    <none>           9402/TCP                          15m     app.kubernetes.io/component=controller,app.kubernetes.io/instance=cert-manager,app.kubernetes.io/name=cert-manager,kapp.k14s.io/app=1664680201113707617
appsso                 service/operator-webhook                                              ClusterIP      10.152.183.216   <none>           443/TCP                           15m     kapp.k14s.io/app=1664680254734830914,name=operator
source-system          service/source-controller-manager-artifact-service                    ClusterIP      10.152.183.187   <none>           80/TCP                            14m     control-plane=controller-manager,kapp.k14s.io/app=1664680257091324896
source-system          service/source-webhook-service                                        ClusterIP      10.152.183.159   <none>           443/TCP                           14m     control-plane=controller-manager,kapp.k14s.io/app=1664680257091324896
source-system          service/source-controller-manager-metrics-service                     ClusterIP      10.152.183.157   <none>           8443/TCP                          14m     control-plane=controller-manager,kapp.k14s.io/app=1664680257091324896
image-policy-system    service/image-policy-webhook-service                                  ClusterIP      10.152.183.67    <none>           443/TCP                           14m     control-plane=controller-manager,kapp.k14s.io/app=1664680256374409186,signing.apps.tanzu.vmware.com/application-name=image-policy-webhook
image-policy-system    service/image-policy-controller-manager-metrics-service               ClusterIP      10.152.183.148   <none>           8443/TCP                          14m     control-plane=controller-manager,kapp.k14s.io/app=1664680256374409186,signing.apps.tanzu.vmware.com/application-name=image-policy-webhook
tanzu-system-ingress   service/contour                                                       ClusterIP      10.152.183.49    <none>           8001/TCP                          14m     app=contour,kapp.k14s.io/app=1664680256208199314
cartographer-system    service/cartographer-conventions-controller-manager-metrics-service   ClusterIP      10.152.183.75    <none>           8443/TCP                          14m     app.kubernetes.io/component=conventions,control-plane=controller-manager,kapp.k14s.io/app=1664680258915424888
tanzu-system-ingress   service/envoy                                                         LoadBalancer   10.152.183.195   192.168.11.220   80:31472/TCP,443:32742/TCP        14m     app=envoy,kapp.k14s.io/app=1664680256208199314
cartographer-system    service/cartographer-conventions-webhook-service                      ClusterIP      10.152.183.191   <none>           443/TCP                           14m     app.kubernetes.io/component=conventions,control-plane=controller-manager,kapp.k14s.io/app=1664680258915424888
cosign-system          service/policy-webhook                                                ClusterIP      10.152.183.73    <none>           443/TCP                           14m     kapp.k14s.io/app=1664680256183012857,role=policy-webhook
cosign-system          service/webhook                                                       ClusterIP      10.152.183.239   <none>           443/TCP                           14m     kapp.k14s.io/app=1664680256183012857,role=webhook
cartographer-system    service/cartographer-webhook                                          ClusterIP      10.152.183.25    <none>           443/TCP                           14m     app=cartographer-controller,kapp.k14s.io/app=1664680258915424888
knative-serving        service/net-certmanager-webhook                                       ClusterIP      10.152.183.172   <none>           9090/TCP,8008/TCP,443/TCP         2m18s   app=net-certmanager-webhook,kapp.k14s.io/app=1664681007527064650
knative-serving        service/activator-service                                             ClusterIP      10.152.183.171   <none>           9090/TCP,8008/TCP,80/TCP,81/TCP   2m18s   app=activator,kapp.k14s.io/app=1664681007527064650
knative-serving        service/autoscaler                                                    ClusterIP      10.152.183.18    <none>           9090/TCP,8008/TCP,8080/TCP        2m18s   app=autoscaler,kapp.k14s.io/app=1664681007527064650
knative-serving        service/controller                                                    ClusterIP      10.152.183.55    <none>           9090/TCP,8008/TCP                 2m18s   app=controller,kapp.k14s.io/app=1664681007527064650
knative-serving        service/domainmapping-webhook                                         ClusterIP      10.152.183.97    <none>           9090/TCP,8008/TCP,443/TCP         2m17s   kapp.k14s.io/app=1664681007527064650,role=domainmapping-webhook
knative-serving        service/webhook                                                       ClusterIP      10.152.183.149   <none>           9090/TCP,8008/TCP,443/TCP         2m17s   kapp.k14s.io/app=1664681007527064650,role=webhook
knative-serving        service/autoscaler-hpa                                                ClusterIP      10.152.183.26    <none>           9090/TCP,8008/TCP                 2m17s   app=autoscaler-hpa,kapp.k14s.io/app=1664681007527064650
knative-serving        service/net-certmanager-controller                                    ClusterIP      10.152.183.160   <none>           9090/TCP,8008/TCP                 2m16s   app=net-certmanager-controller,kapp.k14s.io/app=1664681007527064650
knative-serving        service/autoscaler-bucket-00-of-01                                    ClusterIP      10.152.183.44    <none>           8080/TCP                          73s     <none>
```

```
$ tanzu package installed list -n tap-install --kubeconfig kubeconfig-run 


  NAME                      PACKAGE-NAME                                        PACKAGE-VERSION  STATUS               
  tap-auth                  tap-auth.tanzu.vmware.com                           1.0.1            Reconcile succeeded  
  tap-telemetry             tap-telemetry.tanzu.vmware.com                      0.2.1            Reconcile succeeded  
  service-bindings          service-bindings.labs.vmware.com                    0.7.2            Reconcile succeeded  
  appliveview-connector     connector.appliveview.tanzu.vmware.com              1.2.1            Reconcile succeeded  
  fluxcd-source-controller  fluxcd.source.controller.tanzu.vmware.com           0.16.4           Reconcile succeeded  
  services-toolkit          services-toolkit.tanzu.vmware.com                   0.7.1            Reconcile succeeded  
  cert-manager              cert-manager.tanzu.vmware.com                       1.5.3+tap.2      Reconcile succeeded  
  appsso                    sso.apps.tanzu.vmware.com                           1.0.0            Reconcile succeeded  
  cartographer              cartographer.tanzu.vmware.com                       0.4.3            Reconcile succeeded  
  policy-controller         policy.apps.tanzu.vmware.com                        1.0.1            Reconcile succeeded  
  image-policy-webhook      image-policy-webhook.signing.apps.tanzu.vmware.com  1.1.5            Reconcile succeeded  
  ootb-templates            ootb-templates.tanzu.vmware.com                     0.8.1            Reconcile succeeded  
  source-controller         controller.source.apps.tanzu.vmware.com             0.4.1            Reconcile succeeded  
  ootb-delivery-basic       ootb-delivery-basic.tanzu.vmware.com                0.8.1            Reconcile succeeded  
  contour                   contour.tanzu.vmware.com                            1.18.2+tap.2     Reconcile succeeded  
  cnrs                      cnrs.tanzu.vmware.com                               1.3.0            Reconcile succeeded  
  tap                       tap.tanzu.vmware.com                                1.2.2            Reconcile succeeded 
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

TAP 1.2 and below do not support self-signed TLS communication between ALV connector and server. It will be supported in TAP 1.3.
To communicate between ALV connector and server in TAP 1.2 multi cluster, TLS communication by trusted CA or plaintext (HTTP) must be used.
The following changes are required for plaintext communication.

`tap-values-view.yaml`

```yaml
tap-gui: # ...

# comment out bellow

# appliveview:
#   tls:
#     secretName: tap-default-tls
#     namespace: tanzu-system-ingress
```

```
tanzu package installed update -n tap-install tap -f tap-values-view.yml --kubeconfig kubeconfig-view 
```

`tap-values-run.yaml`

```yaml
appliveview_connector:
  backend:
    sslDisabled: "true"
    host: appliveview.${DOMAIN_NAME_VIEW}
```

```
tanzu package installed update -n tap-install tap -f tap-values-run.yml --kubeconfig kubeconfig-run
```

<img width="1024" alt="image" src="https://user-images.githubusercontent.com/106908/193468064-b35d4375-dcd0-4312-885f-e522732cd60e.png">