# LAB_02: Deklaratívny deployment + troubleshooting a health monitoring

### Cieľ

Cieľom cvičení je naučiť sa používať Kubernetes deklaratívnym spôsobom – vytvárať a upravovať Deployment
a Service pomocou YAML manifestov – a zároveň získať istotu v základnom troubleshootingu a monitoringu health stavu klastra
a podov cez minikube a kubectl (sledovanie stavov, čítanie logov, interpretácia udalostí v namespaci workshop-02).

### Predpoklady

* Nainštalované: `minikube`, `kubectl`
* Prístup na internet (na stiahnutie image `docker.io/euthymos/vue-nginx-demo:0.1`)

---

## Cvičenie 0 – príprava klastra a namespace `workshop-02`

1. Spusti minikube klaster:

   ```bash
   minikube start
   ```

2. Over stav klastra:

   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

3. Vytvor namespace `workshop-02`:

   ```bash
   kubectl create namespace workshop-02
   ```

4. Nastav namespace `workshop-02` ako východzí pre aktuálny kontext:

   ```bash
   kubectl config set-context --current --namespace=workshop-02
   ```

5. Over, že namespace existuje a je nastavený:

   ```bash
   kubectl get namespaces
   kubectl config get-contexts
   ```

---

## Cvičenie 1 – deklaratívny deployment a Service

### Krok 1 – vytvor manifest `deployment.yaml`

1. Vytvor súbor `deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: demo-app
     namespace: workshop-02
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: demo-app
     template:
       metadata:
         labels:
           app: demo-app
       spec:
         containers:
           - name: web
             image: docker.io/euthymos/vue-nginx-demo:0.1
             ports:
               - containerPort: 8080
   ```

### Krok 2 – aplikuj deployment

1. Aplikuj manifest:

   ```bash
   kubectl apply -f deployment.yaml
   ```

2. Over, že deployment existuje:

   ```bash
   kubectl get deployments
   ```

3. Over, že pody bežia:

   ```bash
   kubectl get pods -o wide
   ```

---

### Krok 3 – vytvor manifest `service.yaml`

1. Vytvor súbor `service.yaml`:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: demo-app
     namespace: workshop-02
   spec:
     type: NodePort
     selector:
       app: demo-app
     ports:
       - port: 8080        # port služby
         targetPort: 8080  # port v kontajneri
         protocol: TCP
   ```

2. Aplikuj Service:

   ```bash
   kubectl apply -f service.yaml
   ```

3. Over, že Service beží:

   ```bash
   kubectl get svc
   ```

---

### Krok 4 – prístup na web rozhranie

1. Zobraz služby v namespaci:

   ```bash
   kubectl get svc
   ```

2. Otvor službu v prehliadači cez `minikube`:

   ```bash
   minikube service demo-app -n workshop-02
   ```

3. Over, že sa v prehliadači zobrazí webová stránka aplikácie.

---

## Cvičenie 2 – health status monitoring (klaster + pody)

### Krok 1 – základný prehľad o klastri

1. Zobraz stav node-ov:

   ```bash
   kubectl get nodes -o wide
   ```

2. Zobraz všetky namespaces:

   ```bash
   kubectl get ns
   ```

3. Zobraz všetky pody vo všetkých namespaces:

   ```bash
   kubectl get pods -A
   ```

4. Zobraz posledné udalosti v klastri:

   ```bash
   kubectl get events -A --sort-by=.lastTimestamp | tail -n 30
   ```

### Krok 2 – monitoring namespacu `workshop-02`

1. Zobraz všetky pody v `workshop-02`:

   ```bash
   kubectl get pods
   ```

2. Sleduj pody v reálnom čase (watch):

   ```bash
   kubectl get pods -w
   ```

3. Zobraz deployment a jeho repliky:

   ```bash
   kubectl get deploy demo-app -o wide
   ```

4. Zobraz detaily jedného konkrétneho podu:

   ```bash
   kubectl describe pod <NAZOV_PODU>
   ```

5. Zobraz logy kontajnera v pod-e:

   ```bash
   kubectl logs <NAZOV_PODU>
   ```

---

## Cvičenie 3 – troubleshooting: CrashLoopBackOff (chybný command)

### Krok 1 – vytvor chybný deployment (deklaratívne)

1. Vytvor súbor `deployment-crash.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: crash-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: crash-app
     template:
       metadata:
         labels:
           app: crash-app
       spec:
         containers:
           - name: app
             image: busybox:1.36
             command:
               - sh
               - -c
               - "echo 'Starting app'; sleep 5; exit 1"
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f deployment-crash.yaml
   ```

3. Zobraz pody v namespaci:

   ```bash
   kubectl get pods
   ```

   *(Očakávaj stav `CrashLoopBackOff`.)*

---

### Krok 2 – diagnostikuj problém

1. Zobraz detaily podu `crash-app`:

   ```bash
   kubectl describe pod <POD_CRASH_APP>
   ```

2. Zameraj sa na sekciu **Events** a spočítaj počet reštartov.

3. Zobraz logy kontajnera:

   ```bash
   kubectl logs <POD_CRASH_APP>
   ```

4. Identifikuj, čo spôsobuje pád kontajnera (exit 1 po 5 sekundách).

---

### Krok 3 – oprav deployment deklaratívne

1. Upravil manifest `deployment-crash.yaml` tak, aby kontajner nepadal, napr.:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: crash-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: crash-app
     template:
       metadata:
         labels:
           app: crash-app
       spec:
         containers:
           - name: app
             image: busybox:1.36
             command:
               - sh
               - -c
               - "echo 'Starting app'; sleep 3600"
   ```

2. Znovu aplikuj manifest:

   ```bash
   kubectl apply -f deployment-crash.yaml
   ```

3. Over, že pod je teraz v stave `Running` a RESTARTS sa už nezvyšuje:

   ```bash
   kubectl get pods
   kubectl describe pod <POD_CRASH_APP>
   ```

---

## Cvičenie 4 – troubleshooting: ImagePullBackOff (chybný image)

### Krok 1 – vytvor deployment s neexistujúcim image

1. Vytvor súbor `deployment-bad-image.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: bad-image-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: bad-image-app
     template:
       metadata:
         labels:
           app: bad-image-app
       spec:
         containers:
           - name: app
             image: docker.io/euthymos/vue-nginx-demo:nonexistent-tag
             ports:
               - containerPort: 8080
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f deployment-bad-image.yaml
   ```

3. Zobraz stav podu:

   ```bash
   kubectl get pods
   ```

   *(Očakávaj `ImagePullBackOff` alebo `ErrImagePull`.)*

---

### Krok 2 – zisti dôvod zlyhania

1. Zobraz detaily podu:

   ```bash
   kubectl describe pod <POD_BAD_IMAGE>
   ```

2. V sekcii **Events** nájdi chybové hlášky súvisiace s ťahaním image (`Failed to pull image`).

---

### Krok 3 – oprav image a znova nasadi

1. Upravil `deployment-bad-image.yaml` tak, aby používal existujúci tag:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: bad-image-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: bad-image-app
     template:
       metadata:
         labels:
           app: bad-image-app
       spec:
         containers:
           - name: app
             image: docker.io/euthymos/vue-nginx-demo:0.1
             ports:
               - containerPort: 8080
   ```

2. Aplikuj zmeny:

   ```bash
   kubectl apply -f deployment-bad-image.yaml
   ```

3. Over, že pod prejde do stavu `Running`:

   ```bash
   kubectl get pods
   ```

---

## Cvičenie 5 – Pending pod (nedostatok zdrojov)

### Krok 1 – vytvor deployment s príliš veľkými resource requests

1. Vytvor súbor `deployment-pending.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: heavy-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: heavy-app
     template:
       metadata:
         labels:
           app: heavy-app
       spec:
         containers:
           - name: app
             image: docker.io/euthymos/vue-nginx-demo:0.1
             resources:
               requests:
                 cpu: "8"
                 memory: "16Gi"
             ports:
               - containerPort: 8080
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f deployment-pending.yaml
   ```

3. Zobraz pody v namespaci:

   ```bash
   kubectl get pods
   ```

   *(Očakávaj stav `Pending`.)*

---

### Krok 2 – zisti dôvod Pending stavu

1. Zobraz detaily podu `heavy-app`:

   ```bash
   kubectl describe pod <POD_HEAVY_APP>
   ```

2. Vyhľadaj v časti **Events** hlášky typu `Insufficient cpu` alebo `Insufficient memory`.

---

### Krok 3 – oprav resource requests a znova nasadi

1. Upravil manifest `deployment-pending.yaml` tak, aby žiadal realistické zdroje, napr.:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: heavy-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: heavy-app
     template:
       metadata:
         labels:
           app: heavy-app
       spec:
         containers:
           - name: app
             image: docker.io/euthymos/vue-nginx-demo:0.1
             resources:
               requests:
                 cpu: "100m"
                 memory: "128Mi"
             ports:
               - containerPort: 8080
   ```

2. Aplikuj zmeny:

   ```bash
   kubectl apply -f deployment-pending.yaml
   ```

3. Over, že pod prejde do stavu `Running`:

   ```bash
   kubectl get pods
   ```

4. Over v `describe`, že už nevidíš „Insufficient …“:

   ```bash
   kubectl describe pod <POD_HEAVY_APP>
   ```

---

## Cvičenie 6 – failing readiness/liveness probe

### Krok 1 – vytvor deployment s chybným readiness probe

1. Vytvor súbor `deployment-probes.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: probe-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: probe-app
     template:
       metadata:
         labels:
           app: probe-app
       spec:
         containers:
           - name: web
             image: docker.io/euthymos/vue-nginx-demo:0.1
             ports:
               - containerPort: 8080
             readinessProbe:
               httpGet:
                 path: /healthz
                 port: 8080
               initialDelaySeconds: 5
               periodSeconds: 5
             livenessProbe:
               httpGet:
                 path: /
                 port: 8080
               initialDelaySeconds: 10
               periodSeconds: 10
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f deployment-probes.yaml
   ```

3. Zobraz pody:

   ```bash
   kubectl get pods
   ```

   *(Očakávaj stav `Running`, ale READY = `0/1` alebo prechody medzi `0/1` a `1/1`.)*

---

### Krok 2 – zisti dôvod failing readiness probe

1. Zobraz detaily podu `probe-app`:

   ```bash
   kubectl describe pod <POD_PROBE_APP>
   ```

2. V časti **Events** nájdi záznamy o neúspešných readiness probes (HTTP 404 na `/healthz`).

---

### Krok 3 – oprav readinessProbe a znova nasadi

1. Upravil manifest `deployment-probes.yaml` tak, aby readiness kontrolovala cestu `/` (ktorá vracia 200):

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: probe-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: probe-app
     template:
       metadata:
         labels:
           app: probe-app
       spec:
         containers:
           - name: web
             image: docker.io/euthymos/vue-nginx-demo:0.1
             ports:
               - containerPort: 8080
             readinessProbe:
               httpGet:
                 path: /
                 port: 8080
               initialDelaySeconds: 5
               periodSeconds: 5
             livenessProbe:
               httpGet:
                 path: /
                 port: 8080
               initialDelaySeconds: 10
               periodSeconds: 10
   ```

2. Aplikuj zmeny:

   ```bash
   kubectl apply -f deployment-probes.yaml
   ```

3. Over, že pod je READY `1/1`:

   ```bash
   kubectl get pods
   ```

4. Over v `describe`, že nové failing readiness events už nepribúdajú:

   ```bash
   kubectl describe pod <POD_PROBE_APP>
   ```

---

## Cvičenie 7 – finálny health check namespacu `workshop-02`

1. Zobraz všetky deploymenty v namespaci:

   ```bash
   kubectl get deploy
   ```

2. Zobraz všetky pody a ich stav:

   ```bash
   kubectl get pods -o wide
   ```

3. Zobraz Service a ich typy:

   ```bash
   kubectl get svc
   ```

4. Zobraz posledné udalosti len pre `workshop-02`:

   ```bash
   kubectl get events --sort-by=.lastTimestamp
   ```

5. Identifikuj, či niektorý pod nie je v stave `Running` / `Completed`, a podľa potreby použi:

   ```bash
   kubectl describe pod <NAZOV_PODU>
   kubectl logs <NAZOV_PODU>
   ```
