## Workshop 06 – CI/CD + GitOps: Tekton Pipelines + ArgoCD na OpenShift Local (CRC)

---

## 1. CI/CD a GitOps – prečo ich kombinovať

**CI/CD pipeline** (Continuous Integration / Continuous Delivery):

* Zodpovedá za builnovanie a testovanie aplikácie pri každom commite.
* Výstupom je artefakt – typicky kontajnerový image s tagem (napr. git SHA).
* Klasické CI/CD systémy siahajú priamo na klaster a nasadzujú (`kubectl apply`, `helm upgrade`).

**GitOps model**:

* Klaster je vždy synchronizovaný s Git repozitárom.
* Nikto nesahá na klaster priamo – zmena prechádza cez Git.
* ArgoCD sleduje infra repozitár a deteguje odchýlky.

**Kombinácia – ako to funguje spolu**:

```
git push app-repo
    → Tekton pipeline (CI)
        → build image + push do registra
        → aktualizuj image.tag v infra repo (commit)
    → ArgoCD zaznamená zmenu v infra repo
        → Out of Sync → manuálny / automatický Sync
        → deploy na klaster
```

**Výhody kombinácie**:

* Úplná auditovateľnosť: každý deploy pochádza z Git commitu.
* Rollback = `git revert` v infra repo.
* CI a CD sú oddelené systémy s jasnými zodpovednosťami.

---

## 2. OpenShift Local (CRC) – čo treba vedieť

**CRC (CodeReady Containers)** je lokálna jednouzlová inštalácia OpenShift 4.x.

| Pojem | Popis |
|---|---|
| `crc start` | Spustí VM s lokálnym OCP klastrom |
| `eval $(crc oc-env)` | Nastaví `PATH` pre `oc` CLI |
| `kubeadmin` | Plný administrátorský prístup |
| `developer` | Obmedzený vývojársky účet (pre bežnú prácu) |
| `*.apps-crc.testing` | Doména pre Routes (obdoba Ingress) |
| Interný register | `image-registry.openshift-image-registry.svc:5000` |

**Rozdiel oproti minikube**:

* OpenShift má vlastný RBAC a SCC (Security Context Constraints) – prísnejší ako čistý Kubernetes.
* Namiesto Ingress sa používajú **Routes** (automaticky spravované OpenShift routerom).
* Obraz možno pushnutú do interného registra bez externého nástroja (napr. bez Kaniko s minikube addone).

---

## 3. OpenShift Pipelines (Tekton) – inštalácia cez Operator

**Rozdiel oproti workshop_04 (minikube)**:

* Na minikube sme inštalovali Tekton ručne pomocou `kubectl apply` na upstream manifestoch.
* Na OpenShift inštalujeme **OpenShift Pipelines Operator** z OperatorHub – udržiava verziu, aktualizácie a integráciu s OpenShift konzolou.

**Výhody operátora**:

* Tekton Dashboard je súčasťou inštalácie a dostupný cez Route.
* Operátor spravuje CRD a kontrolér automaticky.
* `pipeline` ServiceAccount je automaticky vytvorený v každom namespace.

---

## 4. OpenShift GitOps (ArgoCD) – inštalácia cez Operator

**Rozdiel oproti workshop_05 (minikube)**:

* Na minikube sme inštalovali ArgoCD ručne cez upstream Helm/manifest.
* Na OpenShift inštalujeme **OpenShift GitOps Operator** – spravovaná verzia ArgoCD s integráciou do OpenShift konzoly.

**Kľúčové detaily**:

* ArgoCD instance beží v namespace `openshift-gitops`.
* Admin password: z `Secret/openshift-gitops-cluster`.
* Route pre ArgoCD UI je automaticky vytvorená operátorom.

---

## 5. buildah – build kontajnerov v OpenShift

**Prečo nie Kaniko**:

* V workshop_04 sme použili Kaniko s minikube interným registrom.
* Na OpenShift je preferovaný **buildah** – natívny nástroj Red Hat, integrovaný s OpenShift registry.

**Ako buildah funguje v pipeline**:

1. `buildah bud` – buildne image podľa Containerfile.
2. `buildah login` – prihlási sa do OpenShift interného registra pomocou SA tokenu.
3. `buildah push` – pushne image do `image-registry.openshift-image-registry.svc:5000/<namespace>/<name>:<tag>`.

**Rootless build**:

* `--storage-driver=vfs` umožňuje bezpečný build bez privilegovaného prístupu.

---

## 6. Admin vs Developer – rozdelenie zodpovedností

Tento workshop explicitne oddeľuje kroky pre administrátora a vývojára.

| Akcia | Kto | Nástroj |
|---|---|---|
| Inštalácia operátorov | **admin** | `oc` + Subscription |
| Inštalácia Gitea | **admin** | `helm` |
| Vytvorenie namespaces a RBAC | **admin** | `oc` |
| Konfigurácia ArgoCD repo | **admin** | API/skript |
| Vytvorenie Git repozitárov | **developer** | Gitea UI / `git` |
| Push zdrojového kódu | **developer** | `git` |
| Aplikovanie Tekton manifestov | **admin** skript / **developer** | `oc apply` |
| Nastavenie webhook | **developer** | Gitea UI |
| Vytvorenie ArgoCD aplikácie | **developer** | ArgoCD UI / `oc apply` |
| Sync ArgoCD | **developer** | ArgoCD UI |

---

## 7. End-to-end architektúra

```
┌──────────────────────────────────────────────────────────┐
│                  Developer laptop                        │
│                                                          │
│   git push ──► app-repo (Gitea)                          │
│                    │                                     │
│                    ▼ webhook                             │
│           ┌─────────────────┐                            │
│           │  EventListener  │  (Tekton Triggers)         │
│           └────────┬────────┘                            │
│                    │                                     │
│                    ▼                                     │
│           ┌─────────────────┐                            │
│           │   PipelineRun   │  (Tekton Pipelines)        │
│           │  1. clone       │                            │
│           │  2. build+push  │──► OpenShift Registry      │
│           │  3. update-infra│──► gitops-infra (Gitea)    │
│           └─────────────────┘          │                 │
│                                        │ poll            │
│           ┌─────────────────┐          │                 │
│           │     ArgoCD      │◄─────────┘                 │
│           │  Out of Sync    │                            │
│           │  Manual Sync ──►│──► workshop-06 namespace   │
│           └─────────────────┘                            │
└──────────────────────────────────────────────────────────┘
```

---

## 8. Komponenty a tooling

| Komponent | Inštalácia | Namespace |
|---|---|---|
| Gitea | Helm chart | `gitea` |
| OpenShift Pipelines | Operator (OperatorHub) | `openshift-operators` |
| OpenShift GitOps (ArgoCD) | Operator (OperatorHub) | `openshift-gitops` |
| CICD resources | `oc apply` | `workshop-06-cicd` |
| Greeter app | ArgoCD sync | `workshop-06` |

---

## 9. Predpoklady

* `crc` nainštalovaný a spustený (`crc start`)
* `oc` CLI (súčasť CRC)
* `tkn` CLI (Tekton)
* `helm` CLI
* `git`, `curl`, `jq`

---

## 10. Štruktúra

```
workshop_06/
├── README.md            ← tento súbor
└── lab/
    ├── lab.md           ← podrobný lab s cvičeniami
    ├── README.md        ← prerekvizity a quick start
    ├── makefile         ← admin automatizácia
    ├── .env.example     ← šablóna premenných prostredia
    ├── scripts/         ← bash skripty (admin)
    ├── manifests/       ← YAML manifesty
    │   ├── namespaces.yaml
    │   ├── tekton/
    │   └── argocd/
    └── values/
        └── gitea-values.yaml
```

---

## 11. Rýchly štart (admin)

```bash
cd workshop_06/lab
cp .env.example .env
# vyplň GITEA_ADMIN_PASS; token doplníš po nastavení Gitea
chmod 774 ./scripts/*.sh

# krok 1: klaster + operátory + Gitea + namespaces
make admin-up

# krok 2: (v Gitea UI vytvor repozitáre a token, vlož do .env)
# krok 3: CICD manifesty + ArgoCD konfigurácia
make cicd-up
```

Vývojár potom:

```bash
oc login -u developer -p developer https://api.crc.testing:6443
# Pokračuj podľa lab.md – Cvičenia 2–9
```
