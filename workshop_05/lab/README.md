# ArgoCD + Gitea GitOps workshop infra (minikube)

## Čo to spraví
- spustí minikube + ingress addon
- nainštaluje ArgoCD (kubectl apply z oficiálneho manifestu)
- nainštaluje Gitea (Ingress host: gitea.local)
- zaregistruje Gitea repo v ArgoCD a sprístupní ArgoCD cez Ingress (argocd.local)

## Predpoklady
- minikube, kubectl, helm, git, curl, python3

## Rýchly štart
1) Skopíruj .env.example na .env:
   cp .env.example .env

2) Spusti:
   make up

3) Pridaj do /etc/hosts (podľa výstupu make up):
   <MINIKUBE_IP> gitea.local argocd.local

4) Otvor Gitea:
   http://gitea.local
   login: admin / admin12345  (workshop demo)

5) Otvor ArgoCD:
   http://argocd.local
   login: admin / <initial password z výstupu make up>

6) Vytvor repo v Gitea (UI alebo API):
   - admin/gitops-infra  (hlavný GitOps repozitár)

7) Vlož manifesty / Helm chart do gitops-infra a vytvor ArgoCD Application.

## Struktura
```
workshop_05/lab/
  .env.example        – vzorové premenné prostredia
  makefile            – orchestrácia (make up / down / reset / verify)
  manifests/
    namespaces.yaml   – namespace gitea, argocd
    ingresses.yaml    – Ingress pre Gitea aj ArgoCD
  scripts/
    00-check.sh       – kontrola nástrojov
    10-minikube-up.sh – štart minikube + ingress addon
    30-argocd-install.sh  – inštalácia ArgoCD
    40-gitea-install.sh   – inštalácia Gitea (Helm)
    50-argocd-configure.sh – registrácia repo + Ingress
    60-print-access.sh     – výpis prístupových údajov
  values/
    gitea-values.yaml – Helm values pre Gitea
```

## Dôležité poznámky
- ArgoCD beží v namespace `argocd`, server v insecure režime (TLS terminuje nginx ingress).
- Gitea beží v namespace `gitea`, dostupná cez http://gitea.local.
- Počiatočné heslo ArgoCD admina: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Troubleshooting
- Ak nevidíš ingress IP:
  kubectl -n ingress-nginx get pods
- Ak Gitea nebeží:
  kubectl -n gitea get pods
  kubectl -n gitea logs deploy/gitea
- Ak ArgoCD nebeží:
  kubectl -n argocd get pods
  kubectl -n argocd logs deploy/argocd-server
