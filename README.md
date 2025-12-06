# IBM GitOps Workshop pre adminov OSK MV SR

Do Vášho obľúbeného prehliadača Vám odporúcam importovať [tieto záložky](https://gist.github.com/runlevl4/c90f8a68f0526e634a67f13e71fdbe0f).

---

V priebehu workshopov budeme pracovať s týmito nástrojmi (návody na inštaláciu v odkazoch):
  - [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Farm64%2Fstable%2Fbinary+download)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/) (Kubernetes control)
  - [helm](https://helm.sh/docs/intro/install)
  - [tkn](https://tekton.dev/docs/cli/) (Tekton)
  - [argocd](https://argo-cd.readthedocs.io/en/stable/cli_installation/) (ArgoCD)
  - [oc](https://docs.redhat.com/en/documentation/openshift_container_platform/4.11/html/cli_tools/openshift-cli-oc) (OpenShift)

---

Agenda:
1. workshop:
    - predstavenie DevOps a GitOps,
    - prehľad technológií,
    - architektúra K8s,
    - overenie inštalácie minikube a kubectl, základné príkazy (lab),
    - prvý pod cez CLI (lab).
2. workshop:
    - popis životného cyklu kontajnerov,
    - nasadzovanie kontajnerových image-ov ako pod pomocou CLI (lab),
    - nasadzovanie a škálovanie deklaratívne pomocou deployment (lab),
    - ladenie problémov bežiaceho kontajnera cez CLI (lab).
3. workshop:
    - http load balancing pomovou k8s service cez CLI (lab),
    - service deklaratívne pomocou YAML (lab),
    - predstavenie ingress, ukážka prezentujúcim (lab?),
    - ladenie problémov prístupu k podu (lab)?
4. workshop:
    - predstavenie Helm chartov,
    - predstavenie Tekton?
    - ukážka OpenShift dashboardu, ladenie problémov cez GUI (lab)?
5. workshop:
    - inštalácia ArgoCD (lab),
    - GitOps z verejného repozitára (lab),
    - ladenie problémov pri nasadení cez GitOps (lab).
