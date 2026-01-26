## 1. Kubernetes – základné pojmy

**Klaster**

* Skupina serverov (node-ov), na ktorých bežia kontajnery a aplikácie.
* Riadiaci (control plane) a pracovné (worker) nody.

**Pod**

* Najmenšia jednotka nasadenia v Kubernetes.
* Obsahuje jeden alebo viac kontajnerov, ktoré zdieľajú IP adresu a disk.

**Namespace**

* Logické „oddelenie“ v klastri (napr. `dev`, `test`, `prod`).
* Pomáha organizovať zdroje a oddeliť tímy/prostredia.

---

## 2. Imperatívny vs. deklaratívny prístup

**Imperatívny**

* Hovoríme „urob toto“:
  napr. `kubectl create deployment ...`
* Rýchle na testovanie, menej vhodné na dlhodobú správu.

**Deklaratívny**

* Hovoríme „chcem, aby stav vyzeral takto“ – v YAML manifestoch.
* Používame `kubectl apply -f ...`.
* Dobre sa kombinuje s GitOps (manifesty v Gite).

V tomto workshope sa sústredíme hlavne na **deklaratívny prístup**.

---

## 3. Deployment, Service a labels

**Deployment**

* Objekt, ktorý riadi **počty podov** a ich verzie.
* Definuje:

  * koľko replík má bežať (`spec.replicas`),
  * šablónu podu (`spec.template`),
  * labely.

**Service**

* Stabilný prístupový bod (IP, DNS meno) pre pody.
* Pomocou labelov nájde správne pody a routuje na ne traffic.

**Labels**

* Jednoduché značky vo forme `key=value` (napr. `app=demo-app`).
* Slúžia na výber a filtrovanie podov, deploymentov, služieb.

---

## 4. Stav podu a životný cyklus

Bežné stavy podov:

* `Pending` – pod čaká, ešte nebol naplánovaný/spustený.
* `Running` – kontajner(e) bežia.
* `Succeeded` – job skončil úspešne.
* `Failed` – job skončil chybou.
* `CrashLoopBackOff` – kontajner sa stále spúšťa a padá.

V zozname podov uvidíte aj:

* `READY` – koľko kontajnerov v pod-e je „pripravených“.
* `RESTARTS` – koľkokrát sa kontajner reštartoval.

---

## 5. Readiness a liveness probes

**Liveness probe**

* Kontrola, či proces ešte žije.
* Keď zlyháva → Kubernetes kontajner reštartuje.

**Readiness probe**

* Kontrola, či je pod pripravený obsluhovať požiadavky.
* Keď zlyháva → pod ostáva bežať, ale Service naň neposiela traffic.

V praxi:

* liveness = „zabi a spusti znova, keď je appka zaseknutá“
* readiness = „neposielaj na mňa traffic, ešte nie som ready“.

---

## 6. Zdroje: CPU/RAM, requests a limits

**Requests**

* Minimálne zdroje, ktoré pod *potrebuje*, aby bol naplánovaný na node.
* Scheduler podľa nich rozhoduje, či sa pod zmestí na node.

**Limits**

* Maximálne zdroje, ktoré pod môže použiť.
* Pri prekročení limitu pamäte môže byť kontajner ukončený (OOMKilled).

Ak sú requests príliš veľké → pod môže zostať v stave `Pending`.

---

## 7. Nástroje na troubleshooting: describe, logs, events

**`kubectl describe`**

* Detailný výpis objektu (pod, service, deployment…).
* Obsahuje aj sekciu **Events** – veľmi dôležitá pri hľadaní chýb.

**`kubectl logs`**

* Zobrazuje logy kontajnera v pod-e.
* `-f` prepínač sleduje log v reálnom čase.

**Events**

* Zobrazíte ich príkazom `kubectl get events`.
* Pomáhajú zistiť:

  * problémy s image (`Failed to pull image`),
  * problémy so zdrojmi (`Insufficient cpu/memory`),
  * problémy so schedulerom a ďalšie.

---

## 8. Minikube – lokálny Kubernetes pre vývoj

* Jednoduchý spôsob, ako mať Kubernetes na vlastnom notebooku.
* Bežne beží ako **single-node klaster**.
* Umožňuje testovať:

  * deploymenty,
  * služby typu NodePort,
  * Ingress a ďalšie.

Užitočné príkazy:

* `minikube start`, `minikube stop`, `minikube delete`
* `minikube status`
* `minikube ip`
* `minikube service <service> -n <namespace>` – otvorí URL v prehliadači.

---

## 9. OpenShift a Kubernetes – stručné porovnanie

* OpenShift stavia na Kubernetes a pridáva:

  * vlastný login (OAuth),
  * web konzolu,
  * zabudovaný registry,
  * prísnejšie bezpečnostné nastavenia.

* Príkazy `oc` sú veľmi podobné `kubectl`:

  * `kubectl get pods` ≈ `oc get pods`
  * `kubectl apply -f ...` ≈ `oc apply -f ...`

* Namespace vs. Project:

  * v OpenShifte sa často používa pojem **project**, technicky je to namespace + metadáta.

V rámci workshopu používame `kubectl` a minikube, ale princípy sú rovnaké aj pre OpenShift.
