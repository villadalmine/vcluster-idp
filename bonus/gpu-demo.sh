#!/usr/bin/env bash
set -uo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
C='\033[1;36m'; B='\033[1;34m'; G='\033[1;32m'; Y='\033[1;33m'; Z='\033[0m'
hr(){ printf "\n${C}━━ %s ━━${Z}\n\n" "$1"; }
note(){ printf "${B}%s${Z}\n" "$*"; }
ok(){ printf "${G}%s${Z}\n" "$*"; }
warn(){ printf "${Y}%s${Z}\n" "$*"; }

OLLAMA=$(kubectl -n gpu-test get pod -l app=ollama -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
TPOD=$(kubectl -n vcluster-tenant-a-dev get pods 2>/dev/null | grep tenant-gpu-smi | awk '{print $1}' | head -1)

hr "BONUS — Multi-tenant GPU on bare metal: HAMi vGPU (slicing, metrics, governance, multi-GPU)"
note "2 physical GPUs on srv-t7910 -> HAMi slices them in software (no MIG, no passthrough) with HARD"
note "VRAM + compute limits -> each tenant/workload gets isolated, capped, measured slices."
sleep 2

hr "1/7  The bare-metal GPUs (la GPU del fierro)"
echo "  node srv-t7910 advertises nvidia.com/gpu = $(kubectl get node srv-t7910 -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null)   (Tesla P4 7680MiB + Quadro M4000 8192MiB)"
sleep 3

hr "2/7  GOVERNANCE — the GPU budget granted per tenant / namespace"
note "What each tenant is ALLOWED (hard caps in the pod spec) — the showback / quota view:"
kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json,sys,collections
d=json.load(sys.stdin); agg=collections.defaultdict(lambda:[0,0,0])
for p in d['items']:
  ns=p['metadata']['namespace']
  for c in p['spec'].get('containers',[]):
    l=c.get('resources',{}).get('limits',{})
    if 'nvidia.com/gpu' in l:
      g=int(l.get('nvidia.com/gpu',0))
      agg[ns][0]+=g
      agg[ns][1]+=int(str(l.get('nvidia.com/gpumem','0')).replace('k','000'))*max(g,1)
      agg[ns][2]+=int(l.get('nvidia.com/gpucores',0))
print('  %-26s %5s %11s %7s' % ('NAMESPACE / TENANT','vGPU','VRAM(MiB)','CORES'))
for ns,(g,m,co) in sorted(agg.items()): print('  %-26s %5d %11d %6d%%' % (ns,g,m,co))
"
sleep 3

hr "3/7  A TENANT's HARD-capped slice (inside its own vCluster)"
note "nvidia-smi from a pod INSIDE vcluster-tenant-a-dev — it sees ONLY its slice of an 8GB card:"
kubectl -n vcluster-tenant-a-dev logs "$TPOD" 2>/dev/null | grep -iE 'Quadro|Tesla|MiB /' | head -3 | sed 's/^/  /'
ok "  -> capped to 1500MiB. The tenant cannot see or exceed its slice (hard isolation)."
sleep 3

hr "4/7  METRICS — HAMi vGPU telemetry per tenant (the dashboard, in text)"
kubectl -n kube-system port-forward svc/hami-device-plugin-monitor 31992:31992 >/tmp/pfm.log 2>&1 &
PF=$!; sleep 3
curl -s http://localhost:31992/metrics 2>/dev/null > /tmp/hami-metrics.txt
kill $PF 2>/dev/null; wait $PF 2>/dev/null
python3 - <<'PY'
import re,collections
t=open('/tmp/hami-metrics.txt').read()
def agg(metric):
    o=collections.defaultdict(float)
    for m in re.finditer(metric+r'\{([^}]*)\}\s+([0-9.eE+]+)', t):
        l=dict(re.findall(r'(\w+)="([^"]*)"', m.group(1))); o[l.get('namespace')]+=float(m.group(2))
    return o
lim=agg('hami_vgpu_memory_limit_bytes'); used=agg('hami_vgpu_memory_used_bytes')
print('  %-26s %12s %12s' % ('TENANT (namespace)','LIMIT(MiB)','USED(MiB)'))
for ns in sorted(lim): print('  %-26s %12d %12d' % (ns, lim[ns]/1048576, used.get(ns,0)/1048576))
print('  physical cards:')
for m in re.finditer(r'hami_host_gpu_memory_used_bytes\{([^}]*)\}\s+([0-9.eE+]+)', t):
    l=dict(re.findall(r'(\w+)="([^"]*)"', m.group(1))); print('   ', l.get('device_type'),'used =', '%.0f MiB' % (float(m.group(2))/1048576))
PY
note "  (source: hami_vgpu_memory_limit/used_bytes -> Prometheus + Grafana on the cluster)"
sleep 3

hr "5/7  GOVERNANCE enforcement — an over-budget request is rejected (Pending)"
note "A tenant asks for 8000MiB (more than any card can give). The scheduler refuses to overcommit:"
kubectl -n gpu-test get pod gpu-greedy -o wide 2>/dev/null | sed 's/^/  /'
warn "  reason: $(kubectl -n gpu-test get event --field-selector involvedObject.name=gpu-greedy 2>/dev/null | grep -oiE 'CardInsufficientMemory[^ ]*' | tail -1)"
ok "  -> it stays Pending; it cannot starve the tenants that already hold their slices."
sleep 3

hr "6/7  MULTI-GPU — one pod (Ollama) spanning BOTH physical cards"
note "Ollama got 2 vGPU (one slice per card, capped 3000MiB each) and spread the model across both:"
kubectl -n gpu-test exec "$OLLAMA" -- nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv 2>/dev/null | sed 's/^/  /'
kubectl -n gpu-test exec "$OLLAMA" -- ollama ps 2>/dev/null | sed 's/^/  /'
ok "  -> the model uses VRAM on BOTH the M4000 and the P4, each within its HAMi cap."
sleep 3

hr "7/7  Ask the LLM (inference live across the sliced GPUs)"
note 'Prompt: "Write a short, funny love story between two Kubernetes pods."'
echo
kubectl -n gpu-test port-forward deploy/ollama 11434:11434 >/tmp/pf.log 2>&1 &
PF=$!; sleep 3
curl -s http://localhost:11434/api/generate -d '{"model":"llama3.2:1b","prompt":"Write a short, funny love story (max 4 sentences) between two Kubernetes pods. Use puns about pods, nodes, scheduling, restarts and labels. Be witty.","stream":false,"options":{"seed":42,"temperature":0.8}}' 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null | fold -s -w 92 | sed 's/^/  /'
kill $PF 2>/dev/null; wait $PF 2>/dev/null
echo
hr "Real cards -> HAMi-sliced -> hard-capped, measured, quota-enforced, multi-GPU -> live LLM."
sleep 1
