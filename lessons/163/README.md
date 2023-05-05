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

## deploy minio

kubectl apply -f minio-ns.yaml
kubectl apply -f minio












## remote write

aws eks update-kubeconfig --name my-cluster --region us-east-2