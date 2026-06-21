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

## 2.3. Interactive Demo Recording
To see the CLI commands, automatic vCluster provisioning, sync waves, and E2E validation suite (`make validate`) running in real-time, you can watch the interactive terminal recording below:

- [![asciinema  for tenant-creation play butt n](https://asciinema.org/img/play-button.png)](https://asciinema.org/a/ha0577C30eV22PwJ)
- [![asciinema  for tenant Validation play butt n](https://asciinema.org/img/play-button.png)](https://asciinema.org/a/YExnzsktDB79rbtD)



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

