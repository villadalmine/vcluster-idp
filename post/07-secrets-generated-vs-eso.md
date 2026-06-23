# Post 07 — Per-tenant secrets: generated vs External Secrets (PUBLISHED)

> **Published** → `docs/07-secrets-generated-vs-eso.md` (live on the blog + index row). No video.
> Assets used: `charts/tenant/templates/secret.yaml`, `applicationsets/eso-appset.yaml`,
> the `secretBackend: generated|eso` knob in the tenant file.
> The EN/ES blocks below are the copy-paste text for LinkedIn/X.

**Tags:** Kubernetes · Secrets · ExternalSecrets · GitOps · Security · Homelab

---

## The angle

A secret should **never** live in Git. So how does a GitOps platform give every tenant a database password?
This post shows the two backends we support and when each fits.

## What I'd cover

- **The golden rule:** Git holds *desired state*, not secret *material*. Plaintext secrets in Git = game over.
- **Default — in-cluster generated:** the tenant chart generates the Postgres password **in the cluster**
  with Helm (`randAlphaNum`), and re-uses it on re-sync via `lookup` — with `/data` in `ignoreDifferences`
  so ArgoCD doesn't see the live secret as "drift" and rotate it every sync. Simple, zero external
  dependencies, nothing sensitive in Git. Trade-off: **no rotation, no central audit, no dynamic secrets.**
- **Opt-in — External Secrets Operator (ESO):** flip `secretBackend: eso` in the tenant file and a
  per-namespace generator produces the secret **in-cluster** from a real backend (Vault/cloud SM) via an
  `ExternalSecret` *reference* — Git stores only the reference, never the value. This is the path to
  rotation, per-tenant policy/paths, and Workload-Identity bootstrap (no static creds).
- **The spectrum (when each):** generated (dev/CI, simplest) → ESO + Vault/OpenBao (prod, rotation, audit) →
  SOPS (encrypt *in* Git, no external backend). Pick by your compliance + ops maturity.

## Why it's a good post

Secrets-in-GitOps is the #1 "gotcha" everyone hits. Showing a clean default **plus** an opt-in real-backend
path (same chart, one flag) is a concrete, reusable pattern — and the `ignoreDifferences` detail is the kind
of thing that bites people in production.

---

## Version EN (draft copy-paste)

How do you give every tenant a database password in GitOps — without ever putting a secret in Git? 🔐

The rule: Git holds desired state, never secret material. Two backends, one flag in the tenant file:

🟢 generated (default): the chart generates the Postgres password IN the cluster (Helm randAlphaNum + lookup to reuse it), with /data in ignoreDifferences so ArgoCD doesn't "fix" it on every sync and rotate it by accident. Simple, no external deps — but no rotation/audit.

🔵 eso (opt-in): External Secrets Operator pulls from a real backend (Vault/cloud) via an ExternalSecret reference — Git stores only the reference, the value is created in-cluster. This is the path to rotation, per-tenant policy, and no static creds.

And for "encrypt in Git, no backend": SOPS.

Pick by your compliance + ops maturity — same chart, one knob: secretBackend: generated | eso.

#Kubernetes #Secrets #ExternalSecrets #GitOps #Security #Homelab

---

## Version ES (draft copia-pega)

¿Cómo le das a cada tenant una contraseña de base de datos en GitOps — sin meter nunca un secreto en Git? 🔐

La regla: Git tiene el estado deseado, nunca el material del secreto. Dos backends, un flag en el archivo del tenant:

🟢 generated (default): el chart genera la password de Postgres EN el cluster (Helm randAlphaNum + lookup para reusarla), con /data en ignoreDifferences para que ArgoCD no la "arregle" en cada sync y la rote sin querer. Simple, sin deps externas — pero sin rotación/auditoría.

🔵 eso (opt-in): External Secrets Operator la trae de un backend real (Vault/nube) vía una referencia ExternalSecret — Git guarda solo la referencia, el valor se crea in-cluster. Es el camino a rotación, policy por tenant y sin credenciales estáticas.

Y para "encriptar en Git, sin backend": SOPS.

Elegís según tu compliance + madurez de ops — mismo chart, una perilla: secretBackend: generated | eso.

#Kubernetes #Secrets #ExternalSecrets #GitOps #Seguridad #Homelab
