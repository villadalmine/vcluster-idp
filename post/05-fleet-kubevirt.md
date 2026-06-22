# Post 05 — A fleet of clusters from one file (CAPI + Crossplane + KubeVirt)

**Tags:** Kubernetes · ClusterAPI · Crossplane · KubeVirt · Longhorn · IaC · PlatformEngineering · Homelab

> Homelab lab — one physical box, no cloud. Shows the *pattern*; the production answer (multi-node) is noted.

---

## ▶️ Assets
| Asset | Link |
|---|---|
| **Platform showcase** (KubeVirt VMs · Crossplane · CAPI · ArgoCD) | https://asciinema.org/a/lr5tg4GWV8KK5tF6 |
| **Fleet inspection** (reaching the created host clusters) | https://asciinema.org/a/LRxKPe9RE8adnPwV |
| Architecture diagram | [`bonus/fleet-architecture.png`](../bonus/fleet-architecture.png) |
| Source | [`fleet/`](../fleet/) · [`clusters/homelab/`](../clusters/homelab/) |

## The idea

I provision **whole Kubernetes clusters from a single YAML file** — on one bare-metal box, no cloud.

- A custom **`HostCluster`** resource (our own platform API) describes a cluster in a few lines: CPUs, memory,
  replicas, CNI, region, role.
- **Crossplane v2** composes that one file into the **Cluster API** object tree.
- **Cluster API + CAPK** (the KubeVirt provider) turn it into a **real cluster whose nodes are KubeVirt VMs**
  running on the physical node — declarative create / upgrade / delete.
- VM disks are **CDI DataVolumes on Longhorn**, so a disk **survives a node reboot** (treating the homelab
  like HCI).

Adding a cluster to the fleet = **one more `HostCluster` file**. Each created cluster then runs its own ArgoCD
and its own tenants (see the recursion post).

## Why it matters

It's **clusters-as-data**: the fleet is a directory of small declarative files, not a pile of imperative
provisioning scripts. The same approach scales from a homelab box to real infrastructure by swapping the CAPI
infra provider (KubeVirt here; could be a cloud or bare-metal provider in prod).

**Honest limitation:** it's a single physical node, so it's a real SPOF. The production answer is multiple
hypervisor nodes + control planes spread across them + replicated storage + MachineHealthCheck.

---

## Version EN (copy-paste)

I provision whole Kubernetes clusters from a single YAML file — on one bare-metal box, no cloud. ☁️🚫

How:
🟦 a custom HostCluster resource describes a cluster in a few lines (cpus, memory, replicas, cni, region)
🟪 Crossplane v2 composes that file into the Cluster API object tree
🟩 Cluster API + the KubeVirt provider (CAPK) turn it into a REAL cluster whose nodes are KubeVirt VMs on the physical node
🟧 VM disks are CDI DataVolumes on Longhorn, so a disk survives a node reboot (HCI-style)

Adding a cluster to the fleet = one more HostCluster file. Each created cluster then runs its own ArgoCD and its own tenants.

It's "clusters-as-data": the fleet is a directory of small declarative files, not imperative provisioning scripts — and it scales to real infra by swapping the CAPI infra provider.

Honest limitation: it's a single node = a real SPOF. The prod answer is multiple hypervisor nodes + control planes spread across them + replicated storage + MachineHealthCheck.

▶️ Showcase: https://asciinema.org/a/lr5tg4GWV8KK5tF6  ·  Fleet: https://asciinema.org/a/LRxKPe9RE8adnPwV

#Kubernetes #ClusterAPI #Crossplane #KubeVirt #IaC #PlatformEngineering #Homelab

---

## Version ES (copia-pega)

Provisiono clusters enteros de Kubernetes desde un solo archivo YAML — en un fierro, sin nube. ☁️🚫

Cómo:
🟦 un recurso HostCluster propio describe un cluster en pocas líneas (cpus, memoria, réplicas, cni, región)
🟪 Crossplane v2 compone ese archivo en el árbol de objetos de Cluster API
🟩 Cluster API + el provider de KubeVirt (CAPK) lo convierten en un cluster REAL cuyos nodos son VMs de KubeVirt en el nodo físico
🟧 los discos de las VMs son CDI DataVolumes sobre Longhorn, así un disco sobrevive un reboot del nodo (estilo HCI)

Agregar un cluster a la flota = un archivo HostCluster más. Cada cluster creado corre su propio ArgoCD y sus propios tenants.

Es "clusters-as-data": la flota es un directorio de archivos declarativos chicos, no scripts imperativos — y escala a infra real cambiando el infra-provider de CAPI.

Limitación honesta: es un solo nodo = SPOF real. La respuesta de prod es varios nodos hypervisor + control planes repartidos + storage replicado + MachineHealthCheck.

▶️ Showcase: https://asciinema.org/a/lr5tg4GWV8KK5tF6  ·  Fleet: https://asciinema.org/a/LRxKPe9RE8adnPwV

#Kubernetes #ClusterAPI #Crossplane #KubeVirt #IaC #PlatformEngineering #Homelab

---

## Notes (no publicar)
- Lab, single node SPOF (marcarlo). Reusa showcase-platform + showcase-fleet.
- Defensa prod: multi-nodo, CP repartido, Longhorn replicado, MachineHealthCheck, LiveMigration para mantenimiento.
