# Post 06 — Node-failure resilience (DRAFT — not published)

> **DRAFT for review.** Not on the blog yet. If you approve, I'll make the `docs/` version + add it to the index.
> Assets it would use: README §3.2 (the real crash story), `clusters/homelab/machinehealthchecks.yaml`.
> Possible video: a node-failure runbook (force-delete a zombie virt-launcher → MHC recreates the worker).

**Tags:** Kubernetes · ClusterAPI · KubeVirt · Resilience · SRE · Homelab

---

## The angle (honest war-story)

During this build the single physical KVM host **crashed mid-flight** and took **every** nested cluster down
at once. Instead of hiding it, the post owns it as the lesson.

## What I'd cover

- **The SPOF, stated plainly:** all guest-cluster VMs are pinned to one x86/KVM node. Even the "HA" cluster
  (3 control-plane replicas) stacks its 3 CP VMs on that *same* box → HA against a VM/process failure, **not**
  against the node dying (etcd quorum across 3 VMs on one host is illusory for node-loss).
- **The nuance that surprised me:** every VM disk is a **CDI DataVolume on Longhorn**, so the disk *survives*
  the crash — but **persistence of the disk ≠ a healthy control-plane recovery**. Cold-booting the crashed
  VMs in place left etcd/api-server unhealthy; the reliable fix was to **re-provision** the clusters from Git
  (`git rm` the HostCluster → let teardown finish → re-add → CAPI recreates them clean). *DataVolume saves the
  bytes; a control plane that died with its node is best re-provisioned, not resurrected.*
- **Automated remediation:** a CAPI **`MachineHealthCheck`** recreates unhealthy **worker** Machines
  declaratively (no manual pod deletion). Scoped to workers on purpose (recreating a control-plane mid-flap
  can strand the immutable `controlPlaneEndpoint`), with long timeouts for the flaky nested network.
- **The production answer:** multiple hypervisor nodes; control plane spread **across** physical nodes (real
  quorum); replicated storage; `MachineHealthCheck` with a tuned `maxUnhealthy` (~40%); and KubeVirt
  **LiveMigration** for *planned maintenance* (it moves a running VM, so it helps for draining a node — not
  for one that already died).

## Why it's a good post

It's the honest-engineering angle people actually engage with: "here's how it broke, here's what I learned,
here's the real fix." Shows you understand the difference between *HA against a process* and *HA against a
node*, and between *disk persistence* and *control-plane recovery*.

---

## Version EN (draft copy-paste)

My single-node homelab crashed mid-build and took the whole cluster fleet down. Here's what it taught me about "HA". 🧵

The trap: even a 3-replica "HA" control plane is a lie if all 3 VMs sit on the same physical box. That's HA against a process crash — not against the node dying.

The surprise: every VM disk was on replicated storage (Longhorn), so the bytes survived. But cold-booting the crashed control-plane VMs did NOT bring etcd/api-server back healthy. Disk persistence ≠ control-plane recovery. The reliable fix was to re-provision the clusters from Git (Cluster API recreates them clean).

What actually helps:
- MachineHealthCheck (CAPI) auto-recreates unhealthy WORKER nodes — scoped to workers on purpose.
- In production: multiple hypervisor nodes, control plane spread across them, replicated storage, and LiveMigration for planned maintenance (not for a node that already died).

A control plane that died with its node is best re-provisioned, not resurrected.

#Kubernetes #ClusterAPI #KubeVirt #SRE #Resilience #Homelab

---

## Version ES (draft copia-pega)

Mi homelab de un solo nodo se cayó en plena construcción y se llevó toda la flota de clusters. Esto me enseñó sobre "HA". 🧵

La trampa: hasta un control plane "HA" de 3 réplicas es mentira si las 3 VMs están en el mismo fierro. Eso es HA contra un crash de proceso — no contra que el nodo se muera.

La sorpresa: cada disco de VM estaba en storage replicado (Longhorn), así que los bytes sobrevivieron. Pero bootear en frío las VMs del control-plane NO devolvió etcd/api-server sanos. Persistencia del disco ≠ recuperación del control-plane. La solución confiable fue re-provisionar los clusters desde Git (Cluster API los recrea limpios).

Lo que sí ayuda:
- MachineHealthCheck (CAPI) recrea solo los WORKER nodes que se ponen unhealthy — scopeado a workers a propósito.
- En producción: varios nodos hypervisor, control plane repartido, storage replicado, y LiveMigration para mantenimiento planificado (no para un nodo que ya murió).

Un control plane que murió con su nodo conviene re-provisionarlo, no resucitarlo.

#Kubernetes #ClusterAPI #KubeVirt #SRE #Resiliencia #Homelab
