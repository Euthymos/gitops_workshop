# LAB_01: Prvý webový pod na minikube

### Cieľ

Rýchlo spustiť minikube, nasadiť jednoduchý webový kontajner, sprístupniť ho cez Kubernetes Service a otvoriť webové rozhranie v prehliadači.

### Predpoklady

* Minikube a kubectl sú nainštalované a funkčné.
  Oficiálne návody uvádzajú, že minikube je navrhnuté práve na jednoduché lokálne spustenie Kubernetes klastra jedným príkazom. ([minikube][1])
* Prístup na internet, ak na stiahnutie image treba.

---

## Krok 1 – Spusti minikube

1. Spustenie klastra:

    ```bash
    minikube start
    ```

2. Over, že je klaster pripravený:

   ```bash
   kubectl get nodes
   kubectl cluster-info
   ```

   *Mal by sa zobraziť jeden uzol a informácie o API serveri.*

3. Vytvor nový namespace workshop-01:

   ```bash
   kubectl create namespace workshop-01
   ```

4. Over, že namespace existuje:

   ```bash
   kubectl get namespaces
   ```

---

## Krok 2 – Vytvor Deployment s jednoduchým webom

1. Vytvor pod s nginx (alebo iným ľahkým webovým serverom):

   ```bash
   kubectl create deployment web-demo \
      --image=nginx:stable-alpine
      -n workshop-01
   ```

2. Over stav podov:

   ```bash
   kubectl get pods -n workshop-01
   ```

   *Hľadaj pod s názvom, ktorý sa začína `web-demo`, stav by mal byť `Running`.*

<details><summary><i>Work smarter - not harder</i></summary>

3. Použi aktuálny kontext a nastav mu namespace `workshop-01` ako východzí:

   ```bash
   kubectl config set-context --current --namespace=workshop-01
   ```

4. Over nastavenie:

   ```bash
   kubectl config get-contexts
   kubectl config current-context
   ```

Odteraz už v príkazoch nemusíš písať `-n workshop-01`, Kubernetes použije tento namespace automaticky.

</details>

---

## Krok 3 – Sprístupni pod cez Service v namespaci

1. Vytvor Service typu NodePort v namespaci `workshop-01`:

   ```bash
   kubectl expose deployment web-demo \
     --port=80 \
     --type=NodePort \
     -n workshop-01
   ```

2. Zobraz Service a zisti port:

   ```bash
   kubectl get svc web-demo -n workshop-01
   ```

---

## Krok 4 – Otvor web v prehliadači

### Možnosť A: Použi `minikube service`

1. Spusti príkaz s uvedeným namespacom:

   ```bash
   minikube service web-demo -n workshop-01
   ```

2. Otvor URL, ktorú minikube vypíše, v prehliadači a over zobrazenie nginx stránky.

---

### Možnosť B: použi IP a NodePort

1. Zisti IP adresu minikube:

   ```bash
   minikube ip
   ```

2. Zisti NodePort služby v namespaci:

   ```bash
   kubectl get svc web-demo -n workshop-01 -o jsonpath='{.spec.ports[0].nodePort}'
   ```

3. Otvor v prehliadači adresu:

   ```text
   http://<MINIKUBE_IP>:<NODE_PORT>
   ```

   *(Nahraď `<MINIKUBE_IP>` a `<NODE_PORT>` reálnymi hodnotami z príkazov.)*

---

## Krok 5 – Uprac resources v namespaci

1. Odstráň Service v namespaci:

   ```bash
   kubectl delete svc web-demo -n workshop-01
   ```

2. Odstráň Deployment v namespaci:

   ```bash
   kubectl delete deployment web-demo -n workshop-01
   ```

3. Voliteľne odstráň celý namespace:

   ```bash
   kubectl delete namespace workshop-01
   ```

4. Zastav minikube (ak už nebudeš pokračovať):

   ```bash
   minikube stop
   ```

---

Hotovo! Toto cvičenie ťa prevedie od úplného spustenia lokálneho klastra až po zobrazenie webu v prehliadači len niekoľkými imperatívnymi príkazmi.

[1]: https://minikube.sigs.k8s.io/docs/start/#:~:text=minikube%20is%20local%20Kubernetes%2C%20focusing,Podman%2C%20VirtualBox%2C%20or%20VMware%20Fusion%2FWorkstation "minikube start | minikube"
[2]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_expose/#:~:text=Expose%20a%20resource%20as%20a,type%3Dtype "kubectl expose | Kubernetes"
