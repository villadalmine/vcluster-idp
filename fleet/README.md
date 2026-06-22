# fleet/ — homelab fleet stack (GitOps, declarative)

This is the **GitOps** form of the KubeVirt + CAPK + Crossplane v2 fleet path. Ansible
(infra-ai) only **bootstraps ArgoCD + `platform-root`**; from there **ArgoCD reconciles
everything here** — matching the diagrams that show ArgoCD reading `platform/addons` and
the host-cluster requests. (The imperative Ansible variant lives in
`infra-ai/infra/fleet-demo/`; pick one — same result.)

## Why GitOps and not `clusterctl init`
`clusterctl init` is a CLI that pushes YAML once (imperative). Here the **Cluster API
Operator** installs CAPI declaratively: ArgoCD applies the operator + Provider CRs, so
CAPI providers are versioned in Git and self-heal. **No pivot** — your cluster already
exists, so it becomes the management cluster in place.

## Layout & sync order (app-of-apps under platform/addons, recursed by platform-root)
```
platform/addons/cluster-api-operator.yaml  (Helm)            wave 1  ┐ operators
platform/addons/crossplane.yaml            (Helm, v2)        wave 1  │
platform/addons/kubevirt.yaml  → fleet/kubevirt (kustomize)  wave 1  ┘
platform/addons/fleet-config.yaml → fleet/config            wave 3   ← providers + XRD/Composition/Function/RBAC
platform/addons/fleet-hostclusters.yaml → clusters/homelab  wave 5   ← the HostCluster requests (XRs)
```
- `fleet/kubevirt/` — upstream KubeVirt operator (kustomize remote) + CR pinning VMs to srv-t7910.
- `fleet/config/` — `capi-providers.yaml` (CoreProvider/Bootstrap/ControlPlane/CAPK CRs),
  `crossplane-function-rbac.yaml`, `crossplane-xrd.yaml`, `crossplane-composition.yaml`.
- `clusters/homelab/host-a.yaml` — the namespaced **HostCluster XR** (v2, no claim) = the request.

## Flow
```
HostCluster XR (clusters/homelab) ─Composition(fleet/config)→ CAPI objects ─CAPK→ VMs on srv-t7910 → workload k8s
```

## Versions (cluster on k8s 1.35.5 — verified live)
- KubeVirt: **v1.8.x is correct for k8s 1.35** (v1.8.0 pinned in `fleet/kubevirt/kustomization.yaml`; v1.8.4 is the latest patch, Jun 2026). **No v1.9 needed** (still beta). Only bump if you later upgrade Kubernetes.
- CAPK `v0.11.x` · Crossplane `2.3` · workload k8s `v1.31.0` (container-disk tag must exist).

## After sync
```
kubectl get coreprovider,infrastructureprovider -A       # CAPI providers Ready
kubectl -n fleet get hostcluster,cluster,machines,vmi    # request → CAPI → VMs
clusterctl get kubeconfig host-a -n fleet > /tmp/host-a.kubeconfig
KUBECONFIG=/tmp/host-a.kubeconfig kubectl apply -f <a CNI>   # workload NotReady until CNI
```
Upgrade flow (B): `infra-ai/infra/fleet-demo/upgrade-example.md`.
v1↔v2 Crossplane: `CAPI-CROSSPLANE-EJEMPLOS.md §17`.
