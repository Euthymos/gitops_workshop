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

4. Prečítaj súbor `dev.yaml` a všimni si sekciu `image:`:

    ```bash
    cat dev.yaml
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

1. Vytvor namespace `workshop-04-dev` a povoľ doplnok `ingress`

    ```bash
    kubectl create namespace workshop-04-dev
    minikube addons enable ingress
    ```

2. Pre nasadenie aplikácie použijeme príkaz `helm install`. Pri nasadzovaní sa použijú predvolené hodnoty doplnené či prepísané hodnotami zo súbora `dev.yaml`:

    ```bash
    helm install todos-api . \
      -f dev.yaml \
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
    sudo chmod 774 ./scripts/*.sh
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

## Cvičenie 5 – Vytvor git repozitáre a vygeneruj token cez gitea UI

### Krok 1 - Vytvor repozitáre pre aplikáciu a helm chart

1. Vo webovom prehliadači otvor gitea UI na adrese http://gitea.local

2. Vytvor git repozitár `app-repo` pre aplikačný kód

3. Vytvor git repozitár `helm-repo` pre helm chart

### Krok 2 - Vygeneruj prístupový token

1. Vygeneruj prístupový token pre admin užívateľa. Klikni na ikonku užívateľa, z menu vyber `Settings` -> choď do Applications, vygeneruj a skopíruj token

2. Vlož token ako hodnotu premennej `GITEA_HTTP_TOKEN` v súbore `.env` a znovu spusti príkaz `make up`

### Krok 3 - Pushni obsah adresárov do vzdialených repozitárov

1. Inicializuj git repozitár v adresári `app-repo/`, sprav počiatočný commit a pushni ho do vzdialeného repozitára:

    ```bash
    cd app-repo/
    git config --global user.name "admin"
    git config --global user.email "admin@example.com"
    git init
    git checkout -b main
    git add .
    git commit -m "first commit"
    git remote add origin http://gitea.local/admin/app-repo.git
    git push -u origin main
    ```

2. Inicializuj git repozitár v adresári `helm-repo/`, sprav počiatočný commit a pushni ho do vzdialeného repozitára:

    ```bash
    cd ../helm-repo/
    git init
    git checkout -b main
    git add .
    git commit -m "first commit"
    git remote add origin http://gitea.local/admin/helm-repo.git
    git push -u origin main
    ```

## Cvičenie 6 – Spusti tekton pipeline ručne

### Krok 1 - Spusti tekton pipeline

1. Obozám sa s parametrami a workspaces definovanými v pipeline `app-ci-to-helm-update`:

    ```
    tkn pipeline describe -n cicd app-ci-to-helm
    ```

2. Aplikuj deklaráciu pipeline-run.yaml"

    ```bash
    kubectl apply -f ../../manifests/tekton/pipeline-run.yaml
    ```

3. Všimni si, s akými parametrami bola pipeline spustená:

    ```bash
    tkn pipelinerun describe -n cicd app-ci-manual-run
    ```

4. Sleduj priebeh behu pipeline:

    ```bash
    tkn pipelinerun logs -n cicd app-ci-manual-run -f
    ```

5. Over úspešné dokončenie behu pipeline"

    ```bash
    tkn pipeline list -n cicd
    ```

## Cvičenie 7 – Nasaď development inštanciu frontendu z vytvoreného kontajnerového image

### Krok 1 - Stiahni zmeny v repozitári `helm-repo`

1. Aktualizuj obsah adresára `helm_repo`:

    ```
    git pull
    ```

### Krok 2 - Nasaď frontend v namespace `workshop-04-dev`

1. Použi príkaz `helm install` a súbor s hodnotami `dev.yaml`:

    ```
    helm install -n workshop-04-dev todos-spa-dev . --values dev.yaml
    ```

2. Over úspešné nasadenie:

    ```
    kubectl get all -n workshop-04-dev
    ```

## Cvičenie 8 – Nastav webhook pre push do `main` branch a spusti pipeline commitom

### Krok 1 - Zisti URL pre git webhook

1. Pozri si popis `gitea-listener` tekton event listeneru:

    ```
    tkn eventlistener describe -n cicd gitea listener
    ```

2. Skopíruj hodnotu `URL:`

### Krok 2 - Vytvor webhook cez UI

1. Otvor `app-repo` v gitea UI, klikni na `Settings`

2. Z menu vyber `Webhooks`, klikni na `Add webhook`, to políčka `Target URL` vlož skopírovaný link a pridaj webhook.

    ```bash
    tkn pipelinerun logs -n cicd app-ci-manual-run -f
    ```

## Cvičenie 9 – Nasaď produkčnú inštanciu frontendu z vytvoreného image

### Krok 1 - Nasaď frontend v namespace `workshop-04`

1. Použi príkaz `helm install` a súbor s hodnotami `prod.yaml`:

    ```
    helm install -n workshop-04 todos-spa . --values prod.yaml
    ```

2. Over úspešné nasadenie:

    ```
    kubectl get all -n workshop-04
    ```

3. Otvor aplikáciu - do webového prehliadača zadaj adresu http://todos-spa.local
