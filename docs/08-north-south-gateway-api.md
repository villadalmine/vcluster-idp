---
title: North-south access to a vCluster — Gateway API + cert-manager
---

# North-south access to a vCluster — Gateway API + cert-manager

*Each tenant runs inside its own vCluster. So how does external HTTPS traffic reach an app that lives inside a
virtual cluster? The Gateway API persona split, and a non-obvious vCluster detail. A homelab lab.*

[← all posts](./index.html)

## The persona split (Gateway API's whole point)

- 🛠️ The **platform / SRE** team owns the cluster-wide `GatewayClass` (Cilium).
- 🙋 The **tenant** owns its own `Gateway` + `HTTPRoute` objects.

Clean separation of who-owns-what — the modern replacement for one big shared Ingress controller.

## The non-obvious bit

vCluster **does not sync Gateway API objects to the host**, but it **does sync Services**. So the routing
(`Gateway` / `HTTPRoute`) is created **host-side** — by the `tenant-route` chart via an ApplicationSet —
targeting the **vCluster-synced Service**.

This matters because the host `Gateway` needs a **host LB IP**, which a `Gateway` *inside* the vCluster could
never get. (The chart's in-vCluster `gateway.yaml` is an intentional empty stub.)

> Service-sync-but-not-Gateway-sync is exactly the gotcha that makes the difference between a routing that
> works and one that silently never gets an address.

## TLS, automated

cert-manager issues the `Gateway`'s certificate via the gateway-shim — no manual certs.

## Isolation, both layers

- **North-south** is allowed through the host `Gateway`.
- **East-west cross-tenant** traffic is denied by a default-deny `CiliumNetworkPolicy`: `tenant-a → tenant-b`
  is blocked, while the L7 ingress path still works.

## Portable fallback

The chart also supports an `ingress` mode (classic Ingress) for clusters without Gateway API.
`externalAccess.mode` is the knob (default `gateway`).

## The YAML that makes it work
- [`charts/tenant-route/`](https://github.com/villadalmine/vcluster-idp/tree/main/charts/tenant-route) — host-side `Gateway` + `HTTPRoute` + TLS, targeting the vCluster-synced Service; `externalAccess.mode` switches gateway/ingress.
- [`applicationsets/routes-appset.yaml`](https://github.com/villadalmine/vcluster-idp/blob/main/applicationsets/routes-appset.yaml) — renders the routing host-side, per tenant.

---

<sub>Source: <a href="https://github.com/villadalmine/vcluster-idp/tree/main/charts/tenant-route">charts/tenant-route/</a> ·
<a href="https://github.com/villadalmine/vcluster-idp/tree/main/applicationsets">applicationsets/</a>.</sub>
