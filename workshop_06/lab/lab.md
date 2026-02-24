# LAB_06: CI/CD + GitOps – Tekton Pipelines a ArgoCD na OpenShift Local (CRC)

### Cieľ

V tomto workshope spojíme CI (Tekton Pipelines) a CD (ArgoCD/GitOps) do jedného end-to-end toku na lokálnom OpenShift klastri (CRC). Administrátor nastaví klaster, operátory a infraštruktúru. Vývojár vytvorí pipeline, eventlistener a ArgoCD aplikáciu pre `greeter` aplikáciu z workshop_05.

Po `git push` do `app-repo`:
1. Tekton pipeline builduje kontajner a pushuje ho do interného OpenShift registra.
2. Pipeline aktualizuje `image.tag` v `gitops-infra` repozitári.
3. ArgoCD zaznamená zmenu a ponúkne manuálny sync.
4. Sync nasadí novú verziu greeter aplikácie.

### Predpoklady

* `crc start` – OpenShift Local klaster beží
* Nainštalované: `oc`, `tkn`, `helm`, `git`, `curl`, `jq`
* Internetové pripojenie (stiahnutie operátorov a obrazov)

---

## Cvičenie 0 – Príprava prostredia (admin)

### Krok 1 – Over stav CRC

1. Over, že CRC klaster beží:

    ```bash
    crc status
    ```

2. Prihlás sa ako admin:

    ```bash
    eval $(crc oc-env)
    oc login -u kubeadmin -p $(crc console --credentials | grep kubeadmin | awk '{print $NF}') https://api.crc.testing:6443
    ```

    Alebo použi výstup z:

    ```bash
    crc console --credentials
    ```

3. Over verziu a prístup:

    ```bash
    oc version
    oc get nodes
    oc get clusterversion
    ```

### Krok 2 – Prejdi do adresára `lab/` a priprav skripty

1. Prejdi do adresára `lab/` a nastav skripty:

    ```bash
    cd workshop_06/lab
    sudo chmod 774 ./scripts/*.sh
    ```

2. Skopíruj `.env.example` a vyplň premenné (token doplníš neskôr po nastavení Gitea):

    ```bash
    cp .env.example .env
    cat .env
    ```

3. Spusti admin prípravu klastra:

    ```bash
    make admin-up
    ```

    Príkaz vykoná skripty v tomto poradí:
    - `00-check.sh` – over prerekvizity
    - `10-install-operators.sh` – nainštaluj OpenShift Pipelines a GitOps operátory
    - `20-gitea-install.sh` – nainštaluj Gitea
    - `30-setup-namespaces.sh` – vytvor namespace-y a RBAC pre vývojára

4. Over výsledok:

    ```bash
    make verify
    ```

---

## Cvičenie 1 – Gitea: vytvor repozitáre a token

> Toto cvičenie vykonaj ako **admin** v Gitea UI.

### Krok 1 – Otvor Gitea UI

1. Zisti URL Gitea z:

    ```bash
    make info
    ```

2. Otvor Gitea vo webovom prehliadači (napr. `http://gitea-gitea.apps-crc.testing`).

3. Prihlás sa ako `gitea-admin` s heslom z `.env`.

### Krok 2 – Vytvor repozitáre

1. Vytvor prázdny repozitár `app-repo` (bez inicializácie):
    - Klikni na `+` → `New Repository`
    - Názov: `app-repo`
    - Ponechaj **bez** inicializácie (prázdny)

2. Vytvor prázdny repozitár `gitops-infra`:
    - Názov: `gitops-infra`
    - Inicializuj s `README.md` (zaškrtni Initialize this repository)
    - Default branch: `main`

### Krok 3 – Vygeneruj prístupový token

1. Klikni na ikonu profilu → `Settings` → `Applications`.

2. Sekcia **Manage Access Tokens**:
    - Token Name: `cicd-token`
    - Zaškrtni `write:repository` a `read:user`
    - Klikni **Generate Token** a skopíruj hodnotu.

3. Vlož token do súboru `.env` ako hodnotu `GITEA_HTTP_TOKEN`:

    ```bash
    # uprav .env
    nano .env
    ```

4. Znovu spusti admin nastavenie (dokončí CICD konfiguráciu):

    ```bash
    make cicd-up
    ```

---

## Cvičenie 2 – Pushni zdrojový kód do `app-repo`

> Toto cvičenie vykonaj ako **vývojár** (`developer`).

### Krok 1 – Prihlás sa ako developer

```bash
oc login -u developer -p developer https://api.crc.testing:6443
```

### Krok 2 – Inicializuj `app-repo`

1. Ulož cestu k `lab/` adresáru pre neskorší návrat a skopíruj zdrojový kód greeter aplikácie:

    ```bash
    LAB_DIR="$(pwd)"   # workshop_06/lab
    cp -r ../../apps/greeter/app /tmp/greeter-app
    cd /tmp/greeter-app
    ```

2. Inicializuj git repozitár a pushni ho do Gitea:

    ```bash
    git init
    git checkout -b main
    git add .
    git commit -m "feat: initial greeter app"
    git remote add origin http://gitea-gitea.apps-crc.testing/gitea-admin/app-repo.git
    git push -u origin main
    ```

    > Ak Gitea pýta prihlasovacie údaje, zadaj `gitea-admin` a heslo z `.env`.

### Krok 3 – Pushni helm chart do `gitops-infra`

Pipeline očakáva, že helm chart sa nachádza v podadresári `greeter/` repozitára `gitops-infra` (cesta `greeter/values.yaml`). Klonuj `gitops-infra` a skopíruj helm chart do správneho podadresára.

1. Klonuj `gitops-infra` a skopíruj helm chart:

    ```bash
    cd "${LAB_DIR}"
    git clone http://gitea-gitea.apps-crc.testing/gitea-admin/gitops-infra.git /tmp/gitops-infra
    mkdir -p /tmp/gitops-infra/greeter
    cp -r ../../apps/greeter/helm/. /tmp/gitops-infra/greeter/
    cd /tmp/gitops-infra
    ```

2. Skontroluj skopírované súbory:

    ```bash
    tree .
    cat greeter/values.yaml
    ```

3. Keďže nasadzuješ na OpenShift, uprav `greeter/values.yaml` a nastav:

    ```yaml
    exposure:
        type: route
    ```

4. Commitni a pushni:

    ```bash
    git add .
    git commit -m "feat: add greeter helm chart"
    git push origin main
    ```

5. Over obsah repozitára v Gitea UI.

---

## Cvičenie 3 – Preskúmaj Tekton manifesty (vývojár)

> Prihlás sa ako developer:

```bash
oc login -u developer -p developer https://api.crc.testing:6443
oc project workshop-06-cicd
```

### Krok 1 – Prezri si Tekton manifesty

1. Prezri si tasky definované v `manifests/tekton/tasks.yaml`:

    ```bash
    cd "${LAB_DIR}"
    cat manifests/tekton/tasks.yaml
    ```

    Vlastné tasky (definované v tomto projekte):
    - `buildah-build-push` – builduje kontajner a pushuje do OpenShift interného registra
    - `npm` – spúšťa ľubovoľný `npm` príkaz (install, run lint, run test) v `src/`

    Tasky z `openshift-pipelines` (referencované cez cluster resolver):
    - `git-clone` – klonuje git repozitár (použitý pre `app-repo` aj `gitops-infra`)
    - `git-cli` – spúšťa git príkazy zo skriptu (commit + push aktualizácie image tagu)

2. Prezri si pipeline definovanú v `manifests/tekton/pipeline.yaml`:

    ```bash
    cat manifests/tekton/pipeline.yaml
    ```

    Pipeline `greeter-ci` má 7 krokov:
    1. `clone` – klonuje `app-repo` do `src/` (git-clone z openshift-pipelines)
    2. `npm-install` – nainštaluje závislosti (`npm install`)
    3. `npm-lint` + `npm-test` – bežia **paralelne** po `npm-install`
    4. `build-push` – buildah build + push image do OCP registra (až po úspešnom lint aj test)
    5. `clone-infra` – klonuje `gitops-infra` do `infrarepo/` (git-clone z openshift-pipelines)
    6. `update-infra` – aktualizuje `image.tag` v `greeter/values.yaml` a pushuje (git-cli z openshift-pipelines)

3. Prezri si trigger manifesty:

    ```bash
    cat manifests/tekton/triggers.yaml
    ```

### Krok 2 – Aplikuj CICD manifesty (vykonaný automaticky, skontroluj)

```bash
oc get pipeline,eventlistener,triggerbinding,triggertemplate -n workshop-06-cicd
oc get pvc -n workshop-06-cicd
```

---

## Cvičenie 4 – Spusti pipeline ručne

> Toto cvičenie overí, že pipeline funguje pred nastavením webhookov.

### Krok 1 – Spusti pipeline-run

1. Pozri si parametre pipeline:

    ```bash
    tkn pipeline describe -n workshop-06-cicd greeter-ci
    ```

2. Aplikuj manuálny pipeline-run:

    ```bash
    oc apply -f manifests/tekton/pipeline-run.yaml -n workshop-06-cicd
    ```

3. Sleduj priebeh pipeline run:

    ```bash
    tkn pipelinerun logs -n workshop-06-cicd greeter-ci-manual-run -f
    ```

4. Over úspešné dokončenie:

    ```bash
    tkn pipelinerun list -n workshop-06-cicd
    ```

### Krok 2 – Over nový image v OpenShift registri

```bash
oc get imagestream -n workshop-06-cicd
oc describe imagestream greeter -n workshop-06-cicd
```

### Krok 3 – Over aktualizáciu `gitops-infra`

1. V Gitea UI otvor repozitár `gitops-infra` a skontroluj commit do `greeter/values.yaml`.

2. Alebo cez git lokálne:

    ```bash
    cd /tmp/gitops-infra && git pull
    cat greeter/values.yaml | grep tag
    ```

---

## Cvičenie 5 – Nastav ArgoCD aplikáciu

> Admin nakonfiguroval ArgoCD počas `make admin-up`. Vývojár teraz vytvorí projekt a aplikáciu.

### Krok 1 – Prihlás sa do ArgoCD UI

1. Zisti URL a prihlasovacie údaje ArgoCD:

    ```bash
    oc get route -n openshift-gitops openshift-gitops-server
    oc extract secret -n openshift-gitops openshift-gitops-cluster
    ```

2. Otvor ArgoCD vo webovom prehliadači.

### Krok 2 – Vytvor projekt v ArgoCD (cez UI)

1. V ľavom menu klikni na **Settings** → **Projects** → **New Project**.

2. Vyplň:
    - **Project Name:** `workshop-06`
    - **Description:** `Workshop 06 – Greeter app CI/CD + GitOps`

3. V sekcii **Source Repositories** pridaj:
    - `http://gitea-gitea.apps-crc.testing/gitea-admin/gitops-infra.git`

4. V sekcii **Destinations** pridaj:
    - **Server:** `https://kubernetes.default.svc`
    - **Namespace:** `workshop-06`

5. Klikni **Create**.

### Krok 3 – Vytvor aplikáciu v ArgoCD (cez UI)

1. Prejdi do **Applications** → **New App**.

2. Vyplň:
    - **Application Name:** `greeter`
    - **Project Name:** `workshop-06`
    - **Sync Policy:** `Manual`

3. **Source:**
    - **Repository URL:** `http://gitea-gitea.apps-crc.testing/gitea-admin/gitops-infra.git`
    - **Revision:** `main`
    - **Path:** `greeter`

4. **Destination:**
    - **Cluster URL:** `https://kubernetes.default.svc`
    - **Namespace:** `workshop-06`

5. **Helm** – nastav parameter `exposure.type=route` (alebo ponechaj predvolené, ak už máš `exposure.type: route` v `greeter/values.yaml`).

6. Klikni **Create**.

### Krok 4 – Manuálne synchronizuj aplikáciu

1. Klikni na aplikáciu `greeter` → **Sync** → **Synchronize**.

2. Over nasadenie:

    ```bash
    oc get all -n workshop-06
    oc get route -n workshop-06
    ```

3. Otvor aplikáciu vo webovom prehliadači (URL z `oc get route -n workshop-06`).

### Krok 5 – Alternatíva: aplikuj ArgoCD manifest priamo

Namiesto UI môžeš aplikovať manifesty:

```bash
oc apply -f manifests/argocd/project.yaml
oc apply -f manifests/argocd/application.yaml
```

---

## Cvičenie 6 – Nastav webhook a spusti end-to-end flow

### Krok 1 – Zisti URL EventListenera

1. Popis EventListenera:

    ```bash
    tkn eventlistener describe -n workshop-06-cicd greeter-listener
    ```

2. Zisti Route EventListenera:

    ```bash
    oc get route -n workshop-06-cicd
    ```

    Skopíruj URL vo formáte `http://el-greeter-listener-workshop-06-cicd.apps-crc.testing`.

### Krok 2 – Nastav webhook v Gitea

1. Otvor `app-repo` v Gitea UI.

2. Klikni na **Settings** → **Webhooks** → **Add Webhook** → **Gitea**.

3. Vyplň:
    - **Target URL:** URL EventListenera z predchádzajúceho kroku
    - **HTTP Method:** `POST`
    - **Content Type:** `application/json`
    - **Secret:** ponechaj prázdny

4. Klikni **Add Webhook**.

5. Otestuj webhook kliknutím na **Test delivery** – odpoveď by mala byť `200 OK`.

### Krok 3 – Spusti end-to-end flow commitom

1. Uprav zdrojový kód greeter aplikácie:

    ```bash
    cd /tmp/greeter-app
    echo "<!-- updated $(date) -->" >> index.html
    git add .
    git commit -m "feat: trigger pipeline via webhook"
    git push origin main
    ```

2. Sleduj spustenie pipeline:

    ```bash
    tkn pipelinerun list -n workshop-06-cicd
    tkn pipelinerun logs -n workshop-06-cicd -f --last
    ```

    Pipeline prejde cez všetky kroky: `clone` → `npm-install` → `npm-lint`/`npm-test` (paralelne) → `build-push` → `clone-infra` → `update-infra`.

3. Po dokončení overte aktualizáciu v `gitops-infra`:

    ```bash
    cd /tmp/gitops-infra && git pull
    cat greeter/values.yaml | grep tag
    ```

### Krok 4 – Sleduj Out of Sync v ArgoCD a synchronizuj

1. Otvor ArgoCD UI – aplikácia `greeter` zobrazuje stav **OutOfSync**.

    > Ak zmena ešte nie je viditeľná, klikni **Refresh**.

2. Klikni **Sync** → **Synchronize**.

3. Sleduj priebeh nasadenia – stav by sa mal zmeniť na **Synced** a **Healthy**.

4. Over, že nová verzia bola nasadená:

    ```bash
    oc get pods -n workshop-06
    oc describe pod -n workshop-06 -l app.kubernetes.io/name=greeter | grep Image:
    ```

5. Otvor aplikáciu vo webovom prehliadači a over zmenu.

---

## Cvičenie 7 – Preskúmaj Tekton Dashboard

### Krok 1 – Nainštaluj Tekton Dashboard (voliteľné, ak nie je súčasťou operátora)

OpenShift Pipelines operátor inštaluje dashboard automaticky. Skontroluj:

```bash
oc get route -n openshift-pipelines
```

### Krok 2 – Otvor Tekton Dashboard

1. Zisti URL dashboardu:

    ```bash
    oc get route tekton-dashboard -n openshift-pipelines -o jsonpath='{.spec.host}'
    ```

2. Otvor URL vo webovom prehliadači.

3. Preskúmaj:
    - Zoznam `PipelineRuns` v namespace `workshop-06-cicd`
    - Detail posledného `PipelineRun` – logy jednotlivých taskov
    - `EventListeners` a `TriggerBindings`

---

## Cvičenie 8 – Nastav automatickú synchronizáciu v ArgoCD (bonus)

### Krok 1 – Zapni Auto-Sync

1. V ArgoCD UI klikni na aplikáciu `greeter`.

2. Klikni na **App Details** → **Sync Policy** → **Enable Auto-Sync**.

3. Zaškrtni **Prune Resources** a **Self Heal**.

4. Klikni **Save**.

### Krok 2 – Over automatickú synchronizáciu

1. Spusti nový commit do `app-repo`:

    ```bash
    cd /tmp/greeter-app
    echo "<!-- auto sync test $(date) -->" >> index.html
    git add .
    git commit -m "test: auto-sync pipeline → argocd"
    git push origin main
    ```

2. Sleduj pipeline run (všetky fázy vrátane paralelného lint/test):

    ```bash
    tkn pipelinerun logs -n workshop-06-cicd -f --last
    ```

3. Po aktualizácii `gitops-infra` sleduj automatickú synchronizáciu v ArgoCD – **bez manuálneho kliku na Sync**.

---

## Cvičenie 9 – Simulácia chybného image tagu (bonus)

### Krok 1 – Nastav neexistujúci tag v `gitops-infra`

```bash
cd /tmp/gitops-infra
sed -i 's/tag:.*/tag: "nonexistent-tag"/' greeter/values.yaml
git add greeter/values.yaml
git commit -m "test: simulate bad image tag"
git push origin main
```

### Krok 2 – Sleduj stav v ArgoCD a na klastri

1. V ArgoCD synchronizuj aplikáciu a sleduj, ako stav prejde na **Degraded**.

2. Over chybu na klastri:

    ```bash
    kubectl describe pod -l app.kubernetes.io/name=greeter -n workshop-06
    ```

    Všimni si chybu `ImagePullBackOff` alebo `ErrImagePull`.

### Krok 3 – Oprav tag a obnov zdravý stav

```bash
cd /tmp/gitops-infra && git pull
# použi aktuálny tag z imagestreamu
NEW_TAG=$(oc get imagestream greeter -n workshop-06-cicd -o jsonpath='{.status.tags[0].tag}')
sed -i "s/tag:.*/tag: ${NEW_TAG}/" greeter/values.yaml
git add greeter/values.yaml
git commit -m "fix: restore correct image tag"
git push origin main
```

Synchronizuj v ArgoCD a over, že aplikácia je opäť **Healthy**.

---
