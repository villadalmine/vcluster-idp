# Bonus — Multi-tenant GPU on bare metal (HAMi vGPU)

> **Not an IDP requirement.** A differentiation extra: the homelab Root cluster has 2 physical GPUs
> (Tesla P4, Quadro M4000) and runs **[HAMi](https://github.com/Project-HAMi/HAMi)** (CNCF Sandbox).
> HAMi slices a GPU in **software** (no MIG hardware, no GPU passthrough) with **hard limits** on VRAM
> (`nvidia.com/gpumem`, MiB) and compute (`nvidia.com/gpucores`, %).

## What the demo shows (7 segments)
1. **The bare-metal GPUs** exposed as schedulable vGPU slices on the node.
2. **Governance / showback** — the GPU budget granted per tenant / namespace.
3. **A tenant** (a pod inside its vCluster) gets a slice **hard-capped to 1500 MiB** — `nvidia-smi` inside
   sees only its slice of an 8 GB card.
4. **Metrics** — HAMi per-tenant vGPU telemetry (`hami_vgpu_memory_limit/used_bytes`) → Prometheus/Grafana.
5. **Governance enforcement** — an over-budget request (8000 MiB) stays **Pending**
   (`CardInsufficientMemory`); it cannot starve the tenants that already hold slices.
6. **Multi-GPU** — one pod (Ollama, `OLLAMA_SCHED_SPREAD=1`, 2 vGPU) spreads a model across **both**
   physical cards; VRAM is used on the M4000 **and** the P4, each within its cap.
7. **Live LLM** — Ollama answers a prompt on the sliced GPUs.

## Scope (honest)
Only the **centralized vClusters on the Root** can use the GPU — they share the Root's nodes incl. the GPU
node. The **regional/recursive host clusters are KubeVirt VMs**, so they'd need **GPU passthrough** (out of
scope). The metrics path (HAMi exporter + kube-prometheus-stack) is on the Root.

## Files
- [`ollama-gpu.yaml`](./ollama-gpu.yaml) — Ollama Deployment + PVC across 2 HAMi vGPU slices.
- [`tenant-gpu-pod.yaml`](./tenant-gpu-pod.yaml) — a tenant pod with a capped slice (apply inside a vCluster).
- [`gpu-greedy-pending.yaml`](./gpu-greedy-pending.yaml) — an over-budget pod that stays Pending (guardrail).
- [`gpu-demo.sh`](./gpu-demo.sh) — the narrated read-only demo (the recording).
- [`demo-gpu.cast`](./demo-gpu.cast) — the asciinema recording.

## Run
```bash
kubectl apply -f bonus/ollama-gpu.yaml
kubectl -n gpu-test exec deploy/ollama -- ollama pull llama3.2:1b
vcluster connect vcluster-tenant-a-dev -n vcluster-tenant-a-dev -- kubectl apply -f bonus/tenant-gpu-pod.yaml
kubectl apply -f bonus/gpu-greedy-pending.yaml      # the Pending guardrail demo
bash bonus/gpu-demo.sh                               # the narrated walkthrough
```

---

## Scenario 2 — 3 tenants, 2 GPUs, 3 stories (the cinematic)

![Architecture](./gpu-architecture.png)

Three tenants (`tenant-a/b/c`), each an **Ollama LLM inside its own vCluster** with **2 vGPU (one slice of
EACH physical card)**. HAMi hard-caps and isolates them, so the three share the same 2 bare-metal GPUs at
once. Each pod loads `llama3.2:1b` **across both cards** (`OLLAMA_SCHED_SPREAD=1`) and tells a different
Kubernetes story — a love story, a heist, and a noir mystery. It demonstrates **local LLMs + GPU
multi-tenancy + per-tenant isolation** end to end.

**Files:** [`tenant-llm-2gpu.yaml`](./tenant-llm-2gpu.yaml) (the per-tenant 2-vGPU Ollama),
[`gpu-3tenant.sh`](./gpu-3tenant.sh) (the cinematic), [`demo-3tenant-gpu.cast`](./demo-3tenant-gpu.cast)
(recording), [`gpu-architecture.dot`](./gpu-architecture.dot) / [`gpu-architecture.png`](./gpu-architecture.png)
(the diagram above).
