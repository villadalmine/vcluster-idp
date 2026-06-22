---
title: Platform & infra notes
---

# Platform &amp; infra notes

Short posts on Kubernetes, GPUs, multi-tenancy and platform engineering — built and recorded on a homelab.

## Posts

- **[Multi-tenant GPU on bare metal (HAMi)](./01-multitenant-gpu-hami.html)**
  3 isolated tenants share 2 physical GPUs (no MIG, no passthrough). Each runs a local LLM (Ollama) that
  tells a Kubernetes story — and the GPU is hard-capped and metered per tenant.

---

<sub>Source &amp; manifests: <a href="https://github.com/villadalmine/vcluster-idp">github.com/villadalmine/vcluster-idp</a></sub>
