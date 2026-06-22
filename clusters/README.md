# clusters/ — Layer 1 (infrastructure, CAPI)

**Status: code + ADR. DOES NOT run in the demo** (see ADR-04 in the master plan).

Defines the **host clusters** on which the vClusters run. In the demo the host is
brought up with `kind`/`k3d` (see `make bootstrap`); these manifests show how the
fleet is provisioned in production, declaratively.

- `prod/eu-west-host.yaml` — RKE2 host in eu-west (CAPI: Cluster + 3-node HA
  RKE2ControlPlane + MachineDeployment). Docker provider for local reproducibility.
- `bootstrap-crs.yaml` — CAPI ClusterResourceSet that **seeds ArgoCD + platform-root**
  onto each new cluster (one-shot). This is how GitOps gets onto a created cluster
  **without a central ArgoCD** — each cluster then self-manages from Git (ADR-13).

**Why RKE2:** CIS + FIPS hardening, relevant for sovereignty/regulated (ADR-05).
**Why CAPI:** the answer to blast radius (ADR-11) is *multiple* host clusters per
environment/region; managing that fleet by hand doesn't scale.

**SPOF and DR:** the management cluster where CAPI lives is a *management* SPOF (not
a runtime one). Mitigation: internal HA + `clusterctl move` (pivot) on regional disaster.
