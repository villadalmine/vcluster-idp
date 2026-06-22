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

## Video transcripts (text)

<details>
<summary><b>Cinematic — 3 tenants &middot; 2 GPUs &middot; 3 stories</b> (click to expand)</summary>

```text
━━ 3 tenants · 2 bare-metal GPUs · 3 local LLMs — HAMi vGPU + vCluster + Ollama ━━

tenant-a / -b / -c each run Ollama INSIDE their own vCluster, each with 2 vGPU (a slice of
EACH physical card). HAMi hard-caps + isolates them; the three share the same 2 bare-metal GPUs.
Stack: bare-metal GPUs -> HAMi (software vGPU, no MIG/passthrough) -> vCluster -> Ollama (llama3.2).

━━ Governance — the 3 tenants sharing 2 physical cards (Tesla P4 + Quadro M4000) ━━

GPU budget granted per tenant (2 vGPU each = one slice per card, hard-capped):
  TENANT (vCluster)           vGPU   VRAM(MiB)   CORES
  tenant-a-dev                   2        4000     40%
  tenant-b-dev                   2        4000     40%
  tenant-c-dev                   2        4000     40%

━━ Tenant-a  ·  love story ━━

Its Ollama pod spans BOTH physical cards (the model is loaded on each slice):
    Quadro M4000, 919 MiB, 2000 MiB
    Tesla P4, 975 MiB, 2000 MiB
  > tenant-a asks its local LLM for a love story about Kubernetes...

  In the bustling cloud of Kubernetes, Podina and Nodey found themselves stuck in a
  scheduling loop - they kept trying to start each other, only to get restarted by their
  human overlords. As they danced around the cluster, their labels became increasingly
  tangled in a web of code and desire. One day, Podina decided to "scale" her feelings, but
  Nodey was having none of it - he shut down on her advances, leaving her to wonder if she
  was just a label that would "stick" to someone else's schedule. Eventually, they both
  learned to "reboot" their love lives and found happiness in the Kubernetes ecosystem.

━━ Tenant-b  ·  heist ━━

Its Ollama pod spans BOTH physical cards (the model is loaded on each slice):
    Quadro M4000, 919 MiB, 2000 MiB
    Tesla P4, 975 MiB, 2000 MiB
  > tenant-b asks its local LLM for a heist about Kubernetes...

  In a brazen heist, a pod and its sidecar snuck into the etcd vault like a swarm of bees
  on a mission to uncover a secret that would make Kubernetes' own self-healing
  capabilities jealous. The pair dodged security cameras with ease, their containerized
  agility allowing them to evade detection and reach the coveted payload. As they cracked
  the code to the Secret, one pod exclaimed, "We've got Kubernetes-iously secured!" But
  little did they know, their mischief was about to get etched into the vault's logs
  forever, leaving a digital footprint that would make even the most hardened security
  expert scratch their head in confusion.

━━ Tenant-c  ·  noir mystery ━━

Its Ollama pod spans BOTH physical cards (the model is loaded on each slice):
    Quadro M4000, 919 MiB, 2000 MiB
    Tesla P4, 975 MiB, 2000 MiB
  > tenant-c asks its local LLM for a noir mystery about Kubernetes...

  In the dimly lit alleys of New Haven, Detective Jack "The Docker" Murphy was on a mission
  to track down the culprit behind the outbreak of OOMs (Over-Outer-Memory) in the city's
  critical infrastructure. As he navigated the crowded streets in his trusty Pod, he
  muttered to himself, "This is a bug in the system - someone needs to shut it down." With
  his vast knowledge of Kubernetes and a keen eye for patterns, Murphy had been tracking a
  lead on a mysterious pod operator who seemed to be running amok, leaving a trail of
  failed applications and corrupted data in their wake. As he closed in on his suspect, he
  quipped, "It's time to containerize the evidence - this guy's going down."

━━ 3 isolated tenants · 2 bare-metal GPUs · 3 local LLMs · all hard-capped & sliced by HAMi ━━
```

</details>

<details>
<summary><b>GPU deep-dive — slicing &middot; governance &middot; metrics &middot; over-budget Pending &middot; multi-GPU &middot; LLM</b> (click to expand)</summary>

```text
━━ BONUS — Multi-tenant GPU on bare metal: HAMi vGPU (slicing, metrics, governance, multi-GPU) ━━

2 physical GPUs on srv-t7910 -> HAMi slices them in software (no MIG, no passthrough) with HARD
VRAM + compute limits -> each tenant/workload gets isolated, capped, measured slices.

━━ 1/7  The bare-metal GPUs (la GPU del fierro) ━━

  node srv-t7910 advertises nvidia.com/gpu = 20   (Tesla P4 7680MiB + Quadro M4000 8192MiB)

━━ 2/7  GOVERNANCE — the GPU budget granted per tenant / namespace ━━

What each tenant is ALLOWED (hard caps in the pod spec) — the showback / quota view:
  NAMESPACE / TENANT          vGPU   VRAM(MiB)   CORES
  ai                             1        6000     80%
  gpu-test                       3       14000     80%
  vcluster-tenant-a-dev          1        1500     15%

━━ 3/7  A TENANT's HARD-capped slice (inside its own vCluster) ━━

nvidia-smi from a pod INSIDE vcluster-tenant-a-dev — it sees ONLY its slice of an 8GB card:
  |   0  Quadro M4000                   Off |   00000000:03:00.0 Off |                  N/A |
  | 47%   44C    P8             22W /  120W |       0MiB /   1500MiB |      0%      Default |
  -> capped to 1500MiB. The tenant cannot see or exceed its slice (hard isolation).

━━ 4/7  METRICS — HAMi vGPU telemetry per tenant (the dashboard, in text) ━━

  TENANT (namespace)           LIMIT(MiB)    USED(MiB)
  gpu-test                           6000         2052
  vcluster-tenant-a-dev              1500            0
  physical cards:
    NVIDIA-Quadro M4000 used = 1304 MiB
    NVIDIA-Tesla P4 used = 1173 MiB
  (source: hami_vgpu_memory_limit/used_bytes -> Prometheus + Grafana on the cluster)

━━ 5/7  GOVERNANCE enforcement — an over-budget request is rejected (Pending) ━━

A tenant asks for 8000MiB (more than any card can give). The scheduler refuses to overcommit:
  NAME         READY   STATUS    RESTARTS   AGE     IP       NODE     NOMINATED NODE   READINESS GATES
  gpu-greedy   0/1     Pending   0          6m44s   <none>   <none>   <none>           <none>
  reason: CardInsufficientMemory(srv-t7910)
  -> it stays Pending; it cannot starve the tenants that already hold their slices.

━━ 6/7  MULTI-GPU — one pod (Ollama) spanning BOTH physical cards ━━

Ollama got 2 vGPU (one slice per card, capped 3000MiB each) and spread the model across both:
  index, name, memory.used [MiB], memory.total [MiB]
  0, Quadro M4000, 963 MiB, 3000 MiB
  1, Tesla P4, 1090 MiB, 3000 MiB
  NAME           ID              SIZE      PROCESSOR    CONTEXT    UNTIL
  llama3.2:1b    baf6a787fdff    2.1 GB    100% GPU     4096       3 minutes from now
  -> the model uses VRAM on BOTH the M4000 and the P4, each within its HAMi cap.

━━ 7/7  Ask the LLM (inference live across the sliced GPUs) ━━

Prompt: "Write a short, funny love story between two Kubernetes pods."

  In the bustling Kubernetes ecosystem, "Pod" Morgan and "Node" Nora locked eyes at the Node
  Manager's conference, where they quickly realized their label was meant to be: "Scheduling
  Sweethearts". As they danced around each other in the pods' designated area, they couldn't
  help but restart their love affair with regular meetings and scheduled dates. But little
  did they know, a rogue Container (aka "Docker") had been trying to sabotage their romance
  by deploying its own pod-like nemesis – a malicious image labeled as "Malicious". Just when
  all hope seemed lost, Morgan and Nora's pods were scheduled for a "deployment" of love, and
  they refused to be restarted.

━━ Real cards -> HAMi-sliced -> hard-capped, measured, quota-enforced, multi-GPU -> live LLM. ━━

0
```

</details>

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
