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
*   **Cluster API (CAPI) VM Host Clusters**: [`clusters/homelab/`](./clusters/homelab/) (defines the CAPK/KubeVirt virtual machine host clusters: `host-a.yaml`, `host-b.yaml`, `host-c.yaml`, `host-euw1.yaml`).
*   **Crossplane v2 Composition & XRD**: [`fleet/config/`](./fleet/config/) (defines infrastructure composition layers):
    *   [`crossplane-xrd.yaml`](./fleet/config/crossplane-xrd.yaml) — defines the custom `HostCluster` resource API.
    *   [`crossplane-composition.yaml`](./fleet/config/crossplane-composition.yaml) — implements the composition pipeline matching XRD to CAPI virtual machines.
*   **KubeVirt & CDI Add-ons**: [`fleet/kubevirt/`](./fleet/kubevirt/) (deploys VM controllers and storage utilities on the bare-metal management node).
*   **Regional GitOps Base**: [`clusters/regions/`](./clusters/regions/) (parameterized regional root applications and tenants for multi-region configurations, like `eu-west1`).

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
      <a href="https://asciinema.org/a/jIzMQQ2x5Imn4cur" target="_blank">
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
  ✔ Found 12 KubeVirt VMs (12 in Running state) in the 'fleet' namespace.
      host-a-control-plane-h9mhb      Running   true
      host-a-md-0-5z44f-nmjkg         Running   true
      host-b-control-plane-m99hg      Running   true
      host-b-md-0-z52gt-rht98         Running   true
      host-c-control-plane-5t7vd      Running   true
      host-c-control-plane-cfm8j      Running   true
      host-c-control-plane-l7j2h      Running   true
      host-c-md-0-q79kb-rlnvc         Running   true
      host-euw1-control-plane-kfmn9   Running   true
      host-euw1-md-0-xkzwh-6m7mg      Running   true
      host-mgmt-control-plane-fsgsq   Running   true
      host-mgmt-md-0-cr5l8-brwhr      Running   true
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
  ✔ Found 5 HostClusters declared via Crossplane:
      host-a      True     True    hostcluster-kubevirt
      host-b      True     True    hostcluster-kubevirt
      host-c      True     True    hostcluster-kubevirt
      host-euw1   True     True    hostcluster-kubevirt
      host-mgmt   True     True    hostcluster-kubevirt

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
  ✔ CAPI is managing 5 Kubernetes clusters:
      host-a      Provisioned   true   true
      host-b      Provisioned   true   true
      host-c      Provisioned   true   true
      host-euw1   Provisioned   true   true
      host-mgmt   Provisioned   true   true
  • Checking CAPI Machine ↔ KubeVirt VM mapping...
      host-a-control-plane-h9mhb      host-a      Running   host-a-control-plane-h9mhb
      host-a-md-0-5z44f-nmjkg         host-a      Running   host-a-md-0-5z44f-nmjkg
      host-b-control-plane-m99hg      host-b      Running   host-b-control-plane-m99hg
      host-b-md-0-z52gt-rht98         host-b      Running   host-b-md-0-z52gt-rht98
      host-c-control-plane-5t7vd      host-c      Running   host-c-control-plane-5t7vd
      host-c-control-plane-cfm8j      host-c      Running   host-c-control-plane-cfm8j
      host-c-control-plane-l7j2h      host-c      Running   host-c-control-plane-l7j2h
      host-c-md-0-q79kb-rlnvc         host-c      Running   host-c-md-0-q79kb-rlnvc
      host-euw1-control-plane-kfmn9   host-euw1   Running   host-euw1-control-plane-kfmn9
      host-euw1-md-0-xkzwh-6m7mg      host-euw1   Running   host-euw1-md-0-xkzwh-6m7mg
      host-mgmt-control-plane-fsgsq   host-mgmt   Running   host-mgmt-control-plane-fsgsq
      host-mgmt-md-0-cr5l8-brwhr      host-mgmt   Running   host-mgmt-md-0-cr5l8-brwhr

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
  ✔ Found 4 ClusterResourceSets in 'fleet' namespace (injecting CNI and regional config):
      • calico-cni
      • calico-vxlan-cni
      • cilium-cni
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
      ✔ ArgoCD propio: 3 apps
      ✔ vClusters: 1
          vc: vcluster-register-29700080-7drr8 Completed
          vc: coredns-df8c87f55-2p7mp-x-kube-system-x-vcluster-tenant-a-dev Running
          vc: tenant-a-customer-api-897db9d68-r5rq8-x-tenant-a-x-v-e3aec378ea Running
          vc: tenant-a-customer-web-5fcdf6ccb5-bnl5w-x-tenant-a-x--c97081183e Running
          vc: tenant-a-postgres-0-x-tenant-a-x-vcluster-tenant-a-dev Running
          vc: vcluster-tenant-a-dev-0 Running

═══════════════════════════════════════════════════════════════════════════
 7. Tenant Virtual Control Plane & Network Isolation (vCluster + CNP)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ What this demonstrates: Virtual API server and etcd per tenant via vCluster, avoiding CRD conflicts. Physical network is isolated with host-side CiliumNetworkPolicies, blocking cross-tenant traffic.

  • Listing active vClusters on the host...
                      NAME             |          NAMESPACE           | STATUS  | VERSION | CONNECTED | AGE
        -------------------------------+------------------------------+---------+---------+-----------+-------
          vcluster-tenant-a-acceptance | vcluster-tenant-a-acceptance | Running | 0.35.0  |           | 3d5h
          vcluster-tenant-a-dev        | vcluster-tenant-a-dev        | Running | 0.35.0  |           | 3d5h
          vcluster-tenant-a-prod       | vcluster-tenant-a-prod       | Running | 0.35.0  |           | 3d5h
          vcluster-tenant-b-dev        | vcluster-tenant-b-dev        | Running | 0.35.0  |           | 3d5h
          vcluster-tenant-c-dev        | vcluster-tenant-c-dev        | Running | 0.35.0  |           | 3d1h
          vcluster-tenant-x-dev        | vcluster-tenant-x-dev        | Running | 0.35.0  |           | 71m
          vcluster-tenant-y-dev        | vcluster-tenant-y-dev        | Running | 0.35.0  |           | 67m

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
      caaph-system                        caaph-serving-cert                          True
      capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-serving-cert         True
      capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-serving-cert     True
      capi-operator-system                capi-operator-serving-cert                  True
      capi-system                         capi-serving-cert                           True
      capk-system                         capk-serving-cert                           True
      cert-manager                        cluster-home-ca                             True
      gateway                             cluster-home-wildcard                       True
      vcluster-tenant-a-acceptance        tenant-a-tls                                True
      vcluster-tenant-a-dev               tenant-a-tls                                True
      vcluster-tenant-a-prod              tenant-a-tls                                True
      vcluster-tenant-b-dev               tenant-b-tls                                True
      vcluster-tenant-c-dev               tenant-c-tls                                True
      vcluster-tenant-x-dev               tenant-x-tls                                True
      vcluster-tenant-y-dev               tenant-y-tls                                True

✔ SHOWCASE & VALIDATION COMPLETE!
All platform architecture components have been passively validated.
```
</details>

<details>
<summary><b>Click to expand the full text output of <code>./cli/showcase-topology</code></b></summary>

```text
Starting Platform Topology & Hierarchy Showcase (Read-Only)

═══════════════════════════════════════════════════════════════════════════
 1. Root Management Cluster (Physical k3s) & Hypervisor
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: Your physical HA k3s cluster acts as both the Root Management
 Plane and the KubeVirt Hypervisor. KubeVirt runs directly on this substrate.

  • Listing physical cluster nodes (the root infrastructure):
      srv-pi-rack1          Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.65
      srv-pi-rack2a         Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.40
      srv-pi-rack2b         Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.130
      srv-rk1-nvme-01       Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.131
      srv-rk1-nvme-02       Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.48
      srv-rk1-nvme-03       Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.51
      srv-rk1-nvme-04       Ready   <none>                      29d    v1.35.5+k3s1   192.168.178.54
      srv-super6c-01-nvme   Ready   control-plane,etcd,worker   30d    v1.35.5+k3s1   192.168.178.120
      srv-super6c-02-nvme   Ready   control-plane,etcd,worker   2d3h   v1.35.5+k3s1   192.168.178.121
      srv-super6c-04-nvme   Ready   control-plane,etcd,worker   2d3h   v1.35.5+k3s1   192.168.178.122
      srv-super6c-05-emmc   Ready   <none>                      2d2h   v1.35.5+k3s1   192.168.178.124
      srv-super6c-06-emmc   Ready   <none>                      2d2h   v1.35.5+k3s1   192.168.178.123
      srv-t7910             Ready   <none>                      8d     v1.35.5+k3s1   192.168.178.90

  • Checking if KubeVirt virtualization engine is active on the root nodes:
      virt-handler-jz9lq   1/1   Running   srv-t7910
  ✔ The physical node srv-t7910 is acting as the KubeVirt virtualization host.

═══════════════════════════════════════════════════════════════════════════
 2. Virtual Compute Layer (KubeVirt VMs)
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: The nodes of the guest CAPI clusters are NOT physical. They are
 running as KubeVirt Virtual Machine Instances (VMIs) hosted on the srv-t7910
 hypervisor.

  • Listing Virtual Machines (VMs) running on top of srv-t7910:
      host-a-control-plane-h9mhb      10.0.6.173   Running
      host-a-md-0-5z44f-nmjkg         10.0.6.253   Running
      host-b-control-plane-m99hg      10.0.6.141   Running
      host-b-md-0-z52gt-rht98         10.0.6.235   Running
      host-c-control-plane-5t7vd      10.0.6.182   Running
      host-c-control-plane-cfm8j      10.0.6.17    Running
      host-c-control-plane-l7j2h      10.0.6.24    Running
      host-c-md-0-q79kb-rlnvc         10.0.6.246   Running
      host-euw1-control-plane-kfmn9   10.0.6.180   Running
      host-euw1-md-0-xkzwh-6m7mg      10.0.6.6     Running
      host-mgmt-control-plane-fsgsq   10.0.6.150   Running
      host-mgmt-md-0-cr5l8-brwhr      10.0.6.184   Running
  ✔ All virtual nodes are active and mapped to srv-t7910.

═══════════════════════════════════════════════════════════════════════════
 3. Cluster Provisioning: Host Clusters vs. Child Managements
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: Crossplane v2 and CAPI provision virtual clusters on the VMs.
 We distinguish between regular Host Clusters (workload hosts) and Child
 Management Clusters (which run their own ArgoCD).

  • Listing Crossplane HostCluster (XR) instances:
      host-a      host                    True   True
      host-b      host                    True   True
      host-c      host                    True   True
      host-euw1   management   eu-west1   True   True
      host-mgmt   management              True   True

  • Listing corresponding CAPI Clusters:
      host-a      Provisioned   true   true
      host-b      Provisioned   true   true
      host-c      Provisioned   true   true
      host-euw1   Provisioned   true   true
      host-mgmt   Provisioned   true   true
  ✔ We have 2 Management clusters (host-mgmt, host-euw1) and 3 Host clusters
    (host-a/b/c).

═══════════════════════════════════════════════════════════════════════════
 4. Tenant Placement: Centralized vs. Decentralized (Regional) vClusters
═══════════════════════════════════════════════════════════════════════════
 ℹ️ Concept: We support two tenancy models: Centralized vClusters (running
 directly on the Root Management Cluster) and Decentralized vClusters (running
 inside virtual regional hosts).

  • Checking CENTRALIZED tenants (running directly on the Root Management Cluster):
      vcluster-tenant-b-dev   | Running | 0.35.0
      vcluster-tenant-c-dev   | Running | 0.35.0
      vcluster-tenant-x-dev   | Running | 0.35.0
      vcluster-tenant-y-dev   | Running | 0.35.0

  • Checking DECENTRALIZED tenants (running inside a regional virtual host cluster,
    e.g. host-euw1):
  • Connecting to host-euw1 via jump pod to list regional vClusters inside it...
      • Namespace: vcluster-tenant-a-dev (Active)
  ✔ Decentralized vClusters are fully sharded into their respective regional
    host VMs!

✔ TOPOLOGY SHOWCASE COMPLETE!
This demonstrates how KubeVirt VMs back CAPI clusters, how child managements
are sharded, and how tenants are distributed.
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

