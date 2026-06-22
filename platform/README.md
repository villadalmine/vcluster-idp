# platform/ — cluster bootstrap & add-ons (app-of-apps)

Fully decentralized GitOps. The **management cluster scope is CAPI only**:

1. **CAPI** — create / upgrade / delete host clusters.
2. On creation, **seed** each new cluster with its own ArgoCD + `platform-root` via a
   **CAPI ClusterResourceSet** (`clusters/bootstrap-crs.yaml`, one-shot).

There is **no central ArgoCD**. After the seed, **each host cluster's own ArgoCD**
connects to Git and reconciles everything itself. The mgmt does **not** deploy tenants.

```
management cluster (CAPI only)            host cluster — its OWN ArgoCD (same pattern x N)
  └─ create cluster ───────────────────►   ArgoCD ──pulls──► Git
  └─ CRS seeds ArgoCD + platform-root ─►   platform-root (app-of-apps)
                                              └─ addons/ ──► tenant-applicationsets
                                                                ├─ appset #1 → vClusters
                                                                └─ appset #2 → workloads (Helm chart)
```

## Files

- `root-app.yaml` — the **app-of-apps** root. The mgmt installs this on each new
  host cluster. It syncs `addons/`.
- `addons/applicationsets.yaml` — child app that installs the tenant ApplicationSets
  into the cluster's ArgoCD (which then provision vClusters + deploy workloads).
- `addons/` is where other **platform services** belong as Applications
  (cert-manager config, Cilium/Gateway, observability agents). On the homelab these
  are already installed cluster-wide; in a fresh cluster they'd be added here.

## Apply (on a host cluster that already has ArgoCD)

```bash
kubectl apply -f platform/root-app.yaml
# platform-root → addons/ → tenant-applicationsets → appsets → vClusters + workloads
```

This replaces the imperative `make appsets` with the declarative app-of-apps chain.
`make appsets` stays as a demo shortcut.

## Why decentralized (ArgoCD per cluster) and not one central ArgoCD

- **Blast radius / autonomy**: each environment reconciles itself; the mgmt ArgoCD
  is not a single point of failure for tenant runtime (ADR-11).
- **Scale**: a central ArgoCD managing every cluster becomes a bottleneck; per-cluster
  ArgoCD scales horizontally with the fleet.
- **Clear ownership**: mgmt = cluster lifecycle (SRE); each cluster = its own
  platform services + tenants, reconciled from the same Git source of truth (ADR-13).
