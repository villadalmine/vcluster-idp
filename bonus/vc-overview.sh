#!/usr/bin/env bash
set -uo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
C='\033[1;36m'; B='\033[1;34m'; G='\033[1;32m'; Z='\033[0m'
hr(){ printf "\n${C}━━ %s ━━${Z}\n\n" "$1"; }
note(){ printf "${B}%s${Z}\n" "$*"; }

hr "vCluster on an existing cluster — the concept (homelab lab)"
note "Each tenant gets a vCluster: its OWN API server + etcd, running as pods ON the existing"
note "k3s cluster. Stronger isolation than a plain namespace, on shared nodes, with low overhead."
sleep 2

hr "1/5  The real cluster (k3s) that hosts everything"
kubectl get nodes -o wide 2>/dev/null | awk 'NR==1 || /control-plane/ {print $1, $2, $3, $5}' | head -4 | sed 's/^/  /'
note "  ... (a real multi-node k3s cluster — the substrate)"
sleep 2

hr "2/5  The vClusters running ON it (one per tenant)"
vcluster list 2>/dev/null | sed 's/^/  /' | head -12
sleep 3

hr "3/5  Inside a tenant's vCluster — its OWN control plane (isolated)"
note "Connecting to tenant-a's vCluster — it sees only ITS namespaces, not the host's:"
timeout 40 vcluster connect vcluster-tenant-a-dev -n vcluster-tenant-a-dev -- kubectl get ns 2>/dev/null | grep -viE 'kube-|external-secrets|default|^NAME' | sed 's/^/  /' | head
note "  ...and its workload (Postgres + API + Web) runs inside it:"
timeout 40 vcluster connect vcluster-tenant-a-dev -n vcluster-tenant-a-dev -- kubectl get pods -n tenant-a 2>/dev/null | grep -iE 'NAME|postgres|customer' | sed 's/^/  /'
sleep 3

hr "4/5  How they're created — Helm chart + ArgoCD ApplicationSet (GitOps)"
note "A git-generator ApplicationSet reads each tenant file and materializes, per tenant:"
kubectl -n argocd get applicationset 2>/dev/null | grep -E 'NAME|tenant' | sed 's/^/  /'
note "  -> one vCluster (vcluster Helm chart) + the workload chart (charts/tenant) INSIDE it."
note "The vCluster values we chose (shared-nodes): sync nodes/GatewayAPI from host, ingress to host:"
grep -vE '^\s*#|^\s*$' vcluster/shared-nodes.yaml 2>/dev/null | head -12 | sed 's/^/    /'
sleep 3

hr "5/5  Isolation — default-deny CiliumNetworkPolicy per tenant"
kubectl get ciliumnetworkpolicy -A 2>/dev/null | grep -E 'NAME|tenant' | head -6 | sed 's/^/  /'
sleep 2
hr "vCluster = per-tenant control plane on shared nodes. Created by Helm + ArgoCD, isolated by Cilium."
sleep 1
