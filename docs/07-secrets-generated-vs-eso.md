---
title: Per-tenant secrets in GitOps — generated vs External Secrets
---

# Per-tenant secrets in GitOps — generated vs External Secrets

*A secret should never live in Git. So how does a GitOps platform give every tenant a database password? Two
backends, one flag. A homelab lab.*

[← all posts](./index.html)

## The golden rule

Git holds **desired state**, not secret **material**. Plaintext secrets in Git = game over. So a GitOps
platform needs a way to hand each tenant a credential (a Postgres password, here) **without** that value ever
touching the repo.

This platform supports two backends, switched by one knob in the tenant file: `secretBackend: generated | eso`.

## Default — in-cluster generated

The tenant chart generates the Postgres password **in the cluster** with Helm (`randAlphaNum`), and re-uses it
on re-sync via `lookup`. The crucial detail: `/data` is in **`ignoreDifferences`**, so ArgoCD doesn't see the
live secret as "drift" and rotate it on every sync.

- ✅ Simple, zero external dependencies, nothing sensitive in Git.
- ⚠️ Trade-off: **no rotation, no central audit, no dynamic secrets.**

> The `ignoreDifferences` detail is the one that bites people in production — without it, ArgoCD "fixes" the
> secret each sync and silently rotates the password out from under the app.

## Opt-in — External Secrets Operator (ESO)

Flip `secretBackend: eso` in the tenant file and a per-namespace generator produces the secret **in-cluster**
from a real backend (Vault / cloud Secrets Manager) via an `ExternalSecret` **reference**. Git stores only the
*reference*, never the value.

This is the path to **rotation**, **per-tenant policy/paths**, and **Workload-Identity bootstrap** (no static
creds).

## The spectrum — when each fits

- **generated** — dev / CI, simplest, no external deps.
- **ESO + Vault/OpenBao** — prod: rotation, audit, dynamic secrets.
- **SOPS** — encrypt *in* Git, no external backend.

Pick by your compliance + ops maturity. Same chart, one flag — so a tenant can start on `generated` and move
to `eso` without rewriting anything.

## The YAML that makes it work
- [`charts/tenant/templates/secret.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/charts/tenant/templates/secret.yaml) — the generated backend (`randAlphaNum` + `lookup` re-use; `/data` in `ignoreDifferences`).
- [`applicationsets/eso-appset.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/applicationsets/eso-appset.yaml) — the ESO opt-in path (per-namespace `ExternalSecret`, Git holds only the reference).

---

<sub>Source: <a href="https://github.com/villadalmine/vcluster-idp/tree/main/charts/tenant">charts/tenant/</a> ·
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/applicationsets">applicationsets/</a>.</sub>
