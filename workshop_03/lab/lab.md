# Workshop: Kubernetes Service + debugging + Ingress (minikube, kubectl, helm)

### Cieľ

Cieľom cvičení so Service a Ingress je naučiť sa, ako správne sprístupniť aplikácie bežiace v podoch – najprv vnútri klastra (ClusterIP), potom zvonka (NodePort / LoadBalancer) a nakoniec cez Ingress s HTTP pravidlami. Účastníci si vyskúšajú, ako Service mapuje traffic na konkrétne pody, ako diagnostikovať typické chyby (chýbajúce Endpoints, zlý port, zlý selector) a ako Ingress Controller routuje požiadavky na viaceré služby podľa URL cesty.

### Predpoklady

* Nainštalované: `kubectl`, `minikube`, `helm`
* Bežiaci minikube klaster
* Prístup na internet (na stiahnutie image `docker.io/euthymos/vue-nginx-demo:0.1`)

---

## Cvičenie 0 - príprava klastra a namespace `workshop-02`

1. Spusti minikube klaster:

   ```bash
   minikube start
   ```

2. Over stav klastra:

   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

3. Vytvor namespace `workshop-03`:

   ```bash
   kubectl create namespace workshop-03
   ```

4. Nastav namespace `workshop-03` ako východzí pre aktuálny kontext:

   ```bash
   kubectl config set-context --current --namespace=workshop-03
   ```

5. Over, že namespace existuje a je nastavený:

   ```bash
   kubectl get namespaces
   kubectl config get-contexts
   ```

---

## Cvičenie 1 – základný Service pre vue-nginx-demo

### Cieľ

* nasadiť Deployment s `docker.io/euthymos/vue-nginx-demo:0.1`
* vytvoriť Service a overiť prístup cez browser

### Krok 1 – Deployment

`vue-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vue-web
  namespace: workshop-03
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vue-web
  template:
    metadata:
      labels:
        app: vue-web
    spec:
      containers:
        - name: web
          image: docker.io/euthymos/vue-nginx-demo:0.1
          ports:
            - containerPort: 8080
```

Aplikuj:

```bash
kubectl apply -f vue-deployment.yaml
kubectl get pods -l app=vue-web -o wide
```

### Krok 2 – Service (NodePort)

`vue-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vue-web
  namespace: workshop-03
spec:
  type: NodePort
  selector:
    app: vue-web
  ports:
    - port: 8080        # port služby
      targetPort: 8080  # port v kontajneri
      protocol: TCP
```

Aplikuj:

```bash
kubectl apply -f vue-service.yaml
kubectl get svc vue-web
```

### Krok 3 – over prístup cez browser

```bash
minikube service vue-web -n workshop-03
```

---

## Cvičenie 2 – Service nemá Endpoints (zlý selector)

### Cieľ

* vidieť Service bez Endpoints
* naučiť sa používať `kubectl get endpoints` / `describe svc`

### Krok 1 – chybný Service selector

`vue-service-badselector.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vue-web-bad
  namespace: workshop-03
spec:
  type: ClusterIP
  selector:
    app: vue-web-typo   # úmyselná chyba
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
```

```bash
kubectl apply -f vue-service-badselector.yaml
kubectl get svc vue-web-bad
kubectl get endpoints vue-web-bad
```

Očakávaj `Endpoints: <none>`.

Oprav selector na `app: vue-web`, znovu apply a skontroluj `kubectl get endpoints vue-web-bad`.

---

## Cvičenie 3 – port mismatch (targetPort ≠ containerPort)

### Cieľ

* zažiť problém, keď `targetPort` nesedí na port v kontajneri

### Krok 1 – chybná Service

`vue-service-wrongport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vue-web-wrongport
  namespace: workshop-03
spec:
  type: ClusterIP
  selector:
    app: vue-web
  ports:
    - port: 80          # port služby
      targetPort: 80    # NESPRÁVNE, kontajner počúva na 8080
      protocol: TCP
```

```bash
kubectl apply -f vue-service-wrongport.yaml
kubectl get svc vue-web-wrongport
```

### Krok 2 – test z iného podu

```bash
kubectl run tester --image=busybox:1.36 -it --restart=Never -n workshop-03 -- sh
```

Vnútri podu:

```sh
wget -qO- http://vue-web-wrongport:80 || echo "request failed"
```

Očakávaj fail.

Oprav Service takto:

```yaml
ports:
  - port: 80
    targetPort: 8080
```

Apply:

```bash
kubectl apply -f vue-service-wrongport.yaml
```

Znova v `tester`:

```sh
wget -qO- http://vue-web-wrongport:80 | head -n 5
```

---

## Cvičenie 4 – httpd pod s ConfigMap a vlastnou Service

### Cieľ

* druhá HTTP app, ktorá servuje `index.html` z ConfigMap
* pripraviť si druhý backend pre Ingress

### Krok 1 – ConfigMap s HTML

```bash
cat > httpd-index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>HTTPD ConfigMap demo</title>
</head>
<body>
  <h1>Vitajte na GitOps workshope pre OSK MV SR!</h1>
  <p>Tento obsah je servovaný z Apache httpd a pochádza z ConfigMap.</p>
</body>
</html>
EOF
```

```bash
kubectl create configmap httpd-content \
  --from-file=index.html=httpd-index.html \
  -n workshop-03
```

### Krok 2 – Deployment httpd

`httpd-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpd-web
  namespace: workshop-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpd-web
  template:
    metadata:
      labels:
        app: httpd-web
    spec:
      containers:
        - name: web
          image: httpd:2.4-alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: httpd-content
              mountPath: /usr/local/apache2/htdocs/index.html
              subPath: index.html
      volumes:
        - name: httpd-content
          configMap:
            name: httpd-content
```

```bash
kubectl apply -f httpd-deployment.yaml
kubectl get pods -l app=httpd-web -n workshop-03
```

### Krok 3 – Service pre httpd

`httpd-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: httpd-web
  namespace: workshop-03
spec:
  type: ClusterIP
  selector:
    app: httpd-web
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
```

```bash
kubectl apply -f httpd-service.yaml
kubectl get svc httpd-web -n workshop-03
```

Test z tester podu:

```bash
kubectl exec -it tester -n workshop-03 -- sh
wget -qO- http://httpd-web:80 | head -n 5
```

---

## BONUS – Ingress Controller cez Helm + Ingress pravidlá

### Cvičenie 5 – inštalácia Ingress Controller-a cez Helm

### Krok 1 – Helm repo

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

### Krok 2 – inštalácia ingress-nginx

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

Over:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

---

## Cvičenie 6 – Ingress pravidlá pre vue-web a httpd-web

### Cieľ

* nakonfigurovať Ingress, ktorý smeruje:

  * `/vue` → Service `vue-web`
  * `/httpd` → Service `httpd-web`

### Krok 1 – zisti adresu Ingress Controllera

```bash
kubectl get svc -n ingress-nginx
minikube ip
```

Zober IP z `minikube ip` a port podľa typu služby `ingress-nginx-controller` (LoadBalancer/NodePort).

### Krok 2 – Ingress resource

`apps-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apps-ingress
  namespace: workshop-03
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /vue(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: vue-web
                port:
                  number: 8080
          - path: /httpd(/|$)(.*)
            pathType: Prefix
            backend:
              service:
                name: httpd-web
                port:
                  number: 80
```

Aplikuj:

```bash
kubectl apply -f apps-ingress.yaml
kubectl get ingress -n workshop-03
```

### Krok 3 – test

Z hosta (alebo cez curl):

```bash
curl http://<INGRESS_IP_OR_NODEIP>/vue | head -n 5
curl http://<INGRESS_IP_OR_NODEIP>/httpd | head -n 5
```

Alebo v prehliadači:

* `http://<INGRESS_IP_OR_NODEIP>/vue`
* `http://<INGRESS_IP_OR_NODEIP>/httpd`

---
