# Thanos

## remote read

minikube start --kubernetes-version=v1.26.3 --driver=docker
kubectl apply -f monitoring-ns.yaml
kubectl create -f prometheus-operator-crds
kubectl apply -R -f prometheus-operator
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=prometheus-operator -n monitoring -f














## remote write

aws eks update-kubeconfig --name my-cluster --region us-east-2