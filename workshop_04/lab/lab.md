# LAB_04: Helm charts a Tekton pipelines

### Cieľ

Prvá časť tohto workshopu je zameraná na zoznámenie sa s helm chartami, prácou s `values` a s nasadením aplikácie na kubernetes klaster pomocou helmu.
V druhej časti workshopu budeme pracovať s Tekton pipelines ako našim CI nástrojom. Predstavíme si základné stavebné bloky Tekton pipelines a triggers a ukážeme si, ako spustiť pipeline automaticky pomocou git webhookov.

### Predpoklady

* Nainštalované: `minikube`, `kubectl`, `helm`, `tkn`
* Prístup na internet (na stiahnutie image `quay.io/euthymos/todos-api:latest`)

---

## Cvičenie 0 – Príprava klastra a namespace `workshop-04`

1. Spusti minikube klaster:

   ```bash
   minikube start
   ```

2. Over stav klastra:

   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

3. Vytvor namespace `workshop-04`:

   ```bash
   kubectl create namespace workshop-04
   ```

4. Nastav namespace `workshop-04` ako východzí pre aktuálny kontext:

   ```bash
   kubectl config set-context --current --namespace=workshop-04
   ```

5. Over, že namespace existuje a je nastavený:

   ```bash
   kubectl get namespaces
   kubectl config get-contexts
   ```

---

## Cvičenie 1 – Zoznámenie sa s helm chartom, dependecies

### Krok 1 – Preskúmaj obsah adresára `./todo-api/helm`

1. Vojdi do adresára `./todo-api/helm`:

    ```bash
    cd ./todo-api/helm
    ```

2. Prečítaj súbor `Chart.yaml` a všimni si sekciu `dependencies:`:

    ```bash
    cat Chart.yaml
    ```

    ```yaml
    dependencies:
      - name: mongodb
        version: 15.6.0
        repository: https://charts.bitnami.com/bitnami
    ```

3. Prečítaj súbor `values.yaml` a všimni si sekciu `image:`:

    ```bash
    cat values.yaml
    ```

    ```yaml
    image:
      repository: quay.io/euthymos/todos-api
      tag: "latest"
      pullPolicy: IfNotPresent
    ```

4. Prečítaj súbor `values-dev.yaml` a všimni si sekciu `image:`:

    ```bash
    cat values-dev.yaml
    ```

5. Vypíš obsah adresára `templates`, otvor v ňom súbor `deployment.yaml` a všimni si sekciu `containers:`:

    ```bash
    ls templates\
    cat templates/deployment.yaml
    ```

    ```yaml
    containers:
      - name: api
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
    ```

### Krok 2 – Build dependency

1. V predchádzajúcom kroku sme zistili, že aplikácia `todos-api` je závislá na balíčku `mongodb`. Skôr, než nasadíme aplikáciu pomocou `helm`, musíme vyriešiť závislosti.

    ```bash
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm dependency build
    ```

2. Over, že do adresára `charts/` sa stiahol správny balíček:

    ```bash
    ls charts/
    ```

### Krok 3 – Nasaď aplikáciu v namespace `workshop-04`

1. Pre nasadenie aplikácie použijeme príkaz `helm install`. Pri nasadzovaní sa použijú predvolené hodnoty zo súbora `values.yaml`:

    ```bash
    helm install todos-api . -n workshop-04
    ```

### Krok 4 – Over úspešné nasadenie aplikácie

1. Zobraz zdroje v namespace `workshop-04`:

    ```bash
    kubectl get all -n workshop-04
    ```

---

## Cvičenie 2 – Nasaď development inštanciu aplikácie

### Krok 1 - Nasaď aplikáciu v namespace `workshop-04-dev`

1. Vytvor namespace `workshop-04-dev`

    ```bash
    kubectl create namespace workshop-04-dev
    ```

2. Pre nasadenie aplikácie použijeme príkaz `helm install`. Pri nasadzovaní sa použijú predvolené hodnoty doplnené či prepísané hodnotami zo súbora `values-dev.yaml`:

    ```bash
    helm install todos-api . \
      -f values-dev.yaml \
      -n workshop-04-dev
    ```

3. Over nasadenie aplikácie

    ```bash
    kubectl get all -n workshop-04-dev
    kubectl get ingress -n workshop-04-dev
    ```

### Krok 2 – Over úspešné nasadenie aplikácie

1. Zobraz zdroje v namespace `workshop-04-dev`:

    ```bash
    kubectl get all -n workshop-04-dev
    ```

2. Zisti IP adresu minikube klastra a pridaj tieto aliasy do súboru /etc/hosts

    ```bash
    MINIKUBE_IP=$(minikube ip)
    sudo echo "${MINIKUBE_IP} todos.local" >> /etc/hosts
    sudo echo "${MINIKUBE_IP} todos-dev.local" >> /etc/hosts
    ```

3. Over dostupnosť backendu prostredníctvom curl príkazu zadaného z príkazového riadku hosta

    ```bash
    curl http://todos.local/version | jq
    curl http://todos-dev.local/version | jq
    ```

---

## Cvičenie 3 – Nasaď novú verziu aplikácie a následne vráť zmeny

### Krok 1 - Nasaď novú verziu

1. Zmeň verziu chartu a aplikácie v `Chart.yaml`.

2. Spusti `helm upgrade:

    ```bash
    helm upgrade todos-api-dev . -n workshop-04-dev
    ```

### Krok 2 – Over nasadenie aplikácie

1. Zobraz zdroje v namespace `workshop-04-dev`:

    ```bash
    kubectl get all -n workshop-04-dev
    ```

2. Over dostupnosť backendu prostredníctvom curl príkazu zadaného z príkazového riadku hosta:

    ```bash
    curl http://todos-dev.local/version | jq
    ```

### Krok 3 – Vráť sa k predchádzajúcej verzii aplikácie

1. Nasaď prvú revíziu helm chartu:

    ```bash
    helm rollback todos-api-dev 1 -n workshop-04-dev
    ```

2. Zobraz zdroje v namespace `workshop-04-dev`:

    ```bash
    kubectl get all -n workshop-04-dev
    ```

3. Over dostupnosť backendu prostredníctvom curl príkazu zadaného z príkazového riadku hosta:

    ```bash
    curl http://todos-dev.local/version | jq
    ```

---

## Cvičenie 4 – Priprav klaster na prácu s tekton pipelines a git webhooks

### Krok 1 - Spusti `make up` z adresára `cicd/`

1. Prejdi do adresára `cicd\` a otvor súbor `makefile`:

    ```bash
    cd ../../cicd
    cat makefile
    ```

2. Prezri si skripty v adresári `scripts`:

    ```bash
    helm upgrade todos-api-dev . -n workshop-04-dev
    ```

   Poznámka: Skripty spustia minikube klaster, ak ešte nebeží, povolia doplnok, ktorý vytvorý lokálny docker register na klastri, nainštalujú tekton, nainštaluje git repozitár z helmu balíčka `gitea`, aplikujú príslušné deklarácie a vypíše adresy jednotlivých služieb.

3. Spusti príkaz `make up`:

    ```bash
    make up
    ```

4. Over výsledok skriptov:

    ```bash
    make verify
    ```

---

## Cvičenie 5 – Vytvor git repozitáre, vygeneruj token a nastav webhook cez gitea UI

### Krok 1 - Vytvor repozitáre pre aplikáciu a helm chart

1. Vo webovom prehliadači otvor gitea UI na adrese http://gitea.local


2. Prezri si skripty v adresári `scripts`:

    ```bash
    helm upgrade todos-api-dev . -n workshop-04-dev
    ```

   Poznámka: Skripty spustia minikube klaster, ak ešte nebeží, povolia doplnok, ktorý vytvorý lokálny docker register na klastri, nainštalujú tekton, nainštaluje git repozitár z helmu balíčka `gitea`, aplikujú príslušné deklarácie a vypíše adresy jednotlivých služieb.

3. Spusti príkaz `make up`:

    ```bash
    make up
    ```

4. Over výsledok skriptov:

    ```bash
    make verify
    ```
