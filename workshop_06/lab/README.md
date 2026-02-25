# LAB_06 – Prerekvizity a Quick Start

## Prerekvizity

| Nástroj | Kontrola |
|---|---|
| `crc` (OpenShift Local) | `crc status` |
| `oc` CLI | `oc version` |
| `kubectl` | `kubectl version --client` |
| `tkn` (Tekton CLI) | `tkn version` |
| `helm` | `helm version` |
| `git` | `git --version` |
| `curl` | `curl --version` |
| `jq` | `jq --version` |

## Spustenie klastra

```bash
crc start
eval $(crc oc-env)
```

## Admin Quick Start

```bash
cd workshop_06/lab
cp .env.example .env
# vyplň GITEA_ADMIN_PASS (TOKEN doplníš po nastavení Gitea)
chmod 774 ./scripts/*.sh

# krok 1: nastav klaster (operátory, gitea, namespaces)
make admin-up

# krok 2: v Gitea UI vytvor repozitáre a token, vlož do .env
# krok 3: dokončí CICD (Tekton manifesty, ArgoCD konfigurácia)
make cicd-up

# vypíš prístupy
make info
```

## Developer Quick Start

```bash
oc login -u developer -p developer https://api.crc.testing:6443
# Pozri lab.md – Cvičenia 2–9
```

## Užitočné príkazy

```bash
make verify       # skontroluj stav komponentov
make info         # vypíš URL a prihlasovacie údaje
make admin-down   # zmaž všetky workshop resources (nie CRC klaster)
```
