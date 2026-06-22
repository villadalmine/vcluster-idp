# Post 04 — A tenant is one Git commit (copy-and-run)

**Tags:** Kubernetes · GitOps · ArgoCD · PlatformEngineering · DeveloperExperience · Homelab

> Homelab lab. The point: tenant lifecycle with **zero manual steps** — declare in Git, ArgoCD does the rest.

---

## ▶️ Assets
| Asset | Link |
|---|---|
| **Add a tenant** (one commit → fully provisioned, hands-off) | https://asciinema.org/a/deIAZiSuxuB8RAo6 |
| **Delete a tenant** (remove the file → prune + GC) | https://asciinema.org/a/Wd5gdGCF5PMgcXVA |
| Flow diagram | [`bonus/copyrun-architecture.png`](../bonus/copyrun-architecture.png) |
| CLI facade | [`cli/platform`](../cli/platform) |

## The idea

The CLI doesn't deploy anything. `platform <tenant> create` just **writes and commits**
`tenants/<env>/<tenant>.yaml` — the source of truth — and lets **ArgoCD reconcile** it. From one commit you
get: a vCluster, its auto-registration in ArgoCD, and the workload (Postgres + API + Web) deployed **inside**
it. **No kubectl, no helm, no manual register step.**

The piece that makes it truly hands-off: a `vcluster-register` **CronJob** that registers each new vCluster
as an ArgoCD target on its own — so the workload lands inside it without anyone wiring it up.

**Delete** is symmetric: remove the file → ArgoCD prunes the Apps → the same CronJob's **GC** reconciles the
leftovers (namespace, PVC, registration). And it's **idempotent**: re-running `create` re-asserts the same
desired state (no duplicates); `selfHeal` repairs drift; deleting a missing tenant is a no-op.

## Why it matters

Tenant onboarding/offboarding becomes a **pull request**, not a runbook. It's auditable, reviewable,
reversible, and self-healing — the difference between "a script someone ran" and "the cluster converges to
what Git says."

---

## Version EN (copy-paste)

Onboarding a tenant should be a pull request, not a runbook.

In my homelab platform, the CLI doesn't deploy anything. `platform <tenant> create` just writes and commits one file to Git — and ArgoCD does the rest:

📄 commit `tenants/<env>/<tenant>.yaml` (the source of truth)
🔁 ArgoCD ApplicationSets reconcile it → a vCluster + the workload (Postgres + API + Web) inside it
🤖 a vcluster-register CronJob auto-registers the new vCluster in ArgoCD — no manual step
➕ ~4 minutes later: a fully provisioned, isolated tenant

Delete is symmetric: remove the file → ArgoCD prunes → the same CronJob's GC reconciles the leftovers (namespace, PVC, registration). And it's idempotent: re-create re-asserts the same state, selfHeal repairs drift, deleting a missing tenant is a no-op.

A tenant becomes auditable, reviewable, reversible, self-healing — not "a script someone ran once."

▶️ Add: https://asciinema.org/a/deIAZiSuxuB8RAo6  ·  Delete: https://asciinema.org/a/Wd5gdGCF5PMgcXVA

#Kubernetes #GitOps #ArgoCD #PlatformEngineering #DevEx #Homelab

---

## Version ES (copia-pega)

Dar de alta un tenant debería ser un pull request, no un runbook.

En mi plataforma de homelab, el CLI no despliega nada. `platform <tenant> create` solo escribe y commitea un archivo a Git — y ArgoCD hace el resto:

📄 commit de `tenants/<env>/<tenant>.yaml` (la fuente de verdad)
🔁 los ApplicationSets de ArgoCD lo reconcilian → un vCluster + el workload (Postgres + API + Web) adentro
🤖 un CronJob vcluster-register auto-registra el nuevo vCluster en ArgoCD — sin pasos manuales
➕ ~4 minutos después: un tenant aislado, provisionado de punta a punta

La baja es simétrica: borrás el archivo → ArgoCD prunea → el GC del mismo CronJob reconcilia lo que queda (namespace, PVC, registro). Y es idempotente: re-crear re-afirma el mismo estado, selfHeal repara el drift, borrar un tenant inexistente es no-op.

Un tenant pasa a ser auditable, revisable, reversible y self-healing — no "un script que alguien corrió una vez".

▶️ Alta: https://asciinema.org/a/deIAZiSuxuB8RAo6  ·  Baja: https://asciinema.org/a/Wd5gdGCF5PMgcXVA

#Kubernetes #GitOps #ArgoCD #PlatformEngineering #DevEx #Homelab

---

## Notes (no publicar)
- Lab. Reusa los videos Add/Delete (ya muestran exactamente esto).
- La pieza clave hands-off: el CronJob de auto-registro + el GC (platform/vcluster-register/). Idempotencia/drift: selfHeal+prune en tenants-appset.
