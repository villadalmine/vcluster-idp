# Post 03 — Recursion: a cluster that creates & serves its own child

**Tags:** Kubernetes · ClusterAPI · Crossplane · KubeVirt · ArgoCD · CAAPH · GitOps · PlatformEngineering · Homelab

> Homelab lab. The point is the **pattern**: the same "declare in Git → a controller reconciles" works at
> every level — a tenant, a region, and a *management-of-managements*.

---

## ▶️ Assets

| Asset | Link |
|---|---|
| **Recursion walk** (Root → host-mgmt → mgmt-child → tenant-z, live) | https://asciinema.org/a/gYZPWvobOhFDr0Ew |
| Architecture diagram | [`bonus/recursion-architecture.png`](../bonus/recursion-architecture.png) |
| Topology showcase (all 6 models, recursion = section 6) | https://asciinema.org/a/w2oxEgyacAJSRDQI |
| Source | [`clusters/management/`](../clusters/management/) (mgmt-child + CAAPH + region-root) |

---

## The idea

I built a Kubernetes cluster that **builds another cluster** — which then **builds its own tenants**.
Turtles all the way down. 🐢

The same pattern repeats at every level: *declare the desired state in Git, a controller reconciles it.*
Only **what** is reconciled changes (a VM, a cluster, a tenant) — not **how**.

## The chain (all live)

1. **Root** (k3s, bare metal) runs Crossplane + Cluster API + KubeVirt + a central ArgoCD. It creates host
   clusters whose **nodes are KubeVirt VMs**. One of them is `role=management`.
2. **host-mgmt** isn't just a workload host — it runs its **own** full Cluster API + **CAAPH** (the Cluster
   API Add-on Provider for Helm). It **creates its own child** (`mgmt-child`) via CAPK *external-infra* (the
   child's VMs run on **Root's** KubeVirt, since host-mgmt has no hypervisor of its own).
3. host-mgmt then **delivers the child the same stack Root gives its regionals** — ArgoCD (via a CAAPH
   `HelmChartProxy`), a `region-root` (via a `ClusterResourceSet`), and the CNI (chicken-and-egg: a cluster
   can't run ArgoCD without a CNI, so it's seeded from outside first).
4. So **mgmt-child ends up decentralized**: its **own** ArgoCD provisions **its** region's tenants — e.g.
   `vcluster-tenant-z` running Postgres + API + Web. Each cluster runs its own ArgoCD → **no central SPOF**.

## Why it's cool

- It's **fractal**: the management plane isn't a single special cluster — any cluster can become a
  management that creates and fully serves its children. That's how you scale a fleet hierarchically.
- **No central control-plane SPOF**: ArgoCD is sharded per cluster; if one dies, its blast radius is bounded.
- The whole chain was validated **clean-room**: torn down in reverse (tenant → child → management) and
  rebuilt **100% from Git** — proving it's reproducible, not hand-assembled.

## Key tech

`Cluster API` (clusters as objects) · `CAPK` (nodes as KubeVirt VMs) · **external-infra** (a child's VMs on
another cluster's hypervisor) · `CAAPH` (installs ArgoCD *into* a cluster) · `ClusterResourceSet` (seeds CNI
+ region-root) · `Crossplane` (the `HostCluster` API) · decentralized `ArgoCD` per cluster.

---

## Version EN (copy-paste)

I built a Kubernetes cluster that builds another cluster — which then builds its own tenants. Turtles all the way down. 🐢

It's a "management-of-managements", and the whole chain is live:

🟦 Root (k3s, bare metal) runs Crossplane + Cluster API + KubeVirt. It creates host clusters whose NODES are VMs.
🟪 host-mgmt isn't just a workload host — it runs its OWN Cluster API + CAAPH and creates its OWN child cluster (mgmt-child), whose VMs run on Root's KubeVirt (external-infra).
🟩 host-mgmt then hands the child the SAME stack Root gives its regionals: its own ArgoCD + a region-root + the CNI.
🟧 so mgmt-child ends up decentralized — its OWN ArgoCD provisions its OWN tenants (a vCluster running Postgres + API + Web).

The point is the pattern: the same "declare in Git → a controller reconciles" works at every level — a tenant, a region, a management. Each cluster runs its own ArgoCD, so there's no central control-plane single point of failure. And the whole chain was validated clean-room: torn down in reverse and rebuilt 100% from Git.

▶️ Watch the walk: https://asciinema.org/a/gYZPWvobOhFDr0Ew
📊 Architecture in the image.

#Kubernetes #ClusterAPI #Crossplane #KubeVirt #ArgoCD #GitOps #PlatformEngineering #Homelab

---

## Version ES (copia-pega)

Construí un cluster de Kubernetes que construye otro cluster — que después construye sus propios tenants. Tortugas hasta el fondo. 🐢

Es un "management-of-managements", y toda la cadena está viva:

🟦 Root (k3s, bare metal) corre Crossplane + Cluster API + KubeVirt. Crea host clusters cuyos NODOS son VMs.
🟪 host-mgmt no es solo un host de workloads — corre su PROPIO Cluster API + CAAPH y crea su PROPIO hijo (mgmt-child), cuyas VMs corren sobre el KubeVirt del Root (external-infra).
🟩 host-mgmt le entrega al hijo el MISMO stack que Root les da a sus regionales: su propio ArgoCD + un region-root + el CNI.
🟧 así mgmt-child queda descentralizado — su PROPIO ArgoCD provisiona sus PROPIOS tenants (un vCluster con Postgres + API + Web).

Lo importante es el patrón: el mismo "declarás en Git → un controlador reconcilia" funciona en todos los niveles — un tenant, una región, un management. Cada cluster corre su propio ArgoCD, así que no hay punto único de falla del control plane. Y toda la cadena se validó clean-room: destruida en reversa y reconstruida 100% desde Git.

▶️ Mirá el recorrido: https://asciinema.org/a/gYZPWvobOhFDr0Ew
📊 La arquitectura en la imagen.

#Kubernetes #ClusterAPI #Crossplane #KubeVirt #ArgoCD #GitOps #PlatformEngineering #Homelab

---

## Notes (no publicar)
- Lab. Marcar que es homelab. La cadena está viva y verificada (fleet-test kc host-mgmt / mgmt-child).
- Video walk = bonus/recursion.sh (usa jump pods de fleet-test, 2 niveles). Diagrama = bonus/recursion-architecture.dot.
- Defensa: external-infra (VMs del hijo sobre el KubeVirt del Root), CAAPH instala ArgoCD, CRS seedea CNI+region-root, ArgoCD descentralizado por cluster.
