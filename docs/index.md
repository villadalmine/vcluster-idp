---
title: Platform & infra notes
---

# Platform &amp; infra notes

Hands-on posts on **Kubernetes, GPUs, multi-tenancy and platform engineering** — built, broken and recorded
on a homelab. Each post has a live terminal recording (asciinema) and the source on GitHub.

## Posts

| # | Post | What it shows | Watch |
|:--:|---|---|:--:|
| **01** | **[Multi-tenant GPU on bare metal (HAMi)](./01-multitenant-gpu-hami.html)** | 3 isolated tenants share 2 physical GPUs (no MIG, no passthrough). Each runs a local LLM that tells a Kubernetes story — hard-capped &amp; metered per tenant. | [▶︎](https://asciinema.org/a/eaoQKFsHhVDQ7qXc) |
| **02** | **[vCluster on an existing cluster](./02-vcluster-on-existing-cluster.html)** | What vCluster is, how we wire it with Helm + ArgoCD ApplicationSets, namespace-as-a-service vs vCluster, and when each vCluster isolation model fits. A homelab lab. | [▶︎](https://asciinema.org/a/OR3lKd81K3zGNI4i) |
| **03** | **[Recursion — management-of-managements](./03-recursion-management-of-managements.html)** | A Kubernetes cluster that creates AND serves its own child, which then provisions its own tenants. Cluster API + CAAPH + decentralized ArgoCD. Validated clean-room. | [▶︎](https://asciinema.org/a/gYZPWvobOhFDr0Ew) |
| **04** | **[A tenant is one Git commit (copy-and-run)](./04-copy-and-run-tenants.html)** | The CLI is a GitOps facade: a tenant = one commit. Auto-register CronJob + GC, idempotent, hands-off. | [▶︎](https://asciinema.org/a/deIAZiSuxuB8RAo6) |
| **05** | **[A fleet of clusters from one file](./05-fleet-kubevirt.html)** | Whole Kubernetes clusters from one YAML on a single bare-metal box — Crossplane + Cluster API + KubeVirt. | [▶︎](https://asciinema.org/a/lr5tg4GWV8KK5tF6) |

<!-- add new rows here as you publish: | 02 | [Title](./02-slug.html) | ... | [▶︎](asciinema-link) | -->

---

<sub>These are the published pages — the links to share. Drafts &amp; copy-paste text for other platforms live in
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/post"><code>/post</code></a>.
Source &amp; manifests: <a href="https://github.com/villadalmine/vcluster-idp">github.com/villadalmine/vcluster-idp</a>.</sub>
