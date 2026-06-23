---
title: Node-failure resilience — what "HA" really means
---

# Node-failure resilience — what "HA" really means

*My single-node homelab crashed mid-build and took the whole cluster fleet down. Here's what it taught me
about HA — and the difference between disk persistence and control-plane recovery. A homelab war-story.*

[← all posts](./index.html)

## What happened

During this build the single physical KVM host **crashed mid-flight** and took **every** nested cluster down
at once. Rather than hide it, this post owns it as the lesson.

## The SPOF, stated plainly

All guest-cluster VMs are pinned to **one** x86/KVM node. Even the "HA" cluster with **3 control-plane
replicas** stacks its 3 CP VMs on that *same* box. That's HA against a **VM/process** failure — **not**
against the **node** dying. etcd quorum across 3 VMs on one host is illusory for node-loss: lose the host and
you lose all three at once.

## The nuance that surprised me

Every VM disk is a **CDI DataVolume on Longhorn**, so the disk *survived* the crash. But **disk persistence ≠
a healthy control-plane recovery.** Cold-booting the crashed VMs in place left etcd / api-server unhealthy.
The reliable fix was to **re-provision** the clusters from Git:

- `git rm` the `HostCluster` → let teardown finish → re-add → Cluster API recreates them clean.

> DataVolume saves the bytes; a control plane that died with its node is best **re-provisioned, not
> resurrected.**

## Automated remediation

A CAPI **`MachineHealthCheck`** recreates unhealthy **worker** Machines declaratively — no manual pod
deletion. It's scoped to workers on purpose: recreating a control-plane node mid-flap can strand the immutable
`controlPlaneEndpoint`. Timeouts are deliberately long for the flaky nested network.

## The production answer

- **Multiple hypervisor nodes**, with the control plane spread **across** physical nodes (real quorum).
- **Replicated storage** under the VM disks.
- `MachineHealthCheck` with a tuned `maxUnhealthy` (~40%).
- KubeVirt **LiveMigration** for *planned maintenance* — it moves a *running* VM, so it helps you drain a
  node, **not** recover one that already died.

Understanding the difference between *HA against a process* and *HA against a node* — and between *disk
persistence* and *control-plane recovery* — is the whole point.

## The YAML that makes it work
- [`clusters/homelab/machinehealthchecks.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/clusters/homelab/machinehealthchecks.yaml) — the `MachineHealthCheck` that auto-recreates unhealthy worker Machines (scoped to workers, long timeouts).
- [`clusters/homelab/host-euw1.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/clusters/homelab/host-euw1.yaml) — a HostCluster; re-provisioning = `git rm` this, let teardown finish, re-add.

---

<sub>Source: <a href="https://github.com/villadalmine/vcluster-idp/tree/main/clusters/homelab">clusters/homelab/</a> ·
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/fleet">fleet/</a>.</sub>
