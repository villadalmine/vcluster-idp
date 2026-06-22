#!/usr/bin/env bash
set -uo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
C='\033[1;36m'; B='\033[1;34m'; G='\033[1;32m'; Z='\033[0m'
hr(){ printf "\n${C}━━ %s ━━${Z}\n\n" "$1"; }
note(){ printf "${B}%s${Z}\n" "$*"; }
ok(){ printf "${G}%s${Z}\n" "$*"; }

OLLAMA=$(kubectl -n gpu-test get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
TPOD=$(kubectl -n vcluster-tenant-a-dev get pods 2>/dev/null | grep tenant-gpu-smi | awk '{print $1}' | head -1)

hr "BONUS — Multi-tenant GPU on bare metal (HAMi vGPU: no MIG hardware, no passthrough)"
note "2 physical GPUs on srv-t7910 -> HAMi slices them with HARD VRAM + core limits ->"
note "a tenant (inside its vCluster) and an LLM workload (Ollama) each get an isolated, capped slice."
sleep 2

hr "1/4  The bare-metal GPUs (la GPU del fierro)"
echo "  node srv-t7910 advertises nvidia.com/gpu = $(kubectl get node srv-t7910 -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null)   (Tesla P4 7680MiB + Quadro M4000 8192MiB)"
sleep 3

hr "2/4  A TENANT gets a HARD-capped slice (inside its own vCluster)"
note "Pod running INSIDE vcluster-tenant-a-dev. Its nvidia-smi sees ONLY its slice of an 8GB card:"
kubectl -n vcluster-tenant-a-dev logs "$TPOD" 2>/dev/null | grep -iE 'Quadro|Tesla|MiB /' | head -3 | sed 's/^/  /'
ok "  -> HAMi caps the tenant to 1500MiB. It cannot see or exceed its slice (hard isolation)."
sleep 3

hr "3/4  An LLM workload (Ollama) on its own slice + GPU"
kubectl -n gpu-test exec "$OLLAMA" -- nvidia-smi 2>/dev/null | grep -iE 'Tesla|Quadro|MiB /' | head -3 | sed 's/^/  /'
note "Model loaded (persisted on a PVC, served on the GPU):"
kubectl -n gpu-test exec "$OLLAMA" -- ollama list 2>/dev/null | sed 's/^/  /'
sleep 2

hr "4/4  Ask the LLM (inference live on the sliced GPU)"
note 'Prompt: "Write a short, funny love story between two Kubernetes pods."'
echo
kubectl -n gpu-test port-forward deploy/ollama 11434:11434 >/tmp/pf.log 2>&1 &
PF=$!; sleep 3
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Write a short, funny love story (max 4 sentences) between two Kubernetes pods. Use puns about pods, nodes, scheduling, restarts and labels. Be witty.","stream":false,"options":{"seed":42,"temperature":0.8}}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null | fold -s -w 92 | sed 's/^/  /'
kill $PF 2>/dev/null; wait $PF 2>/dev/null
echo
hr "Real cards -> HAMi-sliced -> hard-capped per tenant -> live LLM inference on the slice."
sleep 1
