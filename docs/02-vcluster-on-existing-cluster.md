---
title: vCluster on an existing cluster (the concept)
---

# vCluster on an existing cluster

*Give every tenant their own Kubernetes cluster — without paying for one. A homelab lab.*

[← all posts](./index.html)

## The concept

A **vCluster** is a *virtual* Kubernetes cluster that runs **as pods on top of an existing cluster**. Each
tenant gets its **own API server + etcd** (a real control plane), while the **worker nodes are shared** with
the host. The tenant is cluster-admin **inside** its vCluster — it can install CRDs, operators, its own RBAC —
without touching the host or the other tenants.

It beats *namespace-as-a-service* (where everyone shares one control plane and one bad CRD/webhook hits the
whole cluster), at a fraction of the cost of a real cluster per tenant.

## Overview — what we have & how it's wired

<script src="https://asciinema.org/a/OR3lKd81K3zGNI4i.js" id="asciicast-OR3lKd81K3zGNI4i" async></script>

[(watch on asciinema)](https://asciinema.org/a/OR3lKd81K3zGNI4i)

## How we integrate it (GitOps)

One file per tenant in Git → an **ArgoCD ApplicationSet** (git generator) materializes, per tenant:

1. **the vCluster** — the vCluster **Helm chart**, with our `shared-nodes` values;
2. **the workload** — a Helm chart (namespace, quota, NetworkPolicy, Secret, Postgres, API, Web) deployed **inside** that vCluster;
3. **the route** — Gateway/HTTPRoute + TLS on the host.

A small CronJob registers each new vCluster as an ArgoCD target so the workload lands inside it. **Adding a
tenant is one Git commit; deleting is removing the file** (ArgoCD prunes, a GC reconciles the leftovers).

## The lifecycle

**Add** a vCluster (one commit → ArgoCD provisions it):
<script src="https://asciinema.org/a/deIAZiSuxuB8RAo6.js" id="asciicast-deIAZiSuxuB8RAo6" async></script>

**Validate** it (functional checks against the live tenant):
<script src="https://asciinema.org/a/OPuNETxXnTwzKVhT.js" id="asciicast-OPuNETxXnTwzKVhT" async></script>

**Delete** it (prune + GC, no leftovers):
<script src="https://asciinema.org/a/Wd5gdGCF5PMgcXVA.js" id="asciicast-Wd5gdGCF5PMgcXVA" async></script>

## What we decided — and why (lab scope)

We run **shared-nodes** vCluster: real control-plane isolation (own API/etcd/CRDs) with **minimal overhead**
(a small control-plane pod per tenant). The honest residual risk is the **shared node kernel**
(noisy-neighbour / kernel escape). That's the right trade-off for a **dev/CI, cost-sensitive, high-rotation
lab** — which is exactly what this demonstrates.

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

## vCluster has other models — pick by the isolation you need

shared-nodes is **one rung**. The official docs describe a spectrum, from a plain namespace to fully separate
clusters. When each fits:

| Model | Isolates | When |
|---|---|---|
| Namespaces | logical scope | trusted internal teams, CI |
| **Shared Nodes** *(what we run)* | control plane (API/etcd/CRDs) | dev/CI, cost-sensitive, high rotation |
| vNode (virtual nodes) | + **kernel** (sandbox runtime) on shared HW | multi-tenant security **without** dedicating hardware |
| Dedicated Nodes | a labelled node pool (compute) | prod, ML/**GPU**, predictable per-tenant capacity |
| Private Nodes | real worker nodes per tenant | regulated / paying customers |
| Separate clusters | the whole stack | siloed enterprise, per-customer compliance |

**Don't over-isolate** — go up one rung at a time, by the isolation you actually need. More in the vCluster
docs: [architecture &amp; tenancy](https://www.vcluster.com/docs/vcluster/introduction/architecture).

## The YAML that makes it work
- [`vcluster/shared-nodes.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/vcluster/shared-nodes.yaml) — the vCluster values we chose (shared-nodes).
- [`applicationsets/hosts-appset.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/applicationsets/hosts-appset.yaml) — generates the vCluster per tenant.
- [`applicationsets/tenants-appset.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/applicationsets/tenants-appset.yaml) — deploys the workload chart INSIDE each vCluster.
- [`applicationsets/routes-appset.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/applicationsets/routes-appset.yaml) — the host-side Gateway/HTTPRoute + TLS.
- [`charts/tenant/`](https://github.com/villadalmine/vcluster-idp/tree/main/charts/tenant) — the tenant workload chart (ns, quota, netpol, Secret, Postgres, API, Web).
- [`platform/vcluster-register/vcluster-register.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/platform/vcluster-register/vcluster-register.yaml) — the CronJob that registers each vCluster in ArgoCD.

---

<sub>Manifests &amp; scripts:
<a href="https://github.com/villadalmine/vcluster-idp">github.com/villadalmine/vcluster-idp</a>
(<a href="https://github.com/villadalmine/vcluster-idp/blob/main/vcluster/shared-nodes.yaml">shared-nodes.yaml</a>,
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/applicationsets">applicationsets/</a>,
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/charts/tenant">charts/tenant</a>).</sub>
