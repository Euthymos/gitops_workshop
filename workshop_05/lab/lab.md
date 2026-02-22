# LAB_05: GitOps s ArgoCD

### Cieľ

Tento workshop je zameraný na prácu s ArgoCD ako GitOps nástrojom. Ukážeme si, ako nasadiť aplikáciu deklaratívne pomocou Helm chartu uloženého v Git repozitári. Naučíme sa sledovať stav synchronizácie aplikácie a manuálne synchronizovať zmeny. Na záver si simulujeme problém s nesprávnym Docker image tagom a pozorujeme, ako sa to prejaví na zdraví aplikácie.

### Predpoklady

* Nainštalované: `minikube`, `kubectl`, `helm`, `git`
* Prístup na internet (na stiahnutie image `quay.io/euthymos/workshop-greeter:latest`)

---

## Cvičenie 0 – Príprava klastra

### Krok 1 – Spusti `make up` z adresára `lab/`

1. Prejdi do adresára `lab/` a otvor súbor `makefile`:

    ```bash
    cd ./lab
    sudo chmod 774 ./scripts/*.sh
    cat makefile
    ```

    Poznámka: Skripty spustia minikube klaster, ak ešte nebeží, povolia doplnok `ingress`, nainštalujú ArgoCD a Gitea, nakonfigurujú ArgoCD repozitár a vypíšu prihlasovacie údaje.

2. Spusti príkaz `make up`:

    ```bash
    make up
    ```

3. Over výsledok skriptov:

    ```bash
    make verify
    ```

### Krok 2 – Nastav `/etc/hosts`

1. Zisti IP adresu minikube klastra:

    ```bash
    minikube ip
    ```

2. Pridaj záznamy do súboru `/etc/hosts` (nahraď `<MINIKUBE_IP>` zistenou IP):

    ```bash
    sudo sh -c 'echo "<MINIKUBE_IP> gitea.local argocd.local greeter.local" >> /etc/hosts'
    ```

3. Over dostupnosť ArgoCD a Gitea v prehliadači:
    - Gitea: http://gitea.local
    - ArgoCD: http://argocd.local

    Prihlasovacie údaje vypíše príkaz `make up`, prípadne:

    ```bash
    make info
    ```

---

## Cvičenie 1 – Preskúmaj helm chart greeter aplikácie

1. Vojdi do adresára `../helm`:

    ```bash
    cd ../helm
    ```

2. Prečítaj súbor `Chart.yaml`:

    ```bash
    cat Chart.yaml
    ```

3. Prečítaj súbor `values.yaml` a všimni si dostupné hodnoty:

    ```bash
    cat values.yaml
    ```

    Všimni si parameter `attendeeName` – ak je prázdny, aplikácia zobrazí predvolené (fallback) meno.

4. Prezri si šablóny v adresári `templates/`:

    ```bash
    ls templates/
    cat templates/deployment.yaml
    cat templates/configmap.yaml
    cat templates/ingress.yaml
    ```

5. Vyrenderuj helm chart lokálne a skontroluj výstup:

    ```bash
    helm template greeter . --debug
    ```

---

## Cvičenie 2 – Pushni helm chart do gitops-infra repozitára

### Krok 1 – Vytvor lokálnu kópiu gitops-infra repozitára

1. Klonuj repozitár `gitops-infra` z Gitea (Gitea bola nakonfigurovaná skriptami z Cvičenia 0):

    ```bash
    cd /tmp
    git clone http://gitea.local/admin/gitops-infra.git
    cd gitops-infra
    ```

2. Nastav git identitu (ak ešte nie je nastavená):

    ```bash
    git config user.name "admin"
    git config user.email "admin@example.com"
    ```

### Krok 2 – Skopíruj obsah helm chartu do repozitára

1. Skopíruj obsah adresára `helm/` do repozitára:

    ```bash
    cp -r <cesta_k_workshopu>/workshop_05/helm/. ./greeter/
    ```

2. Zobraz skopírované súbory:

    ```bash
    ls -la greeter/
    ```

### Krok 3 – Commitni a pushni zmeny

1. Pridaj zmeny, sprav commit a pushni:

    ```bash
    git add .
    git commit -m "feat: add greeter helm chart"
    git push origin main
    ```

2. Skontroluj repozitár v Gitea UI: http://gitea.local/admin/gitops-infra

---

## Cvičenie 3 – Vytvor namespace a pridaj ArgoCD label

### Krok 1 – Vytvor namespace pre greeter aplikáciu

1. Vytvor namespace `workshop-05`:

    ```bash
    kubectl create namespace workshop-05
    ```

2. Over, že namespace existuje:

    ```bash
    kubectl get namespaces workshop-05
    ```

### Krok 2 – Pridaj label pre ArgoCD

ArgoCD potrebuje vedieť, že smie nasadzovať do daného namespacu v rámci projektu. Label `argocd.argoproj.io/managed-by` to umožňuje.

1. Pridaj label na namespace:

    ```bash
    kubectl label namespace workshop-05 argocd.argoproj.io/managed-by=argocd
    ```

2. Skontroluj, že label bol pridaný:

    ```bash
    kubectl get namespace workshop-05 --show-labels
    ```

---

## Cvičenie 4 – Vytvor projekt a aplikáciu v ArgoCD

### Krok 1 – Vytvor nový projekt v ArgoCD

1. Otvor ArgoCD UI v prehliadači: http://argocd.local

2. Prihlás sa (prihlasovacie údaje z `make info`).

3. V ľavom menu klikni na **Settings** → **Projects** → **New Project**.

4. Vyplň formulár:
    - **Project Name:** `workshop-05`
    - **Description:** `GitOps workshop 05 – Greeter app`

5. V sekcii **Source Repositories** pridaj:
    - `http://gitea.local/admin/gitops-infra.git`

6. V sekcii **Destinations** pridaj:
    - **Server:** `https://kubernetes.default.svc`
    - **Namespace:** `workshop-05`

7. Potvrď vytvorenie projektu kliknutím na **Create**.

### Krok 2 – Pridaj novú aplikáciu

1. Prejdi do sekcie **Applications** → **New App**.

2. Vyplň formulár:
    - **Application Name:** `greeter`
    - **Project Name:** `workshop-05`
    - **Sync Policy:** `Manual`

3. Sekcia **Source**:
    - **Repository URL:** `http://gitea.local/admin/gitops-infra.git`
    - **Revision:** `main`
    - **Path:** `greeter`

4. Sekcia **Destination**:
    - **Cluster URL:** `https://kubernetes.default.svc`
    - **Namespace:** `workshop-05`

5. Sekcia **Helm**:
    - Ponechaj predvolené hodnoty (alebo skontroluj, že `values.yaml` je vybraný).

6. Klikni na **Create**.

### Krok 3 – Nasaď aplikáciu (Sync)

1. V ArgoCD UI klikni na aplikáciu `greeter`.

2. Klikni na tlačidlo **Sync** → **Synchronize**.

3. Sleduj priebeh nasadenia – stav by sa mal zmeniť na **Synced** a **Healthy**.

4. Over nasadenie cez kubectl:

    ```bash
    kubectl get all -n workshop-05
    kubectl get ingress -n workshop-05
    ```

---

## Cvičenie 5 – Over aplikáciu v prehliadači

1. Otvor aplikáciu v prehliadači: http://greeter.local

2. Všimni si, že aplikácia zobrazuje **fallback meno** – parameter `attendeeName` v `values.yaml` je prázdny.

---

## Cvičenie 6 – Uprav values.yaml a sleduj Out of Sync

### Krok 1 – Uprav values.yaml v gitops-infra repozitári

1. Prejdi do naklonovaného repozitára `gitops-infra`:

    ```bash
    cd /tmp/gitops-infra
    ```

2. Otvor súbor `greeter/values.yaml` a nastav svoje meno ako hodnotu `attendeeName`:

    ```yaml
    attendeeName: "Tvoje Meno"
    ```

    ```bash
    # napr.:
    sed -i 's/attendeeName: ""/attendeeName: "Jana Nováková"/' greeter/values.yaml
    cat greeter/values.yaml
    ```

### Krok 2 – Commitni a pushni zmenu

1. Pridaj zmeny, sprav commit a pushni:

    ```bash
    git add greeter/values.yaml
    git commit -m "feat: set attendeeName"
    git push origin main
    ```

### Krok 3 – Sleduj stav Out of Sync v ArgoCD

1. Otvor ArgoCD UI: http://argocd.local

2. Všimni si, že aplikácia `greeter` zobrazuje stav **OutOfSync** – ArgoCD zistil rozdiel medzi stavom v Gite a aktuálnym stavom na klastri.

    Poznámka: ArgoCD štandardne kontroluje repozitár každé 3 minúty. Ak chceš zmenu zobraziť okamžite, klikni na **Refresh**.

### Krok 4 – Manuálne nasaď zmeny

1. V ArgoCD UI klikni na aplikáciu `greeter`.

2. Klikni na **Sync** → **Synchronize**.

3. Po úspešnej synchronizácii otvor aplikáciu v prehliadači: http://greeter.local

4. Overte, že aplikácia zobrazuje tvoje meno.

---

## Cvičenie 7 – Simulácia chybného image tagu

### Krok 1 – Zmeň image tag na neexistujúci

1. V repozitári `gitops-infra` zmeň hodnotu `image.tag` v súbore `greeter/values.yaml`:

    ```yaml
    image:
      tag: "nonexistent"
    ```

    ```bash
    cd /tmp/gitops-infra
    sed -i 's/tag: "latest"/tag: "nonexistent"/' greeter/values.yaml
    cat greeter/values.yaml
    ```

2. Commitni a pushni zmenu:

    ```bash
    git add greeter/values.yaml
    git commit -m "test: set nonexistent image tag"
    git push origin main
    ```

### Krok 2 – Synchronizuj aplikáciu v ArgoCD

1. V ArgoCD UI klikni na **Refresh**, potom **Sync** → **Synchronize**.

2. Sleduj stav aplikácie – po chvíli sa stav zmení na **Degraded** / **Unhealthy**.

3. Prezri si detail aplikácie – klikni na pod `greeter-*` a pozri si udalosti:

    ```bash
    kubectl describe pod -l app.kubernetes.io/name=greeter -n workshop-05
    ```

    Všimni si chybu `ImagePullBackOff` alebo `ErrImagePull` – Kubernetes nevie stiahnuť image s neexistujúcim tagom.

### Krok 3 – Oprav image tag a znovu nasaď

1. Vráť hodnotu `image.tag` späť na `latest`:

    ```bash
    sed -i 's/tag: "nonexistent"/tag: "latest"/' greeter/values.yaml
    git add greeter/values.yaml
    git commit -m "fix: revert image tag to latest"
    git push origin main
    ```

2. V ArgoCD UI synchronizuj aplikáciu a over, že stav sa vrátil na **Healthy**.

3. Over aplikáciu v prehliadači: http://greeter.local

---
