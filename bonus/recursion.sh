#!/usr/bin/env bash
set -uo pipefail
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
C='\033[1;36m'; B='\033[1;34m'; G='\033[1;32m'; Z='\033[0m'
hr(){ printf "\n${C}━━ %s ━━${Z}\n\n" "$1"; }
note(){ printf "${B}%s${Z}\n" "$*"; }
ok(){ printf "${G}%s${Z}\n" "$*"; }
clean(){ grep -viE 'jump|waiting|Starting|creating|Handling connection|Forwarding from|vCluster is up|^done|pod/.* (created|deleted)'; }

hr "Management-of-managements — a cluster that creates AND serves its own child (recursion)"
note "Root creates host-mgmt (a management cluster). host-mgmt then runs its OWN Cluster API + CAAPH and"
note "creates its OWN child (mgmt-child) — and hands it the SAME stack Root gives its regionals: ArgoCD +"
note "region-root + CNI. The child ends up decentralized, hosting its own tenant vCluster. No central SPOF."
note "The whole chain was validated CLEAN-ROOM (torn down in reverse, rebuilt 100% from Git)."
sleep 2

hr "1/4  Root creates host clusters via CAPI — one is role=management"
kubectl -n fleet get cluster -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,ROLE:.metadata.labels.platform\\.idp/role 2>/dev/null | sed 's/^/  /'
sleep 3

hr "2/4  host-mgmt runs its OWN CAPI + CAAPH, and created a CHILD cluster (mgmt-child)"
note "Querying host-mgmt (via jump pod) — it has its own CAPI Cluster object 'mgmt-child':"
./cli/fleet-test kc host-mgmt get cluster -A 2>/dev/null | clean | grep -iE 'NAME|mgmt-child' | sed 's/^/  /'
note "host-mgmt's ArgoCD delivers the child its CNI first (egg-and-chicken bootstrap):"
./cli/fleet-test kc host-mgmt get application -n argocd 2>/dev/null | clean | grep -iE 'NAME|child-cni' | sed 's/^/  /'
sleep 3

hr "3/4  mgmt-child got its OWN ArgoCD + region-root — one rung down, decentralized"
note "Querying mgmt-child (jump → into host-mgmt → into mgmt-child). Its own ArgoCD apps:"
./cli/fleet-test kc mgmt-child get application -n argocd 2>/dev/null | clean | grep -iE 'NAME|region-root|tenant-z' | sed 's/^/  /'
ok "  -> mgmt-child runs its OWN ArgoCD that provisions ITS region's tenants. No central control plane."
sleep 3

hr "4/4  The leaf — a tenant vCluster (tenant-z) running pg/api/web INSIDE mgmt-child"
./cli/fleet-test kc mgmt-child get pods -n vcluster-tenant-z-dev 2>/dev/null | clean | grep -iE 'NAME|postgres|customer|vcluster-tenant-z-dev-0' | sed 's/^/  /'
sleep 2

hr "Root → host-mgmt (mgmt) → mgmt-child (own ArgoCD) → vcluster-tenant-z. Recursion, 100% GitOps."
sleep 1
