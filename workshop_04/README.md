## 1. Helm – čo je to a na čo slúži

**Prečo Helm**

* Kubernetes manifesty (YAML) sa rýchlo množia a opakujú.
* Helm umožní zabaliť aplikáciu do **chartu** (balíček šablón + konfigurácia).
* Jednoduché nasadenie/upgrade/rollback: `helm upgrade --install`, `helm rollback`.

**Základná myšlienka**

* Chart obsahuje **templaty** (`templates/`) a **values** (`values.yaml`).
* Helm pri deployi spraví “render” – z templátov + values vygeneruje finálne YAML.

---

## 2. Helm Chart – štruktúra

**Základné súbory**

* `Chart.yaml` – metadata (meno, verzia, typ)
* `values.yaml` – defaultná konfigurácia
* `templates/` – Kubernetes manifesty ako šablóny (Go templating)

**Typická štruktúra**

```
myapp/
  Chart.yaml
  values.yaml
  templates/
    deployment.yaml
    service.yaml
    ingress.yaml
    _helpers.tpl
```

**_helpers.tpl**

* Ukladá spoločné helper funkcie (napr. `fullname`, labely)
* Znižuje duplicitu v templátoch

---

## 3. Helm templating – ako to funguje

**Premenné**

* `.Values` – hodnoty z `values.yaml` a override súborov (`-f`)
* `.Release.Name` – názov release (napr. `myapp-dev`)
* `.Chart.Name` – názov chartu

**Príklad**

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
replicas: {{ .Values.replicaCount }}
```

**Podmienky a cykly**

* Zapínanie/vypínanie častí manifestu:

```yaml
{{- if .Values.ingress.enabled }}
kind: Ingress
...
{{- end }}
```

---

## 4. Helm Values – prečo separovať dev a prod

**Prečo oddelené values**

* Dev a prod majú iné požiadavky: repliky, resources, hostnames, debug, HPA.
* Chceme mať **jeden chart**, ale **viac konfigurácií**.

**Praktický prístup**

* `values.yaml` – base defaults (bezpečné, generické)
* `values-dev.yaml` – len rozdiely pre dev
* `values-prod.yaml` – len rozdiely pre prod

**Použitie**

```bash
helm upgrade --install myapp ./myapp \
  -f values.yaml -f values-dev.yaml
```

**Poradie je dôležité**

* Neskorší súbor prepisuje skorší (dev/prod override).

---

## 5. Release a životný cyklus

**Čo je Helm release**

* Konkrétna inštalácia chartu v namespace.
* Helm si pamätá históriu release → umožňuje rollback.

**Najčastejšie príkazy**

* Render bez deployu:

```bash
helm template myapp ./myapp -f values.yaml -f values-dev.yaml
```

* Deploy/upgrade:

```bash
helm upgrade --install myapp ./myapp -n dev -f values.yaml -f values-dev.yaml
```

* Zisti hodnoty použité v release:

```bash
helm get values myapp -n dev
```

* Rollback:

```bash
helm rollback myapp 1 -n dev
```

---

## 6. Tekton – čo je to a na čo slúži

**Prečo Tekton**

* Kubernetes-native CI/CD: pipeline beží ako pody v clustri.
* Znovupoužiteľné kroky (Tasks), skladanie do pipeline.
* Lepšia auditovateľnosť a deklaratívny prístup (YAML ako zdroj pravdy).

**Základné pojmy**

* **Task** – definícia krokov (steps) v kontajneroch
* **Pipeline** – poskladanie taskov + závislosti
* **TaskRun/PipelineRun** – konkrétne spustenie
* **Workspace** – zdieľané úložisko medzi taskmi (napr. PVC)
* **Params** – vstupy do taskov/pipeline (repo URL, tag, branch…)

---

## 7. Tekton Task – kroky a izolácia

**Steps**

* Každý step je kontajner, beží sekvenčne v rámci Tasku.
* Všetky stepy v tom istom Taske zdieľajú:

  * workspace mount
  * `/tekton/home` (home adresár)

**Prečo je to dobré**

* Každý step má vlastný image (node, git, kaniko…)
* Izolácia a reproducibilita: rovnaký build v každom clustri

---

## 8. Paralelizácia v Tekton Pipeline

**Ako spraviť paralelné tasky**

* Ak dva tasky majú rovnaký `runAfter` a nezávisia od seba, môžu bežať paralelne.

Príklad (test + lint po npm install):

* `test` runAfter `npm-ci`
* `lint` runAfter `npm-ci`
* `build` runAfter `test` aj `lint`

**Prečo to robiť**

* Skracuje CI čas (testy a lint sa často dajú pustiť naraz)

---

## 9. Tekton Triggers – spúšťanie pipeline z Git eventov

**Prečo Triggers**

* Nechceme spúšťať PipelineRun manuálne.
* Git systém (Gitea/GitLab/GitHub) pošle webhook → Tekton vytvorí PipelineRun.

**Komponenty**

* **EventListener** – HTTP endpoint pre webhook
* **TriggerBinding** – mapovanie údajov z payloadu (repo, branch, SHA…)
* **TriggerTemplate** – šablóna, ktorá vytvorí PipelineRun
* **Interceptors** – filtrovanie/validácia (napr. len `refs/heads/main`)

**Praktická myšlienka “merge”**

* Merge do `main` typicky vyvolá **push** na `main`.
* Najjednoduchší model: spúšťať pipeline na `push` do `main`.

**Poznámka:**

* V prostredí OCP MV SR sa na spúšťanie pipelines miesto EventListenerov a Triggrov používa GitLab CI
* To zabezpečuje lepšiu viditeľnosť spustení pipeline z git repozitára

---

## 10. GitOps update – prečo commitovať image tag do Helm repo

**Problém, ktorý riešime**

* Keď buildnem image, potrebujem, aby sa nasadzovala správna verzia.
* Nechceme ručne meniť YAML/values po každom builde.

**Riešenie**

* Pipeline po pushnutí image spraví commit do `helm-repo`:

  * zmení `image.tag` na nový SHA/tag
* Helm repo sa stáva “zdroj pravdy” pre deploy.

**Výhody**

* Audit: v Git histórii vidíš, kto a kedy zmenil nasadzovanú verziu.
* Jednoduchý rollback: revert commit v helm-repo.

---

## 11. Tokeny a prístup do Git repozitára (HTTP token)

**Prečo token**

* Pipeline potrebuje:

  * klonovať repozitáre
  * pushovať commit do helm-repo
* Heslá sa nepoužívajú, tokeny sa dajú obmedziť (scope, expirácie).

**Kde to držíme**

* Kubernetes `Secret` (napr. `gitea-credentials`)
* Task si token načíta ako env premennú.

**Najčastejšie chyby**

* token nemá právo na push (chýba scope)
* zlá URL (interná vs externá adresa Gitea)
* repo neexistuje alebo zlá vetva

---
