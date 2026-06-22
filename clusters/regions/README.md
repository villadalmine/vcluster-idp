# Regiones y vClusters — modelo descentralizado, parametrizado por región

## La idea (descentralizado)

El cluster **management** (k8s real, con ArgoCD + CAPI + Crossplane) **crea clusters**, pero NO
deploya los tenants. Cada cluster regional tiene **su propio ArgoCD** y despliega **sus** vClusters.
Así escala: N regiones × N vClusters, sin que el management sea cuello de botella.

```
management k8s (ArgoCD + CAPI + Crossplane)
  └─ HostCluster XR (clusters/homelab/host-<region>.yaml)   role=management, region=<region>
        │  Composition → CAPI/KubeVirt → cluster regional (VMs en Longhorn)
        ├─ CAAPH HelmChartProxy  → instala ArgoCD DENTRO del cluster regional
        └─ ClusterResourceSet region-root  (matchLabels platform.idp/region=<region>)
              → siembra el Application "region-root" en el ArgoCD regional
                   path = clusters/regions/<region>/apps   (overlay kustomize)
                        ├─ vclusters-<region>   (ApplicationSet) → 1 vCluster por tenant
                        ├─ workloads-<region>   (ApplicationSet) → charts/tenant DENTRO de cada vCluster
                        ├─ vcluster-register    (CronJob) → registra cada vCluster como cluster ArgoCD
                        └─ local-path-storage   → storage para los vClusters
```

## Parametrización (sin hardcodear la región en cada appset)

Mismo concepto que el campo `cni` (calico/calico-vxlan/cilium) o `cpInitTimeout`: **una pieza
compartida + un valor por instancia**.

- **`clusters/regions/_base/`** — la base COMPARTIDA: los 4 apps. `vcluster-register` y
  `local-path-storage` son region-agnostic. Los 2 ApplicationSets llevan el token literal `REGION`
  en: `metadata.name`, el `path` del generador de git, y el label `platform.idp/region`.
- **`clusters/management/region-root-<region>.yaml`** — la **única** pieza por región. Es un
  `Application` que apunta DIRECTO a `clusters/regions/_base` y, con `source.kustomize.patches`,
  reemplaza `REGION → <region>` (3 campos × 2 appsets). No hay overlay dir ni referencias `../`
  (así ArgoCD lo buildea sin tocar el load-restrictor). Es 1 archivo chico.
- **`clusters/regions/<region>/tenants/<env>/<tenant>.yaml`** — los tenants (la data). El
  `vclusters-appset` genera **1 vCluster por archivo**, nombre `vcluster-<tenant>-<environment>`.

No se duplica el cuerpo de los appsets: vive una sola vez en `_base`. El render con los patches del
region-root queda idéntico a tener los appsets escritos a mano con la región, pero sin copiar/pegar.

## Cómo agregar una REGIÓN nueva (ej: `dev`)

1. **El cluster** — `clusters/homelab/host-dev.yaml` (HostCluster XR):
   ```yaml
   spec:
     role: management
     region: dev
     cni: calico-vxlan        # KubeVirt anidado: IPIP no pasa el masquerade → VXLAN (ver INCIDENTES)
     cpInitTimeout: "15m0s"   # boot lento sobre Longhorn
     workerReplicas: 2        # dimensionar: N vClusters + sus pods (postgres+api+web) no entran en 1 worker chico
     cpuCores: 4
     memory: "8Gi"
   ```
2. **El region-root de la región** — en `clusters/management/`:
   - `region-root-dev.yaml` = copia de `region-root-eu-west1.yaml` cambiando `eu-west1` → `dev` en
     los 6 patches (apunta a `_base`, no hay overlay dir).
   - el CRS que lo siembra (`region-root-crs.yaml` con `matchLabels platform.idp/region: dev`) +
     las entradas en `clusters/management/kustomization.yaml`.
   *(El region-root + su CRS es lo único que aún se copia por región — chico; se puede colapsar a
   futuro generando el seed desde un ApplicationSet del management sobre `clusters/regions/*`.)*
4. **Los tenants** — `clusters/regions/dev/tenants/{dev,acc,prd,tst}/tenant-a.yaml`, cada uno con
   `environment: dev|acc|prd|tst`. → **4 vClusters: `vcluster-tenant-a-{dev,acc,prd,tst}`**.

## Cómo agregar un vCluster a una región existente

Un archivo: `clusters/regions/<region>/tenants/<env>/<tenant>.yaml`. El `vclusters-appset` lo
agarra (requeue 30s) y materializa el vCluster. Nada más.

## Acceder a la API de un vCluster (debug)

El kubeconfig del secret `vc-<ns>` (key `config`) está hecho para `localhost:8443` (port-forward):
```
kubectl -n <ns> port-forward svc/<release> 8443:443 &     # release==ns==vcluster-<tenant>-<env>
KUBECONFIG=<config-del-secret> kubectl get pods -A
```
o `vcluster connect <release> -n <ns>`. (El cert valida para localhost; por service falla la CA.)
