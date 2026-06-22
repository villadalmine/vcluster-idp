# Bonus — Multi-tenant GPU on bare metal (HAMi vGPU)

> **Not an IDP requirement.** A differentiation extra: the homelab Root cluster has 2 physical GPUs
> (Tesla P4, Quadro M4000) and runs **[HAMi](https://github.com/Project-HAMi/HAMi)** (CNCF Sandbox).
> HAMi slices a GPU in **software** (no MIG hardware, no GPU passthrough) with **hard limits** on VRAM
> (`nvidia.com/gpumem`, MiB) and compute (`nvidia.com/gpucores`, %). A pod just asks for `nvidia.com/gpu`
> plus those caps and the HAMi scheduler/webhook place it on the GPU node and enforce the slice.

## What this shows
- **The bare-metal GPUs** are exposed as schedulable vGPU slices (`nvidia.com/gpu`) on the node.
- **A tenant** (a pod **inside its vCluster**) gets a slice **hard-capped to 1500 MiB** — `nvidia-smi`
  inside the pod sees only its slice of the 8 GB card. The tenant cannot see or exceed it.
- **A real LLM workload** (Ollama serving `llama3.2:1b`) runs on its own slice, model persisted on a PVC,
  and answers a prompt live on the GPU.

## Scope (honest)
Only the **centralized vClusters on the Root** can use the GPU — they share the Root's nodes, including the
GPU node. The **regional/recursive host clusters are KubeVirt VMs**, so they'd need **GPU passthrough** to
the VM (out of scope here). The metrics path (HAMi exporter + kube-prometheus-stack Grafana/Prometheus) is
also available on the Root.

## Files
- [`ollama-gpu.yaml`](./ollama-gpu.yaml) — Ollama Deployment + PVC on a HAMi vGPU slice (host).
- [`tenant-gpu-pod.yaml`](./tenant-gpu-pod.yaml) — a tenant pod requesting a capped slice (apply inside a vCluster).
- [`gpu-demo.sh`](./gpu-demo.sh) — the narrated read-only demo (the recording).
- [`demo-gpu.cast`](./demo-gpu.cast) — the asciinema recording.

## Run
```bash
# 1) LLM on a GPU slice (host)
kubectl apply -f bonus/ollama-gpu.yaml
kubectl -n gpu-test exec deploy/ollama -- ollama pull llama3.2:1b

# 2) a tenant pod with a capped slice, INSIDE its vCluster
vcluster connect vcluster-tenant-a-dev -n vcluster-tenant-a-dev -- kubectl apply -f bonus/tenant-gpu-pod.yaml

# 3) the narrated demo
KUBECONFIG=~/.kube/config bash bonus/gpu-demo.sh
```
