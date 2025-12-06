# 1. Workshop

Pre úspešné absolvovanie tohto workshopu je potrebná inštalácia nástrojov [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Farm64%2Fstable%2Fbinary+download) 
a [kubectl](https://kubernetes.io/docs/tasks/tools/).

V tomto priečinku nájdete PowerPoint prezentáciu s názvom [GitOps_Workshop.pptx](./GitOps_Workshop.pptx), na základe ktorej sme preberali základné pojmy a koncepty DevOps a GitOps prístupu, 
vývoja cloud-native applikácií a stručne sme si predstavili hlavné nástroje GitOps vývoja aplikácií.

---

Vrámci predstavenia nástrojov spravil prezentujúci krátku ukážku kontajnerizácie frontendovej aplikácie. Jednoduchú aplikáciu inicializovanú vo Vite + Vue.js 3 spustil lokálne a pomocou dvoch kontajnerov.
Prvý z nich vychádzal z kontajnerového image Node.js a podával development build. Druhý kontajner bol vytvorený pomocou dvoj-stážového buildu a jeho výsledkom bol kontajner s nginx serverom, 
ktorý podáva statické súbory vytvorené v prvej stáži ako produkčný build.

Pre replikovanie dema je potrebné vojsť do priečinku [workshop_01/containers/demo-vue-app](./containers/demo-vue-app). Informácie potrebné pre lokálne spustenie vývojovej verzie aplikácie, 
ako aj pre vytvorenie oboch kontajnerových image-ov nájdete v príslušnom [README.md](./containers/demo-vue-app/README.md) súbore.
Na vytvorenie image-ov je potrebná inštalácia kontajnerového enginu, napríklad [podman](https://podman.io/docs/installation). Okrem príkazov uvedených v README.md môžete preskúmať vytvorené image, 
alebo sa dostať do terminálu bežiaceho kontajnera.

```sh
podman image inspect [názov-image]
podman image inspect tree [názov-image]
podman exec -it [názov-image] /bin/bash
```

---

V poslednej časti workshopu sme si overili úspešnú inštaláciu `minikube` a `kubectl`, následne sme prešli na prvé cvičenia podľa [týchto inštrukcií](./lab/lab.md).
