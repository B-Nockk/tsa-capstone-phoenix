# Architecture (fill this in)

## 1. Topology diagram
> Draw it (ASCII, Excalidraw, draw.io — anything). Show: your nodes, where each TaskApp
> tier runs, the ingress controller, and the request path.

```text
  Internet ──DNS──▶ nockk-tsa-capstone.duckdns.org
        │
        ▼
  ingress controller (nodes: 10.0.1.251, 10.0.1.244, 10.0.2.183)  ──TLS terminated by cert-manager──┐
        │                                                            │
        ▼                                                            ▼
  frontend Service ──▶ frontend Pods (nodes: 10.0.2.183, 10.0.1.251)        backend Service ──▶ backend Pods (nodes: 10.0.1.244, 10.0.1.251)
                              │  /api proxy                              │
                              └────────────────────────────────────────▶│
                                                                         ▼
                                                          postgres Service ──▶ postgres-0 (PVC on node 10.0.2.183)
```

## 2. Node & network
- **Nodes (role, size, AZ/region):** 1 Control Plane (`t3.small`) and 2 Workers (`t3.small`) deployed in AWS `eu-north-1` (Stockholm). All nodes run Ubuntu 22.04 LTS and are placed in public subnets to host the Ingress LoadBalancer/NodePort.
- **CIDR / subnet choices and why:** VPC is `10.0.0.0/16`. Public subnets are `10.0.1.0/24` and `10.0.2.0/24` to allow external ingress traffic and SSH access. Pod CIDR is `192.168.0.0/16` (strictly required by the Calico CNI) and Service CIDR is `10.43.0.0/16` (K3s default).
- **Firewall:** 
  - **Open to the world:** `80` (HTTP) and `443` (HTTPS) for application traffic.
  - **Internal only:** Node-to-node traffic (all protocols) within the VPC CIDR to support the Calico VXLAN overlay network.
  - **Why `6443` is closed:** The Kubernetes API port is restricted to the VPC CIDR plus a dynamic whitelist of the CI runner and admin IP. This prevents unauthorized public access to the cluster control plane while allowing CI/CD and admin `kubectl` access. `22` (SSH) is similarly restricted to admin IPs only.

## 3. Request flow (one paragraph)
> DNS → ingress → TLS → frontend → /api → backend → Postgres. Be specific about names/ports.

DNS resolves `nockk-tsa-capstone.duckdns.org` to the `ingress-nginx` controller. Traffic hits port 443, where TLS is terminated by a certificate provisioned by `cert-manager` (Let's Encrypt). The Ingress resource routes paths matching `/api` to the `backend` Service (ClusterIP on port 5000) and `/` to the `frontend` Service (ClusterIP on port 80). The frontend Nginx container uses `proxy_pass` to forward `/api/` requests internally to `backend:5000`. The backend (Flask/Gunicorn) connects to the `postgres` Service (ClusterIP on port 5432) to query the database.

## 4. The single-server assumptions you fixed  ← graders look here
> For each, name the assumption that was safe on one box but breaks on a cluster, and the
> K8s mechanism you used. Minimum: migrations, persistent storage, traffic routing,
> self-healing, zero-downtime deploys, secrets.

| Single-server assumption | Why it breaks at scale | How you fixed it |
|---|---|---|
| migrate-on-boot in the entrypoint | 2+ replicas race on `alembic upgrade head`, causing DB corruption or crashloops. | Created a dedicated Kubernetes `Job` with ArgoCD sync-wave `"1"` that runs migrations *before* the backend Deployment rolls out. |
| named volume on the host | Pods reschedule across nodes, leaving them unable to find their local data. | Used a `StatefulSet` for Postgres with a `volumeClaimTemplate` (PVC), decoupling storage lifecycle from the Pod and ensuring the volume re-attaches. |
| `ports:` published on the host | Many Pods, many nodes, one front door needed. Host ports cause collisions and bypass K8s load balancing. | Used `Service` (ClusterIP) abstractions and an `Ingress` resource with `ingress-nginx` as the single entry point, routing via hostnames/paths. |
| hardcoded DB IP (`localhost`) | Backend pods are ephemeral and distributed; they can't reach a DB running on another node's localhost. | Exposed Postgres via a `Service` (`postgres:5432`) providing stable internal DNS resolution across the cluster. |
| static IP for scaling | Manually updating Nginx configs or DNS when adding/removing nodes. | Used `topologySpreadConstraints` to automatically spread pods evenly across nodes, and K8s `Endpoints` to dynamically route traffic to healthy pods. |
| plaintext secrets in `.env` files | Cannot commit `.env` to Git for GitOps, and manually injecting them breaks automation. | Used Bitnami `SealedSecrets` to encrypt secrets locally, commit the ciphertext to Git, and let the in-cluster controller decrypt them into native K8s Secrets. |
| zero-downtime deploys | Killing the old container before the new one is ready drops active connections. | Configured `RollingUpdate` strategy (`maxSurge: 1`, `maxUnavailable: 0`) combined with `readinessProbe` so K8s only terminates old pods once new ones pass health checks. |

## 5. Choices & trade-offs
- **Raw YAML vs Helm vs kustomize — why:** **Helm**. Templating allows us to manage multiple environments (dev/prod) with a single chart, parameterized via `values-dev.yaml` and dynamically injected by the ArgoCD `ApplicationSet`. It avoids duplicating YAML files for every environment.
- **ingress-nginx vs k3s Traefik — why:** **ingress-nginx**. K3s's default Traefik was explicitly disabled (`--disable traefik`). ingress-nginx is the industry standard, has broader support for advanced annotations, and integrates seamlessly with cert-manager for ACME HTTP-01 challenges (which we patched via a CoreDNS hairpin script to fix in-cluster self-checks).
- **CNI / NetworkPolicy enforcement — what and why:** **Calico**. K3s's default Flannel CNI does not support Kubernetes `NetworkPolicy`. We installed Calico (`--flannel-backend=none`) to enforce strict zero-trust network rules (e.g., only frontend can talk to backend, only backend to postgres, denying all other ingress by default).
- **Secrets approach (out-of-band vs Sealed/External Secrets) — why:** **Sealed Secrets**. We needed a GitOps-native approach. Unlike External Secrets (which requires a running Vault/Cloud KMS), Sealed Secrets allows us to encrypt secrets locally using the cluster's public key, commit the ciphertext safely to Git, and have the in-cluster controller decrypt them. This keeps secrets out of plaintext in the repo without external dependencies.
