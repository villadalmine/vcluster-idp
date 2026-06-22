# Post 01 — Multi-tenant GPU on bare metal (HAMi)

**Tags:** Kubernetes · GPU · HAMi · vCluster · Ollama · LLM · DevOps · PlatformEngineering · Homelab · CNCF

---

## ▶️ Assets — everything used to build this

### Videos (asciinema)
| Video | Link | Source script | Cast |
|---|---|---|---|
| **Cinematic — 3 tenants · 2 GPUs · 3 stories** | https://asciinema.org/a/eaoQKFsHhVDQ7qXc | [`bonus/gpu-3tenant.sh`](../bonus/gpu-3tenant.sh) | [`bonus/demo-3tenant-gpu.cast`](../bonus/demo-3tenant-gpu.cast) |
| **GPU deep-dive — slicing · governance · metrics · over-budget Pending · multi-GPU · LLM (7 segments)** | https://asciinema.org/a/n2EoxXTNhSslSXsg | [`bonus/gpu-demo.sh`](../bonus/gpu-demo.sh) | [`bonus/demo-gpu.cast`](../bonus/demo-gpu.cast) |

### Diagram (attach this to the post)
- ![arch](../bonus/gpu-architecture.png) — [`bonus/gpu-architecture.png`](../bonus/gpu-architecture.png) (source: [`bonus/gpu-architecture.dot`](../bonus/gpu-architecture.dot), Graphviz)

### Manifests
| File | What |
|---|---|
| [`bonus/tenant-llm-2gpu.yaml`](../bonus/tenant-llm-2gpu.yaml) | per-tenant Ollama with **2 vGPU** (one slice per card) — the cinematic |
| [`bonus/ollama-gpu.yaml`](../bonus/ollama-gpu.yaml) | Ollama Deployment + PVC spanning 2 vGPU (host) |
| [`bonus/tenant-gpu-pod.yaml`](../bonus/tenant-gpu-pod.yaml) | a tenant pod with a single capped slice |
| [`bonus/gpu-greedy-pending.yaml`](../bonus/gpu-greedy-pending.yaml) | over-budget request that stays **Pending** (governance guardrail) |

### Write-up
- [`bonus/README.md`](../bonus/README.md) — full explanation + how to run.

### Key commands (how it was built)
```bash
# per-tenant LLM with 2 vGPU, inside each tenant's vCluster
for t in a b c; do
  vcluster connect vcluster-tenant-$t-dev -n vcluster-tenant-$t-dev -- \
    kubectl apply -n tenant-$t -f bonus/tenant-llm-2gpu.yaml
  vcluster connect vcluster-tenant-$t-dev -n vcluster-tenant-$t-dev -- \
    kubectl -n tenant-$t exec deploy/tenant-llm -- ollama pull llama3.2:1b
done
# the cinematic (3 tenants, 3 stories)
bash bonus/gpu-3tenant.sh
# the diagram
dot -Tpng -Gdpi=140 bonus/gpu-architecture.dot -o bonus/gpu-architecture.png
```

---

## Version EN (copy-paste)

I gave 3 isolated tenants their own GPUs on a single bare-metal box — and made each one tell a Kubernetes story. 🎬

No MIG hardware. No GPU passthrough. Just software vGPU slicing.

Here's the setup, bottom to top:
🟩 2 physical GPUs (Tesla P4 + Quadro M4000) on one k3s node
🟪 HAMi (CNCF) slices them with HARD limits — VRAM (MiB) and compute (%) per pod
🟦 each tenant runs inside its own vCluster (isolated API server + etcd)
🤖 each tenant runs a local LLM (Ollama, llama3.2) — spanning BOTH cards at once

So three tenants share the same two GPUs simultaneously, each capped and isolated, and I asked each one's LLM for a different k8s story:
💘 tenant-a → a love story between two Pods
🦹 tenant-b → a heist on the etcd vault
🕵️ tenant-c → a noir mystery about who keeps OOM-killing the cluster

The governance is real: ask for more VRAM than a card has free and the scheduler keeps you Pending — you can't starve your neighbors. Per-tenant usage is exported as Prometheus metrics.

Why it's cool: GPUs are expensive and usually pinned 1:1 to a workload. With HAMi + vCluster you get multi-tenant GPU sharing with hard isolation — on commodity cards, in a homelab.

▶️ Watch the run (asciinema): https://asciinema.org/a/eaoQKFsHhVDQ7qXc
📊 Architecture in the image.

#Kubernetes #GPU #HAMi #vCluster #Ollama #LLM #DevOps #PlatformEngineering #Homelab #CNCF

---

## Version ES (copia-pega)

Le di a 3 tenants aislados su propia GPU en un solo servidor bare-metal — y cada uno me contó un cuento de Kubernetes. 🎬

Sin hardware MIG. Sin GPU passthrough. Solo slicing de vGPU por software.

El stack, de abajo hacia arriba:
🟩 2 GPUs físicas (Tesla P4 + Quadro M4000) en un nodo k3s
🟪 HAMi (CNCF) las sliceá con límites DUROS — VRAM (MiB) y cómputo (%) por pod
🟦 cada tenant corre en su propio vCluster (API server + etcd aislados)
🤖 cada tenant corre un LLM local (Ollama, llama3.2) — usando LAS DOS placas a la vez

Tres tenants comparten las mismas dos GPUs al mismo tiempo, cada uno capado y aislado, y le pedí a cada LLM un cuento distinto:
💘 tenant-a → una historia de amor entre dos Pods
🦹 tenant-b → un asalto a la bóveda de etcd
🕵️ tenant-c → un noir sobre quién OOM-killea el cluster

La governance es real: si pedís más VRAM de la que queda libre, el scheduler te deja en Pending — no podés robarle a tus vecinos. El uso por tenant sale como métricas Prometheus.

Por qué está bueno: las GPUs son caras y normalmente quedan 1:1 con un workload. Con HAMi + vCluster tenés GPU multi-tenant con aislamiento duro — en placas comunes, en un homelab.

▶️ Mirá la corrida (asciinema): https://asciinema.org/a/eaoQKFsHhVDQ7qXc
📊 La arquitectura en la imagen.

#Kubernetes #GPU #HAMi #vCluster #Ollama #LLM #DevOps #PlatformEngineering #Homelab #CNCF

---

## Notes (no publicar)
- Para el video en LinkedIn: subí el link de asciinema, o grabá la pantalla reproduciendo el cast
  (`asciinema play bonus/demo-3tenant-gpu.cast`) y subilo como video/gif.
- Las 3 historias salen con seed fijo (reproducibles). Cambiá el seed en `bonus/gpu-3tenant.sh` para otras.
- Variante más técnica del mismo tema: el video de 7 segmentos (governance/metrics/Pending/multi-GPU) sirve
  para un post más "deep-dive" o un carrusel.
