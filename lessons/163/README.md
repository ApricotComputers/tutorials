# Thanos


## remote read

minikube start --kubernetes-version=v1.26.3 --driver=docker
kubectl get nodes

go over namespaces a then folders including all prometehus resources (selectors, etc.)

kubectl apply -f monitoring-ns.yaml
kubectl create -f prometheus-operator-crds
kubectl apply -R -f prometheus-operator
kubectl get pods -n monitoring
kubectl get pods -n monitoring --show-labels
kubectl logs -l app.kubernetes.io/name=prometheus-operator -n monitoring -f
kubectl apply -f prometheus
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring -f
kubectl port-forward svc/prometheus-operated 9090 -n monitoring
open http://localhost:9090/

query prometheus_http

## deploy minio

go over minio files

kubectl apply -f minio-ns.yaml
kubectl apply -f minio
kubectl get pods -n minio
kubectl get svc -n minio

minikube service minio-console --url -n minio
admin/devops123

## setup prometheus sidecar

create `prometheus-metrics`
create access key
create `prometheus/5-objectstore.yaml`
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  namespace: monitoring
  name: objstore
stringData:
  objstore.yml: |-
    type: S3
    config:
      bucket: prometheus-metrics
      endpoint: "minio.minio:9000"
      insecure: true
      access_key: "1bwDBSpKUC8dOdxZ"
      secret_key: "6y79ptsoPAmB5P1WDO39eXKgMeOMWGTG"
```

update prometheus/3-prometheus.yaml
```yaml
  thanos:
    version: v0.31.0
    objectStorageConfig:
      name: objstore
      key: objstore.yml
```

kubectl apply -f prometheus
kubectl get pods -n monitoring

kubectl logs -f prometheus-main-0 -c thanos-sidecar -f -n monitoring

create `6-sidecar-svc.yaml`
```yaml
---
apiVersion: v1
kind: Service
metadata:
  namespace: monitoring
  name: sidecar
spec:
  type: ClusterIP
  ports:
    - port: 10901
      targetPort: grpc
      protocol: TCP
      name: grpc
  selector:
    app.kubernetes.io/name: prometheus
```

kubectl apply -f prometheus
kubectl get svc -n monitoring
kubectl get endpoints -n monitoring

## Deploy Thanos querier

crete `thanos` folder
create `0-service-account.yaml`
```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: thanos
  namespace: monitoring
```

create `1-querier-deployment.yaml`
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: monitoring
  name: querier
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: querier
  template:
    metadata:
      labels:
        app.kubernetes.io/name: querier
    spec:
      serviceAccount: thanos
      securityContext:
        runAsUser: 1001
        fsGroup: 1001
      containers:
        - name: querier
          image: docker.io/bitnami/thanos:0.31.0
          args:
            - query
            - --log.level=info
            - --endpoint.info-timeout=30s
            - --grpc-address=0.0.0.0:10901
            - --http-address=0.0.0.0:10902
            - --query.replica-label=prometheus_replica
            - --store=sidecar.monitoring.svc.cluster.local:10901
          ports:
            - name: http
              containerPort: 10902
              protocol: TCP
            - name: grpc
              containerPort: 10901
              protocol: TCP
          livenessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/healthy
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          readinessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/ready
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 2Gi
```

create `2-querier-service.yaml`
```yaml
---
apiVersion: v1
kind: Service
metadata:
  namespace: monitoring
  name: querier
spec:
  type: ClusterIP
  ports:
    - port: 9090
      targetPort: http
      protocol: TCP
      name: http
    - port: 10901
      targetPort: grpc
      protocol: TCP
      name: grpc
  selector:
    app.kubernetes.io/name: querier
```
kubectl apply -f thanos
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=querier -n monitoring -f
kubectl port-forward svc/querier 9090 -n monitoring

prometheus_http_requests_total
prometheus_http_requests_total{prometheus="monitoring/staging"}

## deploy thanos storegateway

create `3-storegateway-sts.yaml`
```yaml
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  namespace: monitoring
  name: storegateway
spec:
  replicas: 1
  serviceName: storegateway
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app.kubernetes.io/name: storegateway
  template:
    metadata:
      labels:
        app.kubernetes.io/name: storegateway
    spec:
      serviceAccount: thanos
      securityContext:
        fsGroup: 1001
      initContainers:
        - name: init-chmod-data
          image: docker.io/bitnami/minideb:buster
          command:
            - sh
            - -c
            - |
              mkdir -p /data
              chown -R "1001:1001" /data
          securityContext:
            runAsUser: 0
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: storegateway
          image: docker.io/bitnami/thanos:0.31.0
          securityContext:
            runAsUser: 1001
          args:
            - store
            - --chunk-pool-size=2GB
            - --log.level=debug
            - --grpc-address=0.0.0.0:10901
            - --http-address=0.0.0.0:10902
            - --data-dir=/data
            - --objstore.config-file=/conf/objstore.yml
          ports:
            - name: http
              containerPort: 10902
              protocol: TCP
            - name: grpc
              containerPort: 10901
              protocol: TCP
          livenessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/healthy
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          readinessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/ready
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 1Gi
          volumeMounts:
            - name: objstore
              mountPath: /conf/objstore.yml
              subPath: objstore.yml
            - name: data
              mountPath: /data
      volumes:
        - name: objstore
          secret:
            secretName: objstore
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 20Gi
```

create `4-storegateway-service.yaml`
```yaml
---
apiVersion: v1
kind: Service
metadata:
  namespace: monitoring
  name: storegateway
spec:
  type: ClusterIP
  ports:
    - port: 9090
      targetPort: http
      protocol: TCP
      name: http
    - port: 10901
      targetPort: grpc
      protocol: TCP
      name: grpc
  selector:
    app.kubernetes.io/name: storegateway
```

update `thanos/1-querier-deployment.yaml`
```yaml
- --store=storegateway.monitoring.svc.cluster.local:10901
```

kubectl apply -f thanos
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=querier -n monitoring -f
kubectl port-forward svc/querier 9090 -n monitoring

## deploy comactor

create `5-compactor-pvc.yaml`
```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  namespace: monitoring
  name: compactor
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
```

create `6-compactor-deployment.yaml`
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: monitoring
  name: compactor
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: compactor
  template:
    metadata:
      labels:
        app.kubernetes.io/name: compactor
    spec:
      serviceAccount: thanos
      securityContext:
        fsGroup: 1001
      initContainers:
        - name: init-chmod-data
          image: docker.io/bitnami/minideb:buster
          command:
            - sh
            - -c
            - |
              mkdir -p /data
              chown -R "1001:1001" /data
          securityContext:
            runAsUser: 0
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: compactor
          image: docker.io/bitnami/thanos:0.31.0
          imagePullPolicy: IfNotPresent
          securityContext:
            runAsUser: 1001
          args:
            - compact
            - --log.level=info
            - --http-address=0.0.0.0:10902
            - --data-dir=/data
            - --retention.resolution-raw=7d
            - --retention.resolution-5m=30d
            - --retention.resolution-1h=180d
            - --consistency-delay=30m
            - --objstore.config-file=/conf/objstore.yml
            - --wait
          ports:
            - name: http
              containerPort: 10902
              protocol: TCP
          livenessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/healthy
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          readinessProbe:
            failureThreshold: 6
            httpGet:
              path: /-/ready
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 30
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 256Mi
          volumeMounts:
            - name: objstore
              mountPath: /conf/objstore.yml
              subPath: objstore.yml
            - name: data
              mountPath: /data
      volumes:
        - name: objstore
          secret:
            secretName: objstore
        - name: data
          persistentVolumeClaim:
            claimName: compactor
```

kubectl apply -f thanos
kubectl get pods -n monitoring
kubectl logs -l app.kubernetes.io/name=compactor -n monitoring -f

## remote read mTLS

install cfssl (https://github.com/cloudflare/cfssl)
brew install cfssl
cfssl version

create `demo-certs`
create `ca-config.json`
```json
{
    "signing": {
        "default": {
            "expiry": "8760h"
        },
        "profiles": {
            "demo": {
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ],
                "expiry": "8760h"
            }
        }
    }
}
```
create `ca-csr.json`
```json
{
    "CN": "DevOps by Example",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "Los Banos"
        }
    ]
}
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
show ca and a key

create `sidecar-csr.json`
```
{
    "CN": "sidecar.monitoring.svc.cluster.local",
    "hosts": [
        "sidecar.monitoring.svc.cluster.local",
        "sidecar.antonputra.com"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "Los Banos"
        }
    ]
}
```

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=demo sidecar-csr.json | cfssljson -bare sidecar

show certificate and key

create `querier-csr.json`
```json
{
    "CN": "querier",
    "hosts": [
        "querier"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "Los Banos"
        }
    ]
}
```

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=demo querier-csr.json | cfssljson -bare querier

create `storegateway-csr.json`
```json
{
    "CN": "storegateway.monitoring.svc.cluster.local",
    "hosts": [
        "storegateway.monitoring.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "ST": "CA",
            "L": "Los Banos"
        }
    ]
}
```

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=demo storegateway-csr.json | cfssljson -bare storegateway

go over all certificates

create `prometheus/7-sidecar-tls.yaml`
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: sidecar-tls
type: kubernetes.io/tls
stringData:
  tls.crt:
  tls.key:
  ca.crt:
```

update `prometheus/3-prometheus.yaml`
```yaml
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

create `thanos/7-querier-tls.yaml`
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: querier-tls
type: kubernetes.io/tls
stringData:
  tls.crt:
  tls.key:
  ca.crt:
```

update `thanos/1-querier-deployment.yaml`
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

create `8-storegateway-tls.yaml`
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: storegateway-tls
type: kubernetes.io/tls
stringData:
  tls.crt:
  tls.key:
  ca.crt:
```

update `3-storegateway-sts.yaml`
```yaml
            - --grpc-server-tls-cert=/secrets/tls.crt
            - --grpc-server-tls-key=/secrets/tls.key
            - --grpc-server-tls-client-ca=/secrets/ca.crt

            - name: storegateway-tls
              mountPath: /secrets

        - name: storegateway-tls
          secret:
            secretName: storegateway-tls
```

kubectl apply -f prometheus
kubectl get secrets -n monitoring
kubectl get pods -n monitoring

kubectl apply -f thanos
kubectl get secrets -n monitoring
kubectl get pods -n monitoring

kubectl logs -l app.kubernetes.io/name=querier -n monitoring -f
kubectl port-forward svc/querier 9090 -n monitoring
