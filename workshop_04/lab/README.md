# Helm + Tekton + Gitea workshop infra (minikube)

## Čo to spraví
- spustí minikube + ingress addon
- zapne minikube registry addon (+ registry-aliases)
- nainštaluje Tekton Pipelines + Triggers
- nainštaluje Gitea (Ingress host: gitea.local)
- aplikuje Tekton Tasks/Pipeline/Triggers pre CI:
  push do main -> clone -> npm ci -> (test+lint paralelne) -> kaniko build+push -> update helm repo values tag

## Predpoklady
- minikube, kubectl, helm, git
- (voliteľné) tkn CLI

## Rýchly štart
1) Skopíruj .env.example na .env a doplň token:
   cp .env.example .env

2) Spusti:
   make up

3) Pridaj do /etc/hosts (podľa výstupu make up):
   <MINIKUBE_IP> gitea.local

4) Otvor Gitea:
   http://gitea.local
   login: admin / admin12345  (workshop demo)

5) Vytvor 2 repá v Gitea (UI):
   - admin/app-repo
   - admin/helm-repo

6) Napushuj sample obsah (z tohto repa):
   - samples/app-repo -> app-repo
   - samples/helm-repo -> helm-repo

   Tip (HTTP token):
   git remote set-url origin http://admin:<TOKEN>@gitea.local/admin/app-repo.git

7) Nastav webhook v app-repo:
   Repo -> Settings -> Webhooks -> Add Webhook (Gitea)
   Payload URL:
     http://el-gitea-listener.cicd.svc.cluster.local:8080
   Events: Push events

8) Urob commit do app-repo na main a pushni.
   Sleduj PipelineRun:
     kubectl -n cicd get pipelineruns -w
   alebo:
     tkn pr logs -n cicd -L

## Dôležité poznámky
- minikube registry addon je v kube-system namespace, service "registry" na porte 5000.
  Image repo v clustri používame:
    registry.kube-system.svc.cluster.local:5000/myapp:<tag>

- Pipeline aktualizuje v helm-repo súbor:
    myapp/values-dev.yaml
  a mení .image.tag na nový SHA.

## Troubleshooting
- Ak nevidíš ingress IP:
  kubectl -n ingress-nginx get pods
- Ak Gitea nebeží:
  kubectl -n gitea get pods
  kubectl -n gitea logs deploy/gitea
- Ak Triggers nefungujú:
  kubectl -n cicd get eventlistener,svc
  kubectl -n cicd logs deploy/el-gitea-listener
