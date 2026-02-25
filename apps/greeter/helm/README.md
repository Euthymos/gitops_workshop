# Greeter Helm Chart

Helm chart pre workshop aplikáciu `greeter`.

## Prerekvizity

- Kubernetes cluster (alebo OpenShift)
- Helm 3.x

## Inštalácia

```bash
helm install greeter ./apps/greeter/helm
```

## Expozícia aplikácie

Chart podporuje dva režimy publikovania aplikácie:

- `ingress` (default)
- `route` (OpenShift)

Prepína sa cez hodnotu `exposure.type`.

### Kubernetes (Ingress)

```bash
helm install greeter ./apps/greeter/helm \
  --set exposure.type=ingress \
  --set ingress.enabled=true \
  --set ingress.host=greeter.local
```

### OpenShift (Route)

```bash
helm install greeter ./apps/greeter/helm \
  --set exposure.type=route \
  --set ingress.host=greeter.apps-crc.testing
```

> Pri `exposure.type=route` sa renderuje `Route` a `Ingress` sa nevytvorí.

## Hlavné hodnoty

| Hodnota | Typ | Default | Popis |
|---|---|---|---|
| `image.repository` | string | `quay.io/euthymos/workshop-greeter` | Názov image repository |
| `image.tag` | string | `latest` | Image tag |
| `image.pullPolicy` | string | `IfNotPresent` | Pull policy |
| `service.type` | string | `ClusterIP` | Typ Kubernetes Service |
| `service.port` | int | `8080` | Service port |
| `service.targetPort` | int | `8080` | Port kontajnera |
| `attendeeName` | string | `""` | Meno účastníka do ConfigMap |
| `exposure.type` | string | `ingress` | Režim expozície: `ingress` alebo `route` |
| `ingress.enabled` | bool | `true` | Zapnutie Ingress šablóny (iba pre `exposure.type=ingress`) |
| `ingress.ingressClassName` | string | `nginx` | Ingress class |
| `ingress.host` | string | `greeter.local` | Hostname pre Ingress/Route |
