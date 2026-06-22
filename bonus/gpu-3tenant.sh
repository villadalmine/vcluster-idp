#!/usr/bin/env bash
set -uo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
C='\033[1;36m'; B='\033[1;34m'; G='\033[1;32m'; M='\033[1;35m'; Z='\033[0m'
hr(){ printf "\n${C}━━ %s ━━${Z}\n\n" "$1"; }
note(){ printf "${B}%s${Z}\n" "$*"; }
ok(){ printf "${G}%s${Z}\n" "$*"; }
pod(){ kubectl -n vcluster-tenant-$1-dev get pods 2>/dev/null | grep tenant-llm | grep Running | awk '{print $1}' | head -1; }

hr "3 tenants · 2 bare-metal GPUs · 3 local LLMs — HAMi vGPU + vCluster + Ollama"
note "tenant-a / -b / -c each run Ollama INSIDE their own vCluster, each with 2 vGPU (a slice of"
note "EACH physical card). HAMi hard-caps + isolates them; the three share the same 2 bare-metal GPUs."
note "Stack: bare-metal GPUs -> HAMi (software vGPU, no MIG/passthrough) -> vCluster -> Ollama (llama3.2)."
sleep 2

hr "Governance — the 3 tenants sharing 2 physical cards (Tesla P4 + Quadro M4000)"
note "GPU budget granted per tenant (2 vGPU each = one slice per card, hard-capped):"
kubectl get pods -A -o json 2>/dev/null | python3 -c "
import json,sys,collections
d=json.load(sys.stdin); agg=collections.defaultdict(lambda:[0,0,0])
for p in d['items']:
  ns=p['metadata']['namespace']
  if not ns.startswith('vcluster-tenant-'): continue
  for c in p['spec'].get('containers',[]):
    l=c.get('resources',{}).get('limits',{})
    if 'nvidia.com/gpu' in l:
      g=int(l['nvidia.com/gpu']); agg[ns][0]+=g
      agg[ns][1]+=int(str(l.get('nvidia.com/gpumem','0')).replace('k','000'))*g
      agg[ns][2]+=int(l.get('nvidia.com/gpucores',0))*g
print('  %-26s %5s %11s %7s' % ('TENANT (vCluster)','vGPU','VRAM(MiB)','CORES'))
for ns,(g,m,co) in sorted(agg.items()): print('  %-26s %5d %11d %6d%%' % (ns.replace('vcluster-',''),g,m,co))
"
sleep 3

demo_tenant(){
  local t=$1 genre=$2 prompt=$3 port=$4
  hr "Tenant-$t  ·  $genre"
  local P; P=$(pod "$t")
  note "Its Ollama pod spans BOTH physical cards (the model is loaded on each slice):"
  kubectl -n vcluster-tenant-$t-dev exec "$P" -- nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader 2>/dev/null | sed 's/^/    /'
  printf "${M}  > %s asks its local LLM for a %s about Kubernetes...${Z}\n\n" "tenant-$t" "$genre"
  kubectl -n vcluster-tenant-$t-dev port-forward pod/"$P" "$port":11434 >/tmp/pf-$t.log 2>&1 &
  local pf=$!; sleep 3
  curl -s --max-time 120 http://localhost:"$port"/api/generate -d "{\"model\":\"llama3.2:1b\",\"prompt\":\"$prompt\",\"stream\":false,\"keep_alive\":\"30m\",\"options\":{\"seed\":7,\"temperature\":0.85}}" 2>/dev/null | python3 -c "import json,sys;print(json.load(sys.stdin).get('response','').strip())" 2>/dev/null | fold -s -w 90 | sed 's/^/  /'
  kill $pf 2>/dev/null; wait $pf 2>/dev/null
  sleep 2
}

demo_tenant a "love story"      "Write a short, witty LOVE story (max 4 sentences) between two Kubernetes pods. Use puns about pods, nodes, scheduling, labels and restarts." 11434
demo_tenant b "heist"           "Write a short, witty HEIST story (max 4 sentences) where a Pod and its sidecar break into the etcd vault to steal a Secret. Use puns about Kubernetes." 11435
demo_tenant c "noir mystery"    "Write a short, witty NOIR detective story (max 4 sentences) where a Pod detective hunts whoever keeps OOM-killing the cluster. Use puns about Kubernetes." 11436

hr "3 isolated tenants · 2 bare-metal GPUs · 3 local LLMs · all hard-capped & sliced by HAMi"
sleep 1
