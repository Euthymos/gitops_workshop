# LAB_02 - BONUS: ConfigMaps a volumes

## Cieľ

* pochopiť, čo je **Job** (jednorazový / batch task),
* vedieť skontrolovať stav Jobu a jeho podu,
* vidieť rozdiel medzi **zlyhaným podom** a **zlyhaným Jobom**,
* použiť **CronJob** na pravidelné spúšťanie Jobov,
* vedieť CronJob **pozastaviť**, **obnoviť** a **upratať po ňom**.

## Predpoklady

Použi ten istý klaster a namespace:

```bash
minikube start
kubectl create namespace workshop-02  # ak ešte neexistuje
kubectl config set-context --current --namespace=workshop-02
kubectl get ns
kubectl config current-context
```

---

## Cvičenie 8 – Jednorazový Job: „Hello from Job“

### Krok 1 – vytvor manifest Jobu

1. Vytvor súbor `job-hello.yaml`:

   ```yaml
   apiVersion: batch/v1
   kind: Job
   metadata:
     name: job-hello
     namespace: workshop-02
   spec:
     backoffLimit: 3
     template:
       metadata:
         labels:
           app: job-hello
       spec:
         containers:
           - name: job
             image: busybox:1.36
             command:
               - sh
               - -c
               - |
                 echo "Hello from Kubernetes Job";
                 date;
                 echo "Sleeping for a few seconds...";
                 sleep 5;
                 echo "Job finished.";
         restartPolicy: Never
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f job-hello.yaml
   ```

---

### Krok 2 – sleduj stav Jobu a podu

1. Zobraz Job:

   ```bash
   kubectl get jobs
   ```

2. Zobraz pody vytvorené týmto Jobom:

   ```bash
   kubectl get pods -l job-name=job-hello
   ```

3. Sleduj, kým sa pod nedostane do stavu `Completed`:

   ```bash
   kubectl get pods -l job-name=job-hello -w
   ```

---

### Krok 3 – skontroluj logy Jobu

1. Zobraz logy podu Jobu:

   ```bash
   kubectl logs -l job-name=job-hello
   ```

2. Over, že sa v logoch nachádza výpis:

   * „Hello from Kubernetes Job“
   * `date`
   * „Job finished.“

---

## Cvičenie 9 – Job, ktorý zlyháva (backoff, failed)

### Krok 1 – vytvor Job, ktorý padne

1. Vytvor súbor `job-fail.yaml`:

   ```yaml
   apiVersion: batch/v1
   kind: Job
   metadata:
     name: job-fail
     namespace: workshop-02
   spec:
     backoffLimit: 3
     template:
       metadata:
         labels:
           app: job-fail
       spec:
         containers:
           - name: job
             image: busybox:1.36
             command:
               - sh
               - -c
               - |
                 echo "This job will fail";
                 exit 1
         restartPolicy: Never
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f job-fail.yaml
   ```

---

### Krok 2 – sleduj stav zlyhávajúceho Jobu

1. Sleduj Job:

   ```bash
   kubectl get jobs -w
   ```

2. Sleduj pody:

   ```bash
   kubectl get pods -l job-name=job-fail -w
   ```

3. Keď Job skončí, zobraz jeho detail:

   ```bash
   kubectl describe job job-fail
   ```

4. Zobraz logy posledného podu:

   ```bash
   kubectl logs -l job-name=job-fail
   ```

---

### Krok 3 – oprav Job a znova ho spusti

1. Zmeň príkaz v `job-fail.yaml` tak, aby Job skončil úspešne, napr.:

   ```yaml
   command:
     - sh
     - -c
     - |
       echo "Fixed job";
       date;
       exit 0
   ```

2. Zmaž starý Job a jeho pody:

   ```bash
   kubectl delete job job-fail
   ```

3. Znova aplikuj upravený manifest:

   ```bash
   kubectl apply -f job-fail.yaml
   ```

4. Over, že nový Job skončí v stave `COMPLETIONS 1/1`:

   ```bash
   kubectl get jobs
   kubectl get pods -l job-name=job-fail
   ```

---

## Cvičenie 10 – CronJob: pravidelné spúšťanie Jobov

### Krok 1 – vytvor CronJob, ktorý loguje čas

1. Vytvor súbor `cronjob-time.yaml`:

   ```yaml
   apiVersion: batch/v1
   kind: CronJob
   metadata:
     name: cron-time
     namespace: workshop-02
   spec:
     schedule: "*/1 * * * *"  # každú minútu
     concurrencyPolicy: Forbid
     successfulJobsHistoryLimit: 3
     failedJobsHistoryLimit: 1
     jobTemplate:
       spec:
         template:
           metadata:
             labels:
               app: cron-time
           spec:
             containers:
               - name: job
                 image: busybox:1.36
                 command:
                   - sh
                   - -c
                   - |
                     echo "CronJob run at $(date)";
                     sleep 5;
                     echo "CronJob finished.";
             restartPolicy: Never
   ```

2. Aplikuj CronJob:

   ```bash
   kubectl apply -f cronjob-time.yaml
   ```

3. Over, že CronJob existuje:

   ```bash
   kubectl get cronjobs
   ```

---

### Krok 2 – sleduj vytvárané Jobs a pody

1. Počkaj pár minút a sleduj Jobs:

   ```bash
   kubectl get jobs -l app=cron-time
   ```

2. Zobraz pody vytvorené CronJobom:

   ```bash
   kubectl get pods -l app=cron-time
   ```

3. Zobraz logy jedného z podov:

   ```bash
   kubectl logs <POD_CRON_TIME>
   ```

4. Over, že v logoch vidíš rôzne časy spustenia (`CronJob run at ...`).

---

### Krok 3 – pozastav CronJob a skontroluj, že nebeží

1. Pozastav CronJob:

   ```bash
   kubectl patch cronjob cron-time -p '{"spec":{"suspend":true}}'
   ```

2. Over, že je `SUSPEND` nastavené na `True`:

   ```bash
   kubectl get cronjob cron-time -o wide
   ```

3. Počkaj niekoľko minút a sleduj, či pribúdajú nové Jobs:

   ```bash
   kubectl get jobs -l app=cron-time
   ```

   *(Nemali by pribúdať nové.)*

---

### Krok 4 – obnov CronJob a následne uprac

1. Obnov CronJob:

   ```bash
   kubectl patch cronjob cron-time -p '{"spec":{"suspend":false}}'
   ```

2. Over, že `SUSPEND` je `False`:

   ```bash
   kubectl get cronjob cron-time -o wide
   ```

3. Počkajte, kým pribudne aspoň jeden nový Job:

   ```bash
   kubectl get jobs -l app=cron-time
   ```

4. Odstráň CronJob aj Jobs, keď už nepotrebuješ ďalšie behy:

   ```bash
   kubectl delete cronjob cron-time
   kubectl delete job -l app=cron-time
   ```

---

## Cvičenie 11 – ConfigMap ako zdroj HTML stránky (mount ako volume)

### Krok 1 – vytvor lokálny HTML súbor

1. Vytvor súbor `custom-index.html` (na svojom stroji):

   ```bash
   cat > custom-index.html << 'EOF'
   <!DOCTYPE html>
   <html>
   <head>
     <meta charset="UTF-8" />
     <title>ConfigMap demo</title>
   </head>
   <body>
     <h1>ConfigMap + Volume lab</h1>
     <p>Tento obsah pochádza z Kubernetes ConfigMap.</p>
   </body>
   </html>
   EOF
   ```

### Krok 2 – vytvor ConfigMap z tohto súboru

1. Vytvor ConfigMap `web-content` v namespaci `workshop-02`:

   ```bash
   kubectl create configmap web-content \
     --from-file=index.html=custom-index.html
   ```

2. Over, že ConfigMap existuje:

   ```bash
   kubectl get configmap web-content
   kubectl describe configmap web-content
   ```

---

### Krok 3 – vytvor Deployment, ktorý mountuje ConfigMap ako volume

Použi jednoduchý nginx, aby bolo ľahko vidieť zmenu HTML:

1. Vytvor `cm-deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: cm-web
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: cm-web
     template:
       metadata:
         labels:
           app: cm-web
       spec:
         containers:
           - name: web
             image: nginx:1.27-alpine
             ports:
               - containerPort: 80
             volumeMounts:
               - name: web-content
                 mountPath: /usr/share/nginx/html/index.html
                 subPath: index.html
       volumes:
         - name: web-content
           configMap:
             name: web-content
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f cm-deployment.yaml
   ```

3. Over stav podu:

   ```bash
   kubectl get pods -l app=cm-web
   kubectl describe pod -l app=cm-web
   ```

---

### Krok 4 – vytvor Service a otvor stránku v prehliadači

1. Vytvor súbor `cm-service.yaml`:

   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: cm-web
     namespace: workshop-02
   spec:
     type: NodePort
     selector:
       app: cm-web
     ports:
       - port: 80
         targetPort: 80
         protocol: TCP
   ```

2. Aplikuj Service:

   ```bash
   kubectl apply -f cm-service.yaml
   ```

3. Over Service:

   ```bash
   kubectl get svc cm-web
   ```

4. Otvor stránku v prehliadači:

   ```bash
   minikube service cm-web -n workshop-02
   ```

5. Over, že sa zobrazí HTML obsah z ConfigMap („ConfigMap + Volume lab“).


## Cvičenie 12 – ConfigMap + environment variables a emptyDir volume

V tejto časti:

* použiješ ConfigMap aj ako **environment variables**,
* použiješ **emptyDir volume** pre dočasné logy.

### Krok 1 – vytvor ConfigMap s konfiguračnými hodnotami

1. Vytvor ConfigMap `app-config` z literálov:

   ```bash
   kubectl create configmap app-config \
     --from-literal=APP_MODE=demo \
     --from-literal=APP_VERSION=1.0.0
   ```

2. Over:

   ```bash
   kubectl get configmap app-config
   kubectl describe configmap app-config
   ```

---

### Krok 2 – vytvor Deployment, ktorý používa ConfigMap ako env vars a emptyDir volume

Použijeme `busybox`, ktorý:

* vytlačí environment premenné,
* zapisuje niečo do `/var/log/app`,
* chvíľu beží.

1. Vytvor `env-emptydir-deployment.yaml`:

   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: env-emptydir-app
     namespace: workshop-02
   spec:
     replicas: 1
     selector:
       matchLabels:
         app: env-emptydir-app
     template:
       metadata:
         labels:
           app: env-emptydir-app
       spec:
         containers:
           - name: app
             image: busybox:1.36
             command:
               - sh
               - -c
               - |
                 echo "APP_MODE=$APP_MODE" | tee -a /var/log/app/app.log;
                 echo "APP_VERSION=$APP_VERSION" | tee -a /var/log/app/app.log;
                 echo "Running..."; sleep 3600
             envFrom:
               - configMapRef:
                   name: app-config
             volumeMounts:
               - name: app-logs
                 mountPath: /var/log/app
       volumes:
         - name: app-logs
           emptyDir: {}
   ```

2. Aplikuj manifest:

   ```bash
   kubectl apply -f env-emptydir-deployment.yaml
   ```

3. Over, že pod beží:

   ```bash
   kubectl get pods -l app=env-emptydir-app
   ```

---

### Krok 3 – skontroluj environment a logy v pod-e

1. Vstúp do podu:

   ```bash
   kubectl exec -it <ENV_EMPTYDIR_POD> -- sh
   ```

2. Vo vnútri kontajnera skontroluj environment premenné:

   ```sh
   env | grep APP_
   ```

3. Skontroluj obsah log súboru (v emptyDir volume):

   ```sh
   ls -R /var/log/app
   cat /var/log/app/app.log
   ```

4. Z kontajnera vystúp (`exit`).
