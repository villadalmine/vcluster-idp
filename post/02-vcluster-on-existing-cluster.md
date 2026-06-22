# Post 02 — vCluster on an existing cluster (the concept)

**Tags:** Kubernetes · vCluster · multi-tenancy · ArgoCD · Helm · ApplicationSet · PlatformEngineering · Homelab

> This is a **homelab lab**, not production. The goal is to show the *concept* and how we wired it
> (Helm + ArgoCD ApplicationSets) — and to be honest about which isolation model we picked and why.

---

## ▶️ Assets

| Video | Link | Source |
|---|---|---|
| **vCluster overview** — what we have + how it's wired | https://asciinema.org/a/OR3lKd81K3zGNI4i | [`bonus/vc-overview.sh`](../bonus/vc-overview.sh) |
| **Add a vCluster** (one Git commit → ArgoCD provisions it) | https://asciinema.org/a/deIAZiSuxuB8RAo6 | `cli/platform create` |
| **Validate** a vCluster (functional checks) | https://asciinema.org/a/OPuNETxXnTwzKVhT | `cli/validate` |
| **Delete a vCluster** (prune + GC) | https://asciinema.org/a/Wd5gdGCF5PMgcXVA | `cli/platform delete` |

Config we chose: [`vcluster/shared-nodes.yaml`](../vcluster/shared-nodes.yaml) · Generators: [`applicationsets/`](../applicationsets/) · Workload chart: [`charts/tenant/`](../charts/tenant/)

---

## The concept

A **vCluster** is a *virtual* Kubernetes cluster that runs **as pods on top of an existing cluster**. Each
tenant gets its **own API server + etcd** (a real control plane), while the **worker nodes are shared** with
the host. The tenant is cluster-admin **inside** its vCluster — it can install CRDs, operators, its own RBAC —
without touching the host or the other tenants.

So instead of *namespace-as-a-service* (everyone shares one control plane), each tenant gets a "cluster" they
can actually `kubectl apply` CRDs and Helm charts into — at a fraction of the cost of a real cluster.

## How we integrate it (GitOps)

One file per tenant in Git → an **ArgoCD ApplicationSet** (git generator) materializes, per tenant:
1. **the vCluster** (the vCluster **Helm chart**, with our [`shared-nodes.yaml`](../vcluster/shared-nodes.yaml) values),
2. **the workload** ([`charts/tenant`](../charts/tenant): namespace, quota, NetworkPolicy, Secret, Postgres, API, Web) deployed **inside** that vCluster,
3. **the route** (Gateway/HTTPRoute + TLS) on the host.

A small CronJob registers each new vCluster as an ArgoCD target so the workload lands inside it. Adding a
tenant = one commit; deleting = remove the file (ArgoCD prunes + a GC reconciles leftovers).

## What we decided — and why (lab scope)

We run **shared-nodes** vCluster: real control-plane isolation (own API/etcd/CRDs) with **minimal overhead**
(a small control-plane pod per tenant). The honest residual risk is the **shared node kernel** (noisy
neighbour / kernel escape). That's the right trade-off for a **dev/CI, cost-sensitive, high-rotation lab** —
and it's exactly what the lab sets out to demonstrate.

## Namespace-as-a-Service vs vCluster (shared-nodes)

| Aspect | Namespace-as-a-Service | vCluster (shared-nodes) |
|---|---|---|
| Control plane | **shared** (one API server / etcd / scheduler) | **own** API server + etcd per tenant |
| CRDs / operators | shared — a tenant's CRD affects everyone | **isolated** — tenant installs its own, safely |
| API versions / webhooks | shared | per tenant |
| RBAC | host RBAC; scope leaks easily | tenant is admin **only inside** its vCluster |
| Nodes / kernel | shared | shared (shared-nodes) |
| Overhead / cost | ~zero | low (one small CP pod per tenant) |
| Blast radius | cluster-wide | bounded to the vCluster |
| Tenant gets… | a namespace | a "cluster" (kubeconfig, CRDs, Helm, operators) |
| Best for | trusted internal teams, CI | tenants needing real cluster-admin without a real cluster |

## vCluster has other models — pick by the isolation you actually need

shared-nodes is one rung. The official docs describe a **spectrum** (from a plain namespace to fully
separate clusters). When each fits (short version):

| Model | Isolates | When |
|---|---|---|
| Namespaces | logical scope | trusted internal teams, CI |
| **Shared Nodes** *(what we run)* | control plane (API/etcd/CRDs) | dev/CI, cost-sensitive, high rotation |
| vNode (virtual nodes) | + **kernel** (sandbox runtime) on shared HW | multi-tenant security **without** dedicating hardware |
| Dedicated Nodes | a labelled node pool (compute) | prod, ML/**GPU**, predictable per-tenant capacity |
| Private Nodes | real worker nodes per tenant | regulated / paying customers |
| Separate clusters | the whole stack | siloed enterprise, per-customer compliance |

> 📖 Don't over-isolate: go up one rung at a time, by need. vCluster docs:
> [Tenancy models](https://www.vcluster.com/docs/vcluster/introduction/architecture) ·
> [Shared vs private nodes](https://www.vcluster.com/docs). Our full research:
> [`VCLUSTER-AISLAMIENTO-MODELOS.md`] (working notes).

---

## Version EN (copy-paste)

What if every tenant got their own Kubernetes cluster — without paying for one? 🧩

That's vCluster: a virtual cluster that runs as pods ON an existing cluster. Each tenant gets its OWN API server + etcd (a real control plane), while the worker nodes are shared. The tenant can install CRDs, operators, its own RBAC — isolated from everyone else, at a fraction of the cost of a real cluster.

It beats "namespace-as-a-service" where everyone shares one control plane (one bad CRD or webhook hits the whole cluster).

How I wired it (GitOps):
📄 one file per tenant in Git
🔁 an ArgoCD ApplicationSet turns it into → a vCluster (Helm) + the workload chart INSIDE it + a route with TLS
➕ adding a tenant = one commit; ❌ deleting = remove the file (ArgoCD prunes)

What I picked (and I'm honest it's a lab): shared-nodes vCluster — real control-plane isolation, minimal overhead. Residual risk: the shared node kernel. The fix in production isn't "jump to separate clusters" — vCluster has a whole spectrum (namespaces → shared nodes → vNode → dedicated nodes → private nodes → separate clusters); you go up one rung by the isolation you actually need.

namespace-as-a-service vs vCluster, the lifecycle (add/validate/delete), and the model table are in the post.

▶️ Overview: https://asciinema.org/a/OR3lKd81K3zGNI4i

#Kubernetes #vCluster #MultiTenancy #ArgoCD #Helm #PlatformEngineering #Homelab

---

## Version ES (copia-pega)

¿Y si cada tenant tuviera su propio cluster de Kubernetes — sin pagar uno? 🧩

Eso es vCluster: un cluster virtual que corre como pods SOBRE un cluster existente. Cada tenant tiene su PROPIO API server + etcd (un control plane real), y los worker nodes son compartidos. El tenant puede instalar CRDs, operators, su propio RBAC — aislado del resto, a una fracción del costo de un cluster real.

Le gana al "namespace-as-a-service" donde todos comparten un solo control plane (un CRD o webhook mal puesto afecta a todo el cluster).

Cómo lo integré (GitOps):
📄 un archivo por tenant en Git
🔁 un ApplicationSet de ArgoCD lo convierte en → un vCluster (Helm) + el chart del workload ADENTRO + una ruta con TLS
➕ agregar un tenant = un commit; ❌ borrar = borrar el archivo (ArgoCD prunea)

Qué elegí (y soy honesto: es un lab): vCluster shared-nodes — aislamiento real de control-plane, overhead mínimo. Riesgo residual: el kernel compartido del nodo. La solución en prod no es "saltar a clusters separados" — vCluster tiene todo un espectro (namespaces → shared nodes → vNode → dedicated nodes → private nodes → clusters separados); subís un escalón según el aislamiento que realmente necesitás.

La tabla namespace-as-a-service vs vCluster, el ciclo de vida (alta/validate/baja) y la tabla de modelos están en el post.

▶️ Overview: https://asciinema.org/a/OR3lKd81K3zGNI4i

#Kubernetes #vCluster #MultiTenancy #ArgoCD #Helm #PlatformEngineering #Homelab

---

## Notes (no publicar)
- Es un lab — remarcarlo siempre. shared-nodes es lo que corre; el resto del espectro es research/defensa.
- Lifecycle: reusar los videos Add/Validate/Delete (ya son alta/baja de un vCluster + validate).
- Research completa en VCLUSTER-AISLAMIENTO-MODELOS.md (local).
