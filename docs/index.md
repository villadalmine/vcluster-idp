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

<!-- add new rows here as you publish: | 02 | [Title](./02-slug.html) | ... | [▶︎](asciinema-link) | -->

---

<sub>These are the published pages — the links to share. Drafts &amp; copy-paste text for other platforms live in
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/post"><code>/post</code></a>.
Source &amp; manifests: <a href="https://github.com/villadalmine/vcluster-idp">github.com/villadalmine/vcluster-idp</a>.</sub>
