# Thanos

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


## remote write

aws eks update-kubeconfig --name my-cluster --region us-east-2