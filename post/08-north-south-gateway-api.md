# Post 08 — North-south access: Gateway API + cert-manager (DRAFT — not published)

> **DRAFT for review.** Not on the blog yet. If you approve, I'll make the `docs/` version + add it to the index.
> Assets it would use: `charts/tenant-route/` (gateway + httproutes + TLS), `applicationsets/routes-appset.yaml`,
> Cilium GatewayClass. Possible video: curl `https://api.<tenant>.<domain>` → 200, and cross-tenant blocked.

**Tags:** Kubernetes · GatewayAPI · Cilium · cert-manager · NetworkPolicy · PlatformEngineering · Homelab

---

## The angle

Each tenant runs inside its own vCluster — so **how does external HTTPS traffic reach an app that lives
inside a virtual cluster?** This post shows the Gateway API persona split and a non-obvious vCluster detail.

## What I'd cover

- **The persona split (Gateway API's whole point):** the platform/SRE team owns the cluster-wide
  `GatewayClass` (Cilium); the **tenant** owns its own `Gateway` + `HTTPRoute` objects. Clean separation of
  who-owns-what — the modern replacement for one big shared Ingress controller.
- **The non-obvious bit:** vCluster **does not sync Gateway API objects to the host**, but it **does sync
  Services**. So the routing (Gateway/HTTPRoute) is created **host-side** (by the `tenant-route` chart via an
  ApplicationSet), targeting the **vCluster-synced Service** — the host Gateway needs a host LB IP, which a
  Gateway *inside* the vCluster could never get. (The chart's in-vCluster `gateway.yaml` is an intentional
  empty stub.)
- **TLS, automated:** cert-manager issues the Gateway's certificate via the gateway-shim — no manual certs.
- **Isolation, both layers:** north-south is allowed through the host Gateway, while **east-west cross-tenant
  traffic is denied** by a default-deny `CiliumNetworkPolicy`. `tenant-a → tenant-b` is blocked; the L7
  ingress path still works.
- **Portable fallback:** the chart also supports an `ingress` mode (classic Ingress) for clusters without
  Gateway API — `externalAccess.mode` is the knob (default `gateway`).

## Why it's a good post

Gateway API is where ingress is heading, and "how do I expose an app that lives in a vCluster" is a real,
specific question. The Service-sync-but-not-Gateway-sync detail is exactly the kind of gotcha that makes the
post useful rather than generic.

---

## Version EN (draft copy-paste)

Each tenant runs in its own vCluster. So how does HTTPS traffic reach an app *inside* a virtual cluster? 🌐

Gateway API, with a persona split:
🛠️ the platform owns the cluster-wide GatewayClass (Cilium)
🙋 the tenant owns its own Gateway + HTTPRoute

The non-obvious part: vCluster doesn't sync Gateway API objects to the host — but it DOES sync Services. So the routing is created host-side, pointing at the synced Service (the host Gateway needs a host LB IP; a Gateway inside the vCluster could never get one). cert-manager issues the TLS cert automatically.

And isolation works both ways: north-south is allowed through the Gateway, while east-west cross-tenant traffic is denied by a default-deny CiliumNetworkPolicy (tenant-a → tenant-b blocked). There's also a portable `ingress` fallback for clusters without Gateway API.

#Kubernetes #GatewayAPI #Cilium #certmanager #PlatformEngineering #Homelab

---

## Version ES (draft copia-pega)

Cada tenant corre en su propio vCluster. ¿Cómo llega el tráfico HTTPS a una app que vive ADENTRO de un cluster virtual? 🌐

Gateway API, con persona split:
🛠️ la plataforma es dueña del GatewayClass global (Cilium)
🙋 el tenant es dueño de su propio Gateway + HTTPRoute

Lo no obvio: vCluster no sincroniza objetos de Gateway API al host — pero SÍ sincroniza Services. Así que el routing se crea del lado del host, apuntando al Service sincronizado (el Gateway del host necesita una IP de LB del host; un Gateway adentro del vCluster nunca la tendría). cert-manager emite el cert TLS automáticamente.

Y el aislamiento va en los dos sentidos: norte-sur permitido por el Gateway, este-oeste cross-tenant denegado por una CiliumNetworkPolicy default-deny (tenant-a → tenant-b bloqueado). También hay un fallback `ingress` portable para clusters sin Gateway API.

#Kubernetes #GatewayAPI #Cilium #certmanager #PlatformEngineering #Homelab
