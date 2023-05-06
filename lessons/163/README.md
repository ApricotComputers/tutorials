# Thanos


## remote read

minikube start --kubernetes-version=v1.26.3 --driver=docker

go over namespaces a then folders including all prometehus resources (selectors, etc.) and minio







































## remote read

minikube start --kubernetes-version=v1.26.3 --driver=docker
kubectl apply -f monitoring-ns.yaml
kubectl create -f prometheus-operator-crds
kubectl apply -R -f prometheus-operator
kubectl get pods -n monitoring
kubectl get pods -n monitoring --show-labels
kubectl logs -l app.kubernetes.io/name=prometheus-operator -n monitoring -f
kubectl apply -f prometheus
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring -f
kubectl pods
kubectl port-forward svc/prometheus-operated 9090 -n monitoring
open http://localhost:9090/

query prometheus_http

## deploy minio

kubectl apply -f minio-ns.yaml
kubectl apply -f minio
kubectl get pods -n minio

kubectl get svc -n minio

## setup prometheus sidecar
minikube service minio-console --url -n minio
admin/devops123

create `prometheus-metrics`
create access key

aDyTcU5HOUVNTfl8
m2Rv69ko3f5qnjiD83sAih4BWMRZWL9T

kubectl logs -f prometheus-main-0 -c thanos-sidecar -f




## Deploy Thanos

create querier

kubectl apply -f thanos


kubectl logs -l app.kubernetes.io/name=querier -n monitoring -f
kubectl port-forward svc/querier 9090 -n monitoring

open `Stores`

query `prometheus_http_requests_total` and show `prometheus="monitoring/main"`

create storagegateway

kubectl apply -f thanos
kubectl logs -l app.kubernetes.io/name=storegateway -n monitoring -f

add storagegateway to querier

```
- --store=storegateway.monitoring:10901
```

kubectl apply -f thanos

open `Store` in querier

kubectl apply -f thanos


```
---
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: main
  namespace: monitoring
spec:
  version: v2.43.1
  serviceAccountName: prometheus
  podMonitorSelector:
    matchLabels:
      prometheus: main
  podMonitorNamespaceSelector:
    matchLabels:
      monitoring: prometheus
  serviceMonitorSelector:
    matchLabels:
      prometheus: main
  serviceMonitorNamespaceSelector:
    matchLabels:
      monitoring: prometheus
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 2Gi
  replicas: 1
  logLevel: info
  logFormat: logfmt
  retention: 1d
  scrapeInterval: 15s
  securityContext:
    fsGroup: 0
    runAsNonRoot: false
    runAsUser: 0
  # storage:
  #   volumeClaimTemplate:
  #     spec:
  #       resources:
  #         requests:
  #           storage: 20Gi
  thanos:
    version: v0.31.0
    objectStorageConfig:
      name: objstore
      key: objstore.yml

```

create `7-sidecar-svc.yaml`

## Remote read mTLS

https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/

install `cfssl`
create `demo-certs`
cd demo-certs
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=demo sidecar-csr.json | cfssljson -bare sidecar

sidecar-tls




create `6-sidecar-tls.yaml`

kubectl apply -f prometheus/6-sidecar-tls.yaml

```
  thanos:
    version: v0.31.0
    objectStorageConfig:
      name: objstore
      key: objstore.yml
    grpcServerTlsConfig:
      caFile: /secrets/ca.crt
      certFile: /secrets/tls.crt
      keyFile: /secrets/tls.key
  containers:
  - name: thanos-sidecar
    volumeMounts:
    - name: sidecar-tls
      mountPath: /secrets
  volumes:
  - name: sidecar-tls
    secret:
      secretName: sidecar-tls
```

kubectl apply -f prometheus/3-prometheus.yaml
kubectl logs -f prometheus-main-0 -c thanos-sidecar -f


kubectl delete pod querier-5fc6f6bf8d-k8zm4
kubectl port-forward svc/querier 9090 -n monitoring

show store wihout sidecar

add `tls` to query

create tls for querier `querier-csr.json`

create `7-querier-tls.yaml`

kubectl apply -f thanos/7-querier-tls.yaml

```yaml
            - --grpc-client-tls-secure
            - --grpc-client-tls-cert=/secrets/tls.crt
            - --grpc-client-tls-key=/secrets/tls.key
            - --grpc-client-tls-ca=/secrets/ca.crt

          volumeMounts:
            - name: querier-tls
              mountPath: /secrets
      volumes:
        - name: querier-tls
          secret:
            secretName: querier-tls
```

kubectl apply -f thanos/7-querier-tls.yaml

update storagegateway



```
            - --grpc-server-tls-cert=/secrets/tls.crt
            - --grpc-server-tls-key=/secrets/tls.key
            - --grpc-server-tls-client-ca=/secrets/ca.crt


            - name: storegateway-tls
              mountPath: /secrets

        - name: storegateway-tls
          secret:
            secretName: storegateway-tls
```

kubectl apply -f thanos





## remote write

aws eks update-kubeconfig --name my-cluster --region us-east-2