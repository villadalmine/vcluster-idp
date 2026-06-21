# vcluster-idp — a lightweight multi-tenant Internal Developer Platform

This repository implements a lightweight, declarative, and GitOps-driven **Internal Developer Platform (IDP)** designed to provision isolated development environments on-demand. 

Each tenant receives an isolated control plane (**vCluster**), a dedicated PostgreSQL database, two applications, auto-generated credentials, resource governance, network isolation, and external HTTPS access. The platform runs entirely through a GitOps facade (a CLI that commits to Git), allowing ArgoCD to reconcile and prune resources automatically.

---

## ── Repository Code Map ──

Use these links to navigate directly to the code implementing each component of the platform:

### 1. Tenant Workloads & Configurations
*   **GitOps Tenants Source of Truth**: [`tenants/dev/tenant-a.yaml`](./tenants/dev/tenant-a.yaml) (declares tenant specification, application versions, domain, and secret backend).
*   **Workload Helm Chart**: [`charts/tenant/`](./charts/tenant/) (the primary golden-path chart containing workloads and governance policies):
    *   [`apps-deployment.yaml`](./charts/tenant/templates/apps-deployment.yaml) — deploys `customer-api` (using `go-httpbin`) and `customer-web` (using `nginx`).
    *   [`postgres.yaml`](./charts/tenant/templates/postgres.yaml) — deploys the dedicated PostgreSQL StatefulSet and Service.
    *   [`secret.yaml`](./charts/tenant/templates/secret.yaml) — holds the auto-generated database credentials (Helm `lookup` or External Secrets templates).
    *   [`quota.yaml`](./charts/tenant/templates/quota.yaml) — defines the tenant's ResourceQuota limits.
    *   [`limitrange.yaml`](./charts/tenant/templates/limitrange.yaml) — defines the default container requests/limits.
    *   [`networkpolicy.yaml`](./charts/tenant/templates/networkpolicy.yaml) — enforces tenant network isolation using `CiliumNetworkPolicy`.

### 2. GitOps & Platform Generators
*   **ApplicationSets (ArgoCD)**: [`applicationsets/`](./applicationsets/) (controllers generating resources based on git configurations):
    *   [`hosts-appset.yaml`](./applicationsets/hosts-appset.yaml) — provisions the virtual cluster control plane on the host.
    *   [`tenants-appset.yaml`](./applicationsets/tenants-appset.yaml) — deploys the workload chart *inside* the virtual cluster.
    *   [`routes-appset.yaml`](./applicationsets/routes-appset.yaml) — provisions external routing (Gateway API) on the host.
    *   [`eso-appset.yaml`](./applicationsets/eso-appset.yaml) — optional controller to install External Secrets Operator per-tenant.
*   **ArgoCD App-of-Apps**: [`platform/root-app.yaml`](./platform/root-app.yaml) (bootstraps the platform add-ons on the host cluster).

### 3. CLI Automation & Scripts
*   **Platform Lifecycle Facade**: [`cli/platform`](./cli/platform) (implements `platform <tenant> <create|delete|status>`).
*   **ArgoCD vCluster Join**: [`cli/register-vcluster`](./cli/register-vcluster) (automatically registers the vCluster context in ArgoCD).
*   **E2E Validation Catalog**: [`cli/validate`](./cli/validate) (automates the 27 functional checks verifying every PDF requirement).
*   **Multicluster Query Tool**: [`cli/fleet-test`](./cli/fleet-test) (routes kubectl queries to nested VM host clusters).

### 4. Advanced Fleet & Infrastructure Definitions
*   **Cluster API (CAPI) VM Host Clusters**: [`clusters/homelab/`](./clusters/homelab/) (defines the CAPK/KubeVirt virtual machine host clusters: `host-euw1.yaml` regional, `host-mgmt.yaml` management).
*   **Crossplane v2 Composition & XRD**: [`fleet/config/`](./fleet/config/) (defines infrastructure composition layers):
    *   [`crossplane-xrd.yaml`](./fleet/config/crossplane-xrd.yaml) — defines the custom `HostCluster` resource API.
    *   [`crossplane-composition.yaml`](./fleet/config/crossplane-composition.yaml) — implements the composition pipeline matching XRD to CAPI virtual machines.
*   **KubeVirt & CDI Add-ons**: [`fleet/kubevirt/`](./fleet/kubevirt/) (deploys VM controllers and storage utilities on the bare-metal management node).
*   **Regional GitOps Base**: [`clusters/regions/`](./clusters/regions/) (parameterized regional root applications and tenants for multi-region configurations, like `eu-west1`).

---

## 1.5 Platform Components — what each piece is and how I apply it

The platform is built from well-known CNCF building blocks. This table is the at-a-glance map: **what
each component is, the exact role it plays here, where it lives in the repo, and which requirement /
Design Question (DQ) it answers.** Read top-to-bottom it is the full request flow: a CLI commit → ArgoCD
reconciles → Crossplane/CAPI build the host cluster → ArgoCD inside it builds the tenant.

| Component | What it is | How I apply it in this platform | Where in the repo | Answers |
|---|---|---|---|---|
| **`platform` CLI** | Tenant lifecycle facade | `platform <tenant> create\|delete\|status` does **not** deploy imperatively — it writes & commits `tenants/<env>/<tenant>.yaml` (the source of truth) and lets GitOps reconcile. Idempotent, drift-aware "for free". | [`cli/platform`](./cli/platform) | Req 2, 9, 10, 11; DQ7 |
| **ArgoCD** | GitOps engine | **Central** ArgoCD runs an app-of-apps (`platform-root`) + 4 ApplicationSets; **each regional cluster runs its OWN ArgoCD** (decentralized → no control-plane SPOF). | [`platform/`](./platform/) | DQ1, DQ3; Req 9–11 |
| **ApplicationSet** | Templated app generator | Git generators read each tenant file and materialize **one vCluster + one workload (+route +ESO) per tenant** automatically. | [`applicationsets/`](./applicationsets/) | DQ2, DQ3 |
| **Helm charts** | Packaging / golden path | `charts/tenant` = the whole tenant unit (namespace, ResourceQuota, LimitRange, CiliumNetworkPolicy, Secret, PostgreSQL, api, web). `charts/tenant-route` = Gateway + HTTPRoute + TLS. Onboarding an app = values, not platform changes. | [`charts/`](./charts/) | Req 3, 4, 5, 6; Infra-def |
| **vCluster** | Per-tenant control plane | Each tenant gets an isolated virtual API server + etcd (shared-nodes by default) → no CRD/RBAC collisions; the isolation knob (spectrum from shared → dedicated → separate clusters). | [`vcluster/`](./vcluster/) | Req 1, 3; DQ6 |
| **Crossplane v2** | Infra composition | A custom **`HostCluster` XR** (our own platform API) is composed into the CAPI object tree (each wrapped in a provider-kubernetes `Object` to hand ownership to CAPI). | [`fleet/config/`](./fleet/config/) | DQ1 |
| **Cluster API + CAPK** | Cluster lifecycle | Turn a one-file `HostCluster` request into a **real Kubernetes cluster whose nodes are KubeVirt VMs**; declarative create/upgrade/delete of the fleet. | [`clusters/homelab/`](./clusters/homelab/), [`fleet/`](./fleet/) | DQ1 |
| **KubeVirt + CDI** | Virtualization / storage | Runs guest-cluster nodes as VMs on the bare-metal node; CDI DataVolumes back the VM disks on Longhorn (HCI). | [`fleet/kubevirt/`](./fleet/kubevirt/) | DQ1 |
| **ClusterResourceSet** | Bootstrap injector | Seeds the **CNI** and the **`region-root`** app into each freshly-created cluster (egg-and-chicken bootstrap). | [`clusters/cni/`](./clusters/cni/), [`clusters/management/`](./clusters/management/) | DQ1, DQ3 |
| **CAAPH (HelmChartProxy)** | Addon delivery | Installs ArgoCD **into** every `role=management` cluster (too big for a CRS ConfigMap). | [`clusters/management/`](./clusters/management/) | DQ1, DQ3 |
| **Cilium** | CNI + Gateway + policy | Host dataplane, `GatewayClass` for north-south access, and **default-deny `CiliumNetworkPolicy`** for cross-tenant isolation. | [`charts/tenant/templates/networkpolicy.yaml`](./charts/tenant/templates/networkpolicy.yaml) | Req 7, 12; DQ5, DQ6 |
| **cert-manager** | TLS automation | Issues the Gateway TLS certificates (gateway-shim). | [`applicationsets/routes-appset.yaml`](./applicationsets/routes-appset.yaml) | Req 12; DQ5 |
| **External Secrets (ESO)** | Secrets (opt-in) | Per-tenant in-cluster secret generation without storing material in Git (default is Helm-generated). | [`applicationsets/eso-appset.yaml`](./applicationsets/eso-appset.yaml) | Req 8; DQ6 |
| **MachineHealthCheck** | Resilience | CAPI auto-remediates unhealthy worker Machines (declarative alternative to manual recovery). | [`clusters/homelab/machinehealthchecks.yaml`](./clusters/homelab/machinehealthchecks.yaml) | DQ1 (resilience) |

> **One sentence:** the **CLI** commits intent to Git; **ArgoCD** reconciles it; **Crossplane + CAPI +
> KubeVirt** build the host clusters; **CAAPH + ClusterResourceSet** give each cluster its own ArgoCD;
> that ArgoCD uses **ApplicationSets + Helm charts + vCluster** to give every tenant an isolated
> environment — all declarative, all GitOps. §3.1 shows the topology variants; §3.2 the failure modes.

---

## 2. Quick Start: How to Run & Verify

You can run and test this repository in two different modes depending on your local cluster capabilities:

### Option A: The GitOps & ArgoCD Flow (Recommended)
This option demonstrates the production-like declarative GitOps workflow. It requires a cluster running ArgoCD.

1.  **Bootstrap the Platform Add-ons**:
    ```bash
    make bootstrap-existing
    # (or run 'make bootstrap' to spin up a fresh Kind cluster and install ArgoCD)
    ```
2.  **Create a Tenant**:
    Runs the CLI to write and commit `tenants/dev/tenant-a.yaml` into Git.
    ```bash
    ./cli/platform tenant-a create --api-version 2.23.1 --web-version 1.27-alpine
    ```
3.  **Register the vCluster in ArgoCD**:
    Since the workload is deployed *inside* the virtual cluster, we register the new vCluster control plane context in ArgoCD:
    ```bash
    ./cli/register-vcluster vcluster-tenant-a-dev
    ```
4.  **Verify the Tenant Status**:
    ```bash
    ./cli/platform tenant-a status
    ```
5.  **Run the Validation Tests**:
    ```bash
    ./cli/validate tenant-a dev
    ```
6.  **Delete the Tenant**:
    ```bash
    ./cli/platform tenant-a delete
    ```

---

### Option B: The Direct Helm & vCluster Flow (Quick Local Demo)
If you do not have ArgoCD running or want to run a quick test without committing files to Git, you can bypass ArgoCD and deploy the Helm chart and vCluster directly:

1.  **Deploy the vCluster and Workload**:
    This command will spin up a local vCluster using [`vcluster/shared-nodes.yaml`](./vcluster/shared-nodes.yaml) and immediately deploy [`charts/tenant`](./charts/tenant) inside it using your current local kube-context:
    ```bash
    make create TENANT=tenant-a ENV=dev
    ```
2.  **Verify the Workloads Inside the vCluster**:
    Connect to the virtual cluster and list the running resources:
    ```bash
    vcluster connect tenant-a-dev --namespace vcluster-tenant-a-dev -- kubectl get pods -n tenant-a
    # You should see: tenant-a-postgres-0, customer-api-*, and customer-web-* running
    ```
3.  **Delete the Local Resources**:
    ```bash
    make delete TENANT=tenant-a ENV=dev
    ```

---

## 2.3. Interactive Demo Recordings & Platform Showcase
To see the CLI commands, automatic vCluster provisioning, sync waves, and E2E validation suite running in real-time, you can watch the interactive terminal recordings below:

<table align="center">
  <tr>
    <td align="center" width="25%">
      <b>1. Tenant Provisioning</b><br/>
      <a href="https://asciinema.org/a/ha0577C30eV22PwJ" target="_blank">
        <img src="https://asciinema.org/img/play-button.png" width="80" alt="Tenant Provisioning"/>
      </a>
    </td>
    <td align="center" width="25%">
      <b>2. Tenant Validation</b><br/>
      <a href="https://asciinema.org/a/KbTlRvky9mGqSoo9" target="_blank">
        <img src="https://asciinema.org/img/play-button.png" width="80" alt="Tenant Validation"/>
      </a>
    </td>
    <td align="center" width="25%">
      <b>3. Full Platform Showcase</b><br/>
      <a href="https://asciinema.org/a/jr3CRkDl1eXs4pLr" target="_blank">
        <img src="https://asciinema.org/img/play-button.png" width="80" alt="Platform Showcase"/>
      </a>
    </td>
    <td align="center" width="25%">
      <b>4. Topology & Hierarchy</b><br/>
      <a href="https://asciinema.org/a/j3crkxelJGxwR0Mm" target="_blank">
        <img src="https://asciinema.org/img/play-button.png" width="80" alt="Topology Showcase"/>
      </a>
    </td>
  </tr>
</table>

### 📄 Full Read-Only Validation Output (Text Version)
If the terminal recording scrolls too quickly, you can expand these sections to read the exact text output:

<details>
<summary><b>Click to expand the full text output of <code>./cli/showcase-platform</code></b></summary>

```text
Starting Platform Showcase & Validation (Full Read Test)
Running passive and read-only checks...

═══════════════════════════════════════════════════════════════════════════
 1. Node Virtualization & Compute (KubeVirt)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Hypervisor-level compute isolation. Host cluster nodes run as KubeVirt Virtual Machines (VMs) on the physical host node srv-t7910.

  • Checking KubeVirt control plane (namespace: kubevirt)...
  ✔ KubeVirt control plane active: 6/6 pods in Running state.
  • Checking active Virtual Machines (VMs) backing the fleet (namespace: fleet)...
  ✔ Found 4 KubeVirt VMs (4 in Running state) in the 'fleet' namespace.
      host-euw1-control-plane-gw2k6   Running   true
      host-euw1-md-0-lvzrh-8twht      Running   true
      host-mgmt-control-plane-82v4s   Running   true
      host-mgmt-md-0-ckvd8-9qq6p      Running   true
  • Checking physical x86 compute node (srv-t7910)...
  ✔ Physical node srv-t7910 is READY (Hypervisor compute active).

═══════════════════════════════════════════════════════════════════════════
 2. GPU Governance & Slicing (HAMi vGPU)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Shared GPU usage (Tesla P4 & Quadro M4000) with hard VRAM (in MiB) and cores (%) isolation per tenant, without requiring MIG hardware.

  • Checking HAMi mutating admission webhook...
  ✔ MutatingWebhook 'hami-webhook' registered and active.
  • Checking HAMi controllers (namespace: kube-system)...
  ✔ HAMi controllers active (Device Plugin: 1 pods, Scheduler: 1 pods).
  • Checking advertised vGPU resources on node srv-t7910...
  ✔ Node srv-t7910 advertises vGPU capacity: 20 virtual cores/slices available.
  • Physical GPU configuration detected by HAMi:
      • NVIDIA-Tesla P4: 7680 MiB VRAM total, 10 slices vGPU, modo hami-core
      • NVIDIA-Quadro M4000: 8192 MiB VRAM total, 10 slices vGPU, modo hami-core

═══════════════════════════════════════════════════════════════════════════
 3. Declarative Infrastructure Composition (Crossplane v2)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Crossplane abstraction of underlying infrastructure. Defines a custom 'HostCluster' resource type that Crossplane automatically composes into CAPI and KubeVirt resources.

  • Checking Crossplane operator (namespace: crossplane-system)...
  ✔ Crossplane operator running successfully (4 pods).
  • Checking HostCluster Composite Resource Definition (XRD) and Composition...
  ✔ XRD 'hostclusters.fleet.homelab.io' established successfully.
  ✔ Composition 'hostcluster-kubevirt' configured.
  • Checking active HostCluster instances (XR resources)...
  ✔ Found 2 HostClusters declared via Crossplane:
      host-euw1   True   True   <none>
      host-mgmt   True   True   <none>

═══════════════════════════════════════════════════════════════════════════
 4. Multicluster Provisioning with CAPI & CAPK
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Automated and declarative cluster creation, upgrades, and deletion. CAPI (Cluster API) and CAPK (Provider KubeVirt) orchestrate the k8s lifecycle of the host clusters.

  • Checking Cluster API (CAPI) controllers and KubeVirt provider (CAPK)...
      • caaph-system/caaph-controller-manager (1 ready)
      • capi-kubeadm-bootstrap-system/capi-kubeadm-bootstrap-controller-manager (1 ready)
      • capi-kubeadm-control-plane-system/capi-kubeadm-control-plane-controller-manager (1 ready)
      • capi-operator-system/cluster-api-operator (1 ready)
      • capi-system/capi-controller-manager (1 ready)
      • capk-system/capk-controller-manager (1 ready)
  • Checking CAPI Clusters status in 'fleet' namespace...
  ✔ CAPI is managing 2 Kubernetes clusters:
      host-euw1   Provisioned   true   true
      host-mgmt   Provisioned   true   true
  • Checking CAPI Machine ↔ KubeVirt VM mapping...
      host-euw1-control-plane-gw2k6   host-euw1   Running   host-euw1-control-plane-gw2k6
      host-euw1-md-0-lvzrh-8twht      host-euw1   Running   host-euw1-md-0-lvzrh-8twht
      host-mgmt-control-plane-82v4s   host-mgmt   Running   host-mgmt-control-plane-82v4s
      host-mgmt-md-0-ckvd8-9qq6p      host-mgmt   Running   host-mgmt-md-0-ckvd8-9qq6p

═══════════════════════════════════════════════════════════════════════════
 5. Decentralized GitOps (ArgoCD & ClusterResourceSets)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Git desired state synchronization without a central SPOF. Each regional host cluster runs its own ArgoCD seeded by CAPI via ClusterResourceSets.

  • Checking central ArgoCD (namespace: argocd)...
  ✔ Central ArgoCD active, root application 'platform-root' is HEALTHY.
  • Detected GitOps ApplicationSets:
      • tenant-eso
      • tenant-routes
      • tenant-vclusters
      • tenant-workloads
  • Checking ClusterResourceSets (CRS) for network/GitOps bootstrapping...
  ✔ Found 5 ClusterResourceSets in 'fleet' namespace (injecting CNI and regional config):
      • calico-cni
      • calico-vxlan-cni
      • cilium-cni
      • mgmt-child
      • region-root-eu-west1

═══════════════════════════════════════════════════════════════════════════
 6. Connectivity & Health Check of Regional host-euw1
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Real connectivity validation via jump pod inside the management pod network. Verifies that the remote cluster is running, nodes are ready, CNI is healthy, and its local ArgoCD is active.

  • Interacting with host-euw1 (jump pod)...
    
    ══ CLUSTER host-euw1 ══
      ✔ CAPI: phase=Provisioned controlPlaneReady=true
      ✔ nodos Ready: 2
      ✔ CNI pods Running: 3
      ✔ DNS cross-node (MTU): OK
      ✔ StorageClass: 1

═══════════════════════════════════════════════════════════════════════════
 7. Tenant Virtual Control Plane & Network Isolation (vCluster + CNP)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Virtual API server and etcd per tenant via vCluster, avoiding CRD conflicts. Physical network is isolated with host-side CiliumNetworkPolicies, blocking cross-tenant traffic.

  • Listing active vClusters on the host...
        
                      NAME             |          NAMESPACE           | STATUS  | VERSION | CONNECTED |  AGE   
        -------------------------------+------------------------------+---------+---------+-----------+--------
          vcluster-tenant-a-acceptance | vcluster-tenant-a-acceptance | Running | 0.35.0  |           | 3d22h  
          vcluster-tenant-a-dev        | vcluster-tenant-a-dev        | Running | 0.35.0  |           | 3d22h  
          vcluster-tenant-a-prod       | vcluster-tenant-a-prod       | Running | 0.35.0  |           | 3d22h  
          vcluster-tenant-b-dev        | vcluster-tenant-b-dev        | Running | 0.35.0  |           | 3d22h  
          vcluster-tenant-c-dev        | vcluster-tenant-c-dev        | Running | 0.35.0  |           | 3d18h  
          vcluster-tenant-x-dev        | vcluster-tenant-x-dev        | Running | 0.35.0  |           | 18h    
          vcluster-tenant-y-dev        | vcluster-tenant-y-dev        | Running | 0.35.0  |           | 18h    
        
  • Checking network isolation policies (CiliumNetworkPolicy) on the host...
  ✔ Found 7 CiliumNetworkPolicies on the host:
      vcluster-tenant-a-acceptance   tenant-a-isolation
      vcluster-tenant-a-dev          tenant-a-isolation
      vcluster-tenant-a-prod         tenant-a-isolation
      vcluster-tenant-b-dev          tenant-b-isolation
      vcluster-tenant-c-dev          tenant-c-isolation
      vcluster-tenant-x-dev          tenant-x-isolation
      vcluster-tenant-y-dev          tenant-y-isolation
  • Isolation test: Attempting curl from tenant-b to tenant-a (must fail/be blocked)...
  ✔ Network isolation successful: Direct traffic tenant-b → tenant-a BLOCKED (HTTP 000 / Timeout).

═══════════════════════════════════════════════════════════════════════════
 8. External Access & TLS (Gateway API + cert-manager)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: North-south routing using Cilium Gateway API. cert-manager issues TLS certificates automatically via gateway-shim hooks.

  • Checking Cilium GatewayClass...
  ✔ GatewayClass 'cilium' successfully accepted by the Cilium operator.
  • Checking Gateways and HTTPRoutes configured for tenant-a (dev)...
  ✔ Gateway 'tenant-a-gateway' PROGRAMMED=True with assigned IP: 192.168.178.205.
  ✔ Found 2 HTTPRoutes in vcluster-tenant-a-dev:
      tenant-a-api-route   [api.tenant-a.example.local]
      tenant-a-web-route   [web.tenant-a.example.local]
  • Checking cert-manager TLS Certificates for Gateways...
  ✔ Found 15 TLS certificates managed by cert-manager:
      caaph-system                        caaph-serving-cert                        True
      capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-serving-cert       True
      capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-serving-cert   True
      capi-operator-system                capi-operator-serving-cert                True
      capi-system                         capi-serving-cert                         True
      capk-system                         capk-serving-cert                         True
      cert-manager                        cluster-home-ca                           True
      gateway                             cluster-home-wildcard                     True
      vcluster-tenant-a-acceptance        tenant-a-tls                              True
      vcluster-tenant-a-dev               tenant-a-tls                              True
      vcluster-tenant-a-prod              tenant-a-tls                              True
      vcluster-tenant-b-dev               tenant-b-tls                              True
      vcluster-tenant-c-dev               tenant-c-tls                              True
      vcluster-tenant-x-dev               tenant-x-tls                              True
      vcluster-tenant-y-dev               tenant-y-tls                              True

✔ SHOWCASE & VALIDATION COMPLETE!
All platform architecture components have been passively validated.
```
</details>

<details>
<summary><b>Click to expand the full text output of <code>./cli/showcase-topology</code></b></summary>

```text
Platform Topology & vCluster Models Showcase (read-only, live)

═══════════════════════════════════════════════════════════════════════════
 1. The Root cluster is the hypervisor AND hosts vClusters (MODEL 1)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: The physical HA k3s cluster wears two hats at once: it runs KubeVirt (so it is the VM hypervisor) and it also runs tenant vClusters directly on itself (centralized).

  • Physical cluster nodes (the substrate):
      srv-pi-rack1          Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.65    <none>   Ubuntu 24.04.3 LTS   6.8.0-1053-raspi      containerd://2.2.3-k3s1
      srv-pi-rack2a         Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.40    <none>   Ubuntu 24.04.1 LTS   6.8.0-1053-raspi      containerd://2.2.3-k3s1
      srv-pi-rack2b         Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.130   <none>   Ubuntu 24.10         6.11.0-1015-raspi     containerd://2.2.3-k3s1
      srv-rk1-nvme-01       Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.131   <none>   Ubuntu 24.04.1 LTS   6.1.0-1025-rockchip   containerd://2.2.3-k3s1
      srv-rk1-nvme-02       Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.48    <none>   Ubuntu 24.04.1 LTS   6.1.0-1025-rockchip   containerd://2.2.3-k3s1
      srv-rk1-nvme-03       Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.51    <none>   Ubuntu 24.04.1 LTS   6.1.0-1025-rockchip   containerd://2.2.3-k3s1
      srv-rk1-nvme-04       Ready   <none>                      29d     v1.35.5+k3s1   192.168.178.54    <none>   Ubuntu 24.04.1 LTS   6.1.0-1025-rockchip   containerd://2.2.3-k3s1
      srv-super6c-01-nvme   Ready   control-plane,etcd,worker   30d     v1.35.5+k3s1   192.168.178.120   <none>   Ubuntu 24.04.4 LTS   6.8.0-1053-raspi      containerd://2.2.3-k3s1
      srv-super6c-02-nvme   Ready   control-plane,etcd,worker   2d20h   v1.35.5+k3s1   192.168.178.121   <none>   Ubuntu 24.04.4 LTS   6.8.0-1053-raspi      containerd://2.2.3-k3s1
      srv-super6c-04-nvme   Ready   control-plane,etcd,worker   2d19h   v1.35.5+k3s1   192.168.178.122   <none>   Ubuntu 24.04.4 LTS   6.8.0-1047-raspi      containerd://2.2.3-k3s1
      srv-super6c-05-emmc   Ready   <none>                      2d18h   v1.35.5+k3s1   192.168.178.124   <none>   Ubuntu 24.04.4 LTS   6.8.0-1051-raspi      containerd://2.2.3-k3s1
      srv-super6c-06-emmc   Ready   <none>                      2d18h   v1.35.5+k3s1   192.168.178.123   <none>   Ubuntu 24.04.4 LTS   6.8.0-1053-raspi      containerd://2.2.3-k3s1
      srv-t7910             Ready   <none>                      8d      v1.35.5+k3s1   192.168.178.90    <none>   Ubuntu 26.04 LTS     7.0.0-22-generic      containerd://2.2.3-k3s1

  • KubeVirt virtualization engine running on the substrate:
      virt-handler-jz9lq   1/1   Running   102 (174m ago)   2d17h   10.0.6.222   srv-t7910   <none>   <none>
  ✔ srv-t7910 is the KubeVirt hypervisor — and (see §4) the same cluster also hosts vClusters.

═══════════════════════════════════════════════════════════════════════════
 2. A management cluster creates whole host clusters as KubeVirt VMs (MODEL 2)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: Crossplane v2 (HostCluster XR) + Cluster API (CAPI) + provider-KubeVirt (CAPK) declaratively turn a one-file request into a full Kubernetes cluster whose NODES are VMs.

  • KubeVirt VMs backing the guest clusters (these ARE the cluster nodes):
      host-euw1-control-plane-gw2k6   10.0.6.132   <none>   Running
      host-euw1-md-0-lvzrh-8twht      10.0.6.123   <none>   Running
      host-mgmt-control-plane-82v4s   10.0.6.157   <none>   Running
      host-mgmt-md-0-ckvd8-9qq6p      10.0.6.42    <none>   Running

  • Crossplane HostCluster XRs → composed into CAPI Clusters:
      host-euw1   regional     eu-west1   calico-vxlan   True
      host-mgmt   management              calico-vxlan   True

      host-euw1   Provisioned   true   true
      host-mgmt   Provisioned   true   true
  ✔ Each row is a real Kubernetes cluster whose control-plane/worker nodes are VMs on srv-t7910.

═══════════════════════════════════════════════════════════════════════════
 3. Each host runs its OWN ArgoCD + its OWN vClusters (MODELS 3 & 4)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: Decentralized GitOps: the management ArgoCD only creates clusters; each created host (role=management) gets its own ArgoCD (via CAAPH) seeded with a region-root, and provisions ITS region's vClusters locally — no central SPOF. A host promoted to management is the 'management-child' rung.

  • Management-role clusters (each runs its own ArgoCD):
      host-mgmt (region=none) → local ArgoCD apps: 1
  ✔ ArgoCD is sharded per cluster — the management plane is not a single point of failure.

═══════════════════════════════════════════════════════════════════════════
 4. vCluster placement — centralized (Root) vs decentralized (regional)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: The SAME tenant chart (vCluster + Postgres + api + web + quota + netpol) runs either directly on the Root (centralized) or inside a regional host (decentralized). Same contract, different placement.

  • CENTRALIZED vClusters (running directly on the Root cluster):
      • vcluster-tenant-a-acceptance
      • vcluster-tenant-a-dev
      • vcluster-tenant-a-prod
      • vcluster-tenant-b-dev
      • vcluster-tenant-c-dev
      • vcluster-tenant-x-dev
      • vcluster-tenant-y-dev

  • DECENTRALIZED vClusters (inside each regional host, queried via jump pod):
  ✔ Tenants are sharded across regional host VMs — the decentralized fleet model.

═══════════════════════════════════════════════════════════════════════════
 5. Variants validated: HA control plane & per-cluster CNI experiments
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: On the same substrate we A/B-tested control-plane HA (etcd quorum) and three CNIs. On nested KubeVirt the per-VM masquerade interfered with cross-VM overlay traffic (IPIP/Cilium); Calico-VXLAN is what we validated end-to-end (README §3.1 — framed as an experiment, not a verdict).

  • Control-plane replicas per cluster (HA = 3 → etcd quorum 2/3):
      host-euw1-control-plane   1     1     true
      host-mgmt-control-plane   1     1     true

  • CNI chosen per cluster (the experiment knob, spec.cni):
      host-euw1   calico-vxlan
      host-mgmt   calico-vxlan
  ✔ CNI is a per-cluster field; multi-VM clusters standardized on calico-vxlan after the experiment.

═══════════════════════════════════════════════════════════════════════════
 6. Management-of-managements: host-mgmt CREATES its own child (MODEL 6)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: host-mgmt is not just a workload host — it runs FULL CAPI and creates ITS OWN host cluster (mgmt-child). The child's VMs run on the Root's KubeVirt via CAPK external-infra (the only KVM node). Recursive fleet: a management cluster spawning more clusters, all GitOps.

  • host-mgmt runs CAPI (it IS a management cluster — providers Ready):
      coreprovider.operator.cluster.x-k8s.io/cluster-api ready=True
      bootstrapprovider.operator.cluster.x-k8s.io/kubeadm ready=True
      controlplaneprovider.operator.cluster.x-k8s.io/kubeadm ready=True
      infrastructureprovider.operator.cluster.x-k8s.io/kubevirt ready=True

  • host-mgmt CREATED a child cluster (mgmt-child):
      default   mgmt-child         Provisioned   29m   

  • the child's VMs run on the ROOT's KubeVirt (namespace mgmt-child, via external-infra):
      mgmt-child-control-plane-zcvr7   10.0.6.158   <none>   Running
      mgmt-child-md-0-257tx-vctmk      10.0.6.208   <none>   Running
  ✔ host-mgmt → creates mgmt-child → its VMs land on the Root's KubeVirt. Management-of-managements.

✔ TOPOLOGY & MODELS SHOWCASE COMPLETE
Same homelab, every model: hypervisor+host (1), mgmt creates clusters (2), decentralized
regional ArgoCD (3,4), HA + CNI variants (5), and management-of-managements (6: host-mgmt → child).
```
</details>

---


## 3. Detailed Architecture

The platform architecture is structured in a layered, decentralized model:

```
Management cluster (Scope: CAPI & Infrastructure)
  └─ CAPI + CAPK: Provisions VM host clusters on srv-t7910
  └─ ClusterResourceSet: seeds each host with its own ArgoCD + platform-root (App-of-Apps)
  
Host cluster (Scope: Environment dev/acc/prod - Decentralized ArgoCD)
  └─ platform-root (app-of-apps) -> provisions platform add-ons and ApplicationSets:
       ├─ ApplicationSet #1 (hosts-appset) -> provisions vClusters (k8s vanilla)
       ├─ ApplicationSet #2 (tenants-appset) -> deploys workload chart inside vClusters
       └─ ApplicationSet #3 (routes-appset) -> provisions Host Gateway API routes
```

### 3.1 vCluster Placement & Cluster-Topology Models (variants demonstrated live)

A core part of this exercise was exploring **where a tenant vCluster can live** and **who provisions
the cluster that hosts it**. The same physical homelab was used to stand up and validate the full
spectrum below. Each row is a distinct, real model — not a paper design — and maps to the scaling /
multi-region / security Design Questions answered in §5.

| # | Model / Variant | Who provisions the host & where the vCluster runs | Live example | Answers Design Question |
|---|---|---|---|---|
| 1 | **Hypervisor-cluster also hosts vClusters (centralized)** | The physical k3s cluster is *simultaneously* the KubeVirt **hypervisor** and the tenant host: the central ArgoCD provisions vClusters **directly on it**. The cluster wears both hats — substrate for VMs *and* multi-tenant control planes. | Root k3s runs **7 centralized vClusters** (`tenant-a/b/c/x/y`) + KubeVirt | Q1 (single-cluster / ~10 tenants) |
| 2 | **Management cluster creates host clusters (CAPI/CAPK on KubeVirt)** | A management cluster declaratively creates **whole Kubernetes host clusters as KubeVirt VMs** via Cluster API + provider-KubeVirt (CAPK), composed by **Crossplane v2** (`HostCluster` XR). | Root creates **5 host clusters** as VMs on `srv-t7910` | Q1 (Cluster API + Crossplane + fleet) |
| 3 | **Decentralized regional fleet (no central SPOF)** | Each created host cluster (`role=regional`) runs its **own ArgoCD** (seeded by a CAPI `ClusterResourceSet` → `region-root`) and hosts **its own** regional vClusters. The central ArgoCD never deploys tenants cross-cluster. | `host-euw1` (eu-west1): local ArgoCD + `vcluster-tenant-a` (pg+api+web) | Q1 (100/1000 multi-cluster), Q3 (GitOps), Q5 (multi-region) |
| 4 | **Management-of-managements (a cluster that creates clusters)** | `host-mgmt` (`role=management`) runs its **own full CAPI** (operator + providers, installed by CAAPH) and **creates its OWN child host cluster** (`mgmt-child`). The child's VMs run on the **Root's** KubeVirt via **CAPK external-infra** (`infraClusterSecretRef`), since that is the only KVM node. Recursive fleet, end-to-end GitOps. | `host-mgmt` → created `mgmt-child` (CP+worker Ready) | Q1 (hierarchical fleet management) |
| 5 | **HA control plane host cluster** | A host cluster with **3 control-plane replicas / etcd quorum** (2-of-3), vs the single-CP default. | demonstrated on a 3-CP host cluster (etcd quorum forms once on calico-vxlan) | Q1 (production resilience) |
| 6 | **Per-cluster CNI variants (an experiment)** | The CNI is selectable per cluster via the `cni` field: **Calico (IPIP)**, **Cilium**, **Calico-VXLAN**. We A/B'd all three on nested KubeVirt and **converged on Calico-VXLAN** for multi-VM clusters (see the note below). | all multi-VM clusters on `calico-vxlan` | Q5/Q6 (networking) |
| 7 | **vCluster isolation spectrum** | vCluster tenancy from **shared-nodes** (default, soft multi-tenancy) → dedicated/private nodes → fully separate clusters (the 9-model spectrum). Network isolation enforced by host-side `CiliumNetworkPolicy` default-deny. | shared-nodes live; deeper rungs designed (ADR-16) | Q6 (security, vCluster risks, isolation) |
| 8 | **HCI storage for VM disks** | We moved from ephemeral **containerDisk** to **CDI DataVolumes on Longhorn** (`storageClassName: longhorn-vm`) for **all** host clusters — CDI imports the cloud image into a replicated Longhorn PVC, so a VM disk **survives a node reboot** (treating the homelab like vSAN/HCI). | all host clusters on Longhorn DataVolumes | Q1 (production storage) |

> **A note on nested-KubeVirt networking (empirical, two separate layers).** Multi-node guest clusters
> on nested KubeVirt hit cross-node failures (workers never joining, etcd not reaching quorum). Two
> distinct things matter:
> 1. **VM network binding — use `bridge`, not `masquerade`.** With KubeVirt **masquerade**, *every* VM
>    is NAT'd to the **same** internal IP `10.0.2.2`, so all the guest's nodes report the **same
>    InternalIP** → they collide and cross-node routing/CNI breaks (the worker stays `NotReady`,
>    `install-cni` fails). The fix is **bridge** (CAPK's default when you set no `interfaces`/`networks`):
>    each VM gets a **unique pod-network IP** (`10.0.6.x`) → unique node IPs. All our working clusters use
>    bridge; this was the real root cause of the multi-node breakage.
> 2. **CNI overlay — `Calico-VXLAN` (UDP 4789).** On top of unique IPs, VXLAN is the dataplane we
>    validated end-to-end for the guest's pod overlay. We did not exhaustively tune the Cilium path
>    (MTU, `kubeProxyReplacement`) once VXLAN worked — an open avenue, not a dead end.
>
> *(Honest correction: an earlier draft blamed "masquerade dropping IPIP packets". The actual multi-node
> blocker is the masquerade IP collision above; the working clusters never used masquerade.)*

> 📊 **Flow diagram:** [`flow-management-of-managements.svg`](./flow-management-of-managements.svg)
> (source: `.mermaid`) — the full graph of what consumes/connects to what: Git → ArgoCD → CAPI/KubeVirt →
> host clusters → CAAPH/CRS addons → vClusters, plus `host-mgmt` creating `mgmt-child` via external-infra.

### 3.2 Resilience & Node-Failure (honest limitation + production answer)

During this work the single physical KVM host (`srv-t7910`) crashed, which took **every** nested host
cluster down at once. That is a real **single point of failure**, and it is worth stating plainly:

- **Why it happens:** all guest-cluster VMs are pinned to the one x86/KVM-capable node. There is no VM
  failover. Even the "HA" host cluster (3 control-plane replicas) stacks all 3 CP VMs on that *same*
  physical box — so it is HA against a process/VM failure, **not** against the node itself dying
  (etcd quorum across 3 VMs on one host is illusory for node-loss).
- **Recovery (what we actually observed — honest):** every VM disk is a **CDI DataVolume on Longhorn**
  (`longhorn-vm`), so the **disk persists** the node crash. But persistence of the disk is **not** the
  same as a clean control-plane recovery: when we cold-booted the crashed VMs in place, the guest
  **etcd/api-server did not come back healthy** (KubeadmControlPlane stayed `0/1`, api-server
  unreachable). The reliable fix was to **rebuild** those clusters via GitOps (`git rm` the HostCluster →
  let the teardown finish → re-add → ArgoCD/CAPI recreate them clean). So the lesson is nuanced:
  DataVolume saves the *bytes*, but a control plane that died with its node is best **re-provisioned**,
  not resurrected. (Freshly-provisioned clusters were healthy immediately; only the in-place cold-boots
  were not.)
- **Automated remediation:** a CAPI **`MachineHealthCheck`** ([`clusters/homelab/machinehealthchecks.yaml`](./clusters/homelab/machinehealthchecks.yaml))
  detects unhealthy worker Machines and recreates them declaratively (no manual pod deletion). It is
  intentionally scoped to **workers** (recreating a control-plane mid-flap can strand the immutable
  `controlPlaneEndpoint`) with long timeouts to avoid churn on the flaky nested network.
- **Production answer:** multiple hypervisor nodes; `evictionStrategy: LiveMigrate` + replicated
  storage to drain a failing node; DataVolume-backed disks everywhere; `MachineHealthCheck` with a
  tuned `maxUnhealthy` (≈40%) so a node loss remediates only its share and short-circuits fleet-wide
  outages; and a control plane spread **across** physical nodes.

### Key Design Decison Records (ADRs)
*   **Decentralized GitOps (ADR-02 / ADR-13)**: To eliminate single points of failure (SPOF) and acotate blast radius, each host cluster runs its own local ArgoCD. The management cluster only handles CAPI VM creation and seeds the local ArgoCDs.
*   **Gateway API Persona Split (ADR-06)**: The platform SRE team owns the global `GatewayClass` (Cilium), while the tenant controls their own routing objects. Gateway and HTTPRoutes are created host-side targeting the vCluster-synced services.
*   **Eventual Consistency & Sync Waves (ADR-08)**: Provisioning uses sync waves: Namespace (0) -> Policies/Quotas (1) -> Secret (2) -> PostgreSQL (3) -> Applications (4). ArgoCD blocks application deployment if the database fails to report healthy.

---

## 4. How the PDF Requirements Map to Code

### Dedicated Namespace & vCluster (Req 1, 3)
*   The virtual cluster control plane is spawned on the host inside `vcluster-<tenant>-<env>` via [`hosts-appset.yaml`](./applicationsets/hosts-appset.yaml) using the configuration in [`vcluster/shared-nodes.yaml`](./vcluster/shared-nodes.yaml).
*   Inside the vCluster, a dedicated namespace matching the tenant's name is provisioned by the workload chart [`charts/tenant/templates/apps-deployment.yaml`](./charts/tenant/templates/apps-deployment.yaml).

### Dedicated PostgreSQL (Req 3)
*   Deployed as a dedicated `StatefulSet` with PVC persistence in [`postgres.yaml`](./charts/tenant/templates/postgres.yaml).

### Resource Governance (Req 6)
*   **ResourceQuota**: Defined in [`quota.yaml`](./charts/tenant/templates/quota.yaml) using the values `requests.cpu: "2"`, `requests.memory: 4Gi`, `limits.cpu: "4"`, `limits.memory: 8Gi`, and `pods: "20"`.
*   **LimitRange**: Defined in [`limitrange.yaml`](./charts/tenant/templates/limitrange.yaml) to enforce container-level defaults.

### Network Isolation (Req 7)
*   Enforced via a host-side `CiliumNetworkPolicy` in [`networkpolicy.yaml`](./charts/tenant/templates/networkpolicy.yaml). It denies all cross-namespace traffic (`tenant-a -> tenant-b DENIED`) while allowing traffic from the host L7 ingress controller.

### Secret Management (Req 8)
*   **Default**: In-chart autogenerated secrets using Helm's `randAlphaNum` and `lookup` in [`secret.yaml`](./charts/tenant/templates/secret.yaml), with `/data` ignored in the ApplicationSet to prevent drift rotation.
*   **ESO Option**: Opt-in via [`eso-appset.yaml`](./applicationsets/eso-appset.yaml) to generate keys in-cluster without storing sensitive material in Git.

### External Access & TLS (Req 12)
*   Gateway and HTTPRoute definitions terminate TLS on the host in [`routes-appset.yaml`](./applicationsets/routes-appset.yaml), targeting the virtual services. TLS certs are issued by cert-manager gateway-shim.

---

## 5. Design Questions & Answers

### Q1: Scaling — 10 / 100 / 1000 tenants
Our platform is architected to scale out using a multi-cluster fleet design rather than vertically sizing a single host cluster. This mitigates the host cluster control-plane (`etcd`/API server) saturation which is the primary bottleneck of running many vClusters.

*   **10 Tenants**: Run on a single **Host Cluster** (Control Plane + Workers). This maps to our single-host local test setups.
*   **100 Tenants**: Distributed across 2–4 medium Host Clusters (e.g. sharded by environment or region).
*   **1000 Tenants (Multi-Cluster Fleet)**: Distributed across a fleet of 10–20 Host Clusters managed by a dedicated **Management Cluster** running Cluster API (CAPI).
    *   **Referenced Diagrams**:
        *   [`homelab-kubevirt-fleet.svg`](./homelab-kubevirt-fleet.svg) — Illustrates our homelab fleet topology where the management cluster controls Host Cluster VMs (`host-euw1`, etc.) via KubeVirt, each running its own local regional ArgoCD.
        *   [`architecture-ideal-vs-homelab.svg`](./architecture-ideal-vs-homelab.svg) — Contrasts the single-host demo with the multi-cluster production fleet sharded over OpenStack/Bare Metal.
    *   **Code Implementation Examples**:
        *   **Host Cluster Definitions**: Spawning a Host Cluster VM in a specific region is done declaratively via CAPI manifests, see [`clusters/homelab/host-euw1.yaml`](./clusters/homelab/host-euw1.yaml).
        *   **Infrastructure Composition**: Crossplane v2 is used to compose these host clusters, matching the custom platform API defined in [`fleet/config/crossplane-xrd.yaml`](./fleet/config/crossplane-xrd.yaml) to the CAPI resources defined in [`fleet/config/crossplane-composition.yaml`](./fleet/config/crossplane-composition.yaml).
        *   **Decentralized GitOps**: Each regional host cluster runs its own ArgoCD seeded by a CAPI ClusterResourceSet (preventing a central ArgoCD from becoming a SPOF). The regional ArgoCD reconciles only its regional config, see [`clusters/management/region-root-eu-west1.yaml`](./clusters/management/region-root-eu-west1.yaml) pointing to regional tenants in [`clusters/regions/eu-west1/tenants/`](./clusters/regions/eu-west1/tenants/).
        *   **Sleep Mode (Density)**: For development environments at this scale, idle vCluster replicas are scaled down to `0` and woken up on-demand to maximize node density.


### Q2: Application Lifecycle — 5 / 50 / 500 apps
*   **Git Layout**: We divide our Git repository structure between `/clusters` (defining platform infrastructure) and `/tenants` (defining product/environment specs). Review [`tenants/dev/tenant-a.yaml`](./tenants/dev/tenant-a.yaml) to see how a single file represents a tenant configuration.
*   **Application Catalog**: For 50 or 500 applications, we define golden paths using Helm library charts, see our modular packaging structure in [`charts/tenant/`](./charts/tenant/).
*   **Promotion Flow**: Promotion from `dev` to `test` and `prod` is executed as-code by moving tenant configuration specs between Git directories (e.g. from `/tenants/dev/` to `/tenants/prod/`). ArgoCD controllers local to each regional cluster pull their specific folder, ensuring isolated promotions.

### Q3: GitOps Integration (Argo CD vs. Flux)
*   **ApplicationSet Generation**: We selected ArgoCD due to its native `ApplicationSet` Git generator. It automatically reads tenant files in Git to generate virtual clusters and workloads. See:
    *   [`applicationsets/hosts-appset.yaml`](./applicationsets/hosts-appset.yaml) — generates the vCluster instances on the host cluster.
    *   [`applicationsets/tenants-appset.yaml`](./applicationsets/tenants-appset.yaml) — generates the tenant workloads *inside* each vCluster.
*   **Decentralized Bootstrapping**: To prevent a single central ArgoCD from becoming a SPOF, each host cluster runs its own ArgoCD. Management cluster seeds local ArgoCDs via a CAPI ClusterResourceSet, see [`clusters/bootstrap-crs.yaml`](./clusters/bootstrap-crs.yaml). Flux could replicate this using GitRepository and HelmRelease resources combined with Kustomize.

### Q4: Version Management & Upgrades
*   **Image Version Gating**: Versions are image tags configured in the tenant spec, see [`tenants/dev/tenant-a.yaml`](./tenants/dev/tenant-a.yaml#L7-L11). Upgrades are triggered by committing a new tag.
*   **ArgoCD Mapping**: The ApplicationSet maps these tags to the Helm chart's deployment values, see [`applicationsets/tenants-appset.yaml`](./applicationsets/tenants-appset.yaml#L62-L66).
*   **Reconciliation & Drift**: ArgoCD actively reconciles drift. We configure automated pruning and self-healing directly in the generator, see [`applicationsets/tenants-appset.yaml`](./applicationsets/tenants-appset.yaml#L79-L82). Progressive delivery (canary/blue-green) is achieved by interfacing Argo Rollouts with Gateway API routes.

### Q5: External Access & Multi-Region
*   **Gateway API & Persona Split**: The platform SRE team owns the cluster-wide `GatewayClass` (Cilium), while the tenant controls their own routing objects. See:
    *   [`applicationsets/routes-appset.yaml`](./applicationsets/routes-appset.yaml) — materializes the routing resources on the host cluster.
    *   [`charts/tenant-route/`](./charts/tenant-route/) — contains the route Helm chart rendering the Gateway, HTTPRoute, and cert-manager TLS Certificates.
*   **Multi-Region Access**: Configured dynamically. For example, the regional gateway in region `eu-west1` is orchestrated via [`clusters/management/region-root-eu-west1.yaml`](./clusters/management/region-root-eu-west1.yaml), routing traffic locally to the synced services.

### Q6: Security & Isolation Risks
*   **Control Plane vs. Network Isolation**: Control plane is isolated by vCluster, see [`vcluster/shared-nodes.yaml`](./vcluster/shared-nodes.yaml). Network is isolated by Cilium Network Policies blocking cross-namespace traffic (`tenant-a -> tenant-b DENIED`), see [`charts/tenant/templates/networkpolicy.yaml`](./charts/tenant/templates/networkpolicy.yaml).
*   **Secret Management**: Autogenerated credentials use Helm lookup and ignoreDifferences, see [`secret.yaml`](./charts/tenant/templates/secret.yaml). Optional External Secrets Operator (ESO) generates secrets in-cluster, see [`applicationsets/eso-appset.yaml`](./applicationsets/eso-appset.yaml).
*   **Referenced Diagrams**:
    *   [`secrets-flow.svg`](./secrets-flow.svg) — Details the secure secret lifecycle.
    *   [`tenancy-model.svg`](./tenancy-model.svg) — Illustrates the logical isolation boundary.

### Q7: Tenant Kubernetes Access
*   **Scoped Kubeconfig**: Tenants run `vcluster connect` to download a kubeconfig that isolates them. In the status tool [`cli/platform`](./cli/platform#L150-L152), we query the virtual control plane directly without exposing the host context.
*   **Logs & Metrics**: Scoped `kubectl logs` are fully supported within the vCluster plane. Centralized monitoring is designed using the LGTM stack (Loki/Grafana/Mimir), enforcing OIDC multi-tenancy based on tenant ID headers.

