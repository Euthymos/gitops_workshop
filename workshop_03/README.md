## 1. Kubernetes Service – na čo slúži

**Prečo Service**

* Pody sú dynamické – menia IP adresy, môžu zaniknúť a vzniknúť znova.
* Service poskytuje **stabilný prístupový bod** (IP + DNS meno) k skupine podov.
* Vnútorný „loadbalancer“ – rozdeľuje traffic na viac replík podu.

**Základná myšlienka**

* Service vyberá pody pomocou **label selectorov**.
* Traffic ide vždy na **ready** pody (podľa readiness probe).

---

## 2. Typy Services

**ClusterIP (default)**

* Prístupná len **vo vnútri klastra**.
* Najčastejší typ – backendy, databázy, interné API.
* Má vlastnú virtuálnu IP (cluster IP).

**NodePort**

* Sprístupní Service cez port na každom node (napr. `30080`).
* Prístup zvonku: `http://<node-ip>:<nodePort>`.
* Jednoduchý spôsob na testovanie v dev/prostredí.

**LoadBalancer**

* V cloud prostredí vytvorí externý loadbalancer (AWS ELB, GCP LB…).
* Používa sa pre služby, ktoré majú byť priamo dostupné z internetu.
* Z pohľadu K8s je to NodePort + cloud loadbalancer navrch.

**ExternalName**

* „Alias“ na externú službu (napr. databáza mimo klastra).
* V DNS preloží meno Service na externý názov (CNAME).

---

## 3. Labels a selectors

**Labels**

* Kľúč–hodnota (napr. `app=echo`, `env=dev`).
* Priraďujeme ich podom, deploymentom, services a iným objektom.

**Selectors v Service**

* Definujú, **ktoré pody** daná Service obsluhuje.
* Príklad:

  ```yaml
  spec:
    selector:
      app: echo
  ```

* Ak labely nesedia (`app=echoo` vs `app=echo`), Service **nebude mať žiadne endpoints**.

---

## 4. Endpoints a kube-proxy

**Endpoints**

* Zoznam IP adries podov + portov, na ktoré Service smeruje.

* Zobrazenie:

  ```bash
  kubectl get endpoints <service-name>
  ```

* Ak je tam `ENDPOINTS: <none>` → Service **nemá kam routovať**.

**kube-proxy**

* Komponent bežiaci na každom node.
* Starostlivosť o to, aby traffic na IP/port Service skončil na správnom pod-e.
* Využíva iptables/iptables-nft alebo IPVS (podľa konfigurácie).

---

## 5. Porty v Service (port, targetPort, nodePort)

**port**

* Port, na ktorom Service počúva – to, čo používajú klienti v klastri.
* Napr. `port: 80`.

**targetPort**

* Port na pod-e (kontajneri), na ktorý sa request nakoniec dostane.
* Musí sedieť s `containerPort` alebo reálne použitým portom v aplikácii.
* Typický bug: `port: 80`, `targetPort: 8080`, ale app beží na `5678`.

**nodePort**

* Používa sa iba pri type `NodePort` alebo `LoadBalancer`.
* Statický port na node (`30000–32767`), cez ktorý sa Service dá volať zvonku.

---

## 6. DNS v klastri

**Service DNS mená**

* Krátky tvar v tom istom namespace:

  * `echo-service`
* FQDN (plný tvar):

  * `echo-service.default.svc.cluster.local`

**CoreDNS**

* Komponent, ktorý rieši DNS v klastri.
* Umožňuje podom používať názvy Services namiesto IP.

**Praktické príkazy**

* Z podu:

  ```bash
  nslookup echo-service
  nslookup echo-service.default.svc.cluster.local
  ```

---

## 7. Readiness, liveness a vplyv na Service

**Liveness probe**

* Kontroluje, či proces „žije“.
* Pri opakovaných failoch Kubernetes kontajner **reštartuje**.

**Readiness probe**

* Kontroluje, či je pod pripravený obsluhovať traffic.
* Ak zlyháva:

  * pod beží,
  * ale **nie je pridaný medzi endpoints** danej Service.
* Service posiela traffic len na pody, ktoré sú `Ready`.

**Dôsledok pre troubleshooting**

* Pod môže byť `Running`, ale `READY 0/1` → Service ho ignoruje.
* Vtedy často vidíme `ENDPOINTS: <none>` alebo menej endpointov, než očakávame.

---

## 8. Testovanie a troubleshooting Services

**Základné príkazy**

* Zoznam Services:

  ```bash
  kubectl get svc
  ```

* Detaily Service:

  ```bash
  kubectl describe svc <name>
  ```

* Zoznam podov, ktoré by mala Service obsluhovať:

  ```bash
  kubectl get pods -l app=<hodnota>
  ```

* Endpoints:

  ```bash
  kubectl get endpoints <name>
  ```

**Test z vnútra klastra**

* Spustenie dočasného podu:

  ```bash
  kubectl run tmp-shell --rm -it --image=busybox -- /bin/sh
  ```

* Vo vnútri:

  ```sh
  wget -qO- http://<service-name>:<port>
  ```

**Typický checklist**

1. Beží Service? (`kubectl get svc`)
2. Má Service endpoints? (`kubectl get endpoints`)
3. Sedia labely medzi Service a pod-mi?
4. Sedia porty (`port` vs `targetPort` vs `containerPort`)?
5. Sú pody `READY 1/1`?
6. Funguje volanie z testovacieho podu?
7. Ak ide o NodePort/LoadBalancer, funguje volanie aj z node alebo zvonku?

---

## 9. NodePort vs. LoadBalancer vs. Ingress

**NodePort**

* Každý node počúva na rovnakom porte (napr. `30080`).
* Prístup cez `http://node-ip:nodePort`.
* Jednoduché, ale:

  * vyššia väzba na IP nódov,
  * zlá škálovateľnosť pre veľké projekty.

**LoadBalancer**

* V cloude vytvára externý loadbalancer.
* Používa IP adresu alebo DNS, na ktorú sa pripájajú klienti z internetu.
* Dražšie, každá služba môže mať vlastný LB.

**Ingress**

* Rieši HTTP(S) routovanie na viac Services cez **jeden externý vstup**.
* Máš jednu IP / DNS (napr. `apps.example.com`) a viacero host/path pravidiel.
* Šetrí loadbalancery a zjednodušuje konfiguráciu.

---

## 10. Ingress controller – čo to je

**Ingress resource vs. Ingress controller**

* Ingress **resource**:

  * Kubernetes objekt, kde popíšeš pravidlá: host, path, backend Service.
* Ingress **controller**:

  * reálna komponenta (napr. NGINX, HAProxy, Traefik),
  * číta Ingress zdroje a nastavuje si vlastnú konfiguráciu.

**Príklady controllerov**

* `ingress-nginx` (NGINX Ingress Controller – veľmi rozšírený).
* Traefik, HAProxy, istio-ingressgateway a ďalšie.

---

## 11. Ingress resource – základné polia

**Stručný príklad**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: echo-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: echo.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: echo-service
                port:
                  number: 80
```

**Kľúčové časti**

* `ingressClassName`

  * Hovorí, ktorý Ingress controller má objekt spracovať (napr. `nginx`).
* `rules`

  * zoznam pravidiel, podľa ktorých sa routuje traffic.
* `host`

  * DNS meno (napr. `echo.local`, `api.example.com`).
* `paths`

  * `path` – URL cesta (`/`, `/api`, `/app`…),
  * `pathType` – typ matchovania (`Prefix`, `Exact`).
* `backend.service`

  * názov Service a port, kam sa má request poslať.

**TLS (šifrovanie)**

* Voliteľná sekcia:

  ```yaml
  tls:
    - hosts:
        - echo.local
      secretName: echo-tls
  ```

* Secret obsahuje TLS certifikát a key.

---

## 12. Čo si z workshopu odniesť

* Service = stabilný prístupový bod na pody, vyberané cez labely.
* Endpoints = reálny zoznam podov, ktoré Service obsluhuje.
* Najčastejšie príčiny problémov:

  * zlé labely/selectory,
  * nesediace porty,
  * pods nie sú Ready,
  * DNS / Ingress pravidlá.
* Ingress controller + Ingress resource = flexibilný HTTP(S) vstup do klastra.
* `kubectl describe`, `kubectl get endpoints`, dočasný testovací pod a `curl/wget`
  sú tvoji najlepší kamoši pri troubleshootingu Services a Ingressov.

```
::contentReference[oaicite:0]{index=0}
```
