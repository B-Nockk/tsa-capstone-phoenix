# Cost Analysis

This echoes the Docker lesson's "why one server" thread — except now the answer to "is the extra cost worth it?" is yours to argue.

## Monthly itemized cost

*Calculations based on AWS On-Demand pricing for the eu-north-1 region.*

| Item | Spec | Qty | $/mo |
| --- | --- | --- | --- |
| control-plane VM | t3.small (2 vCPU, 2GB RAM) | 1 | $15.33 |
| worker VMs | t3.micro (2 vCPU, 1GB RAM) | 2 | $15.32 |
| load balancer / elastic IP | Built-in K3s ServiceLB + attached EIP | 1 | $0.00 |
| block storage (PVC) | EBS gp3 root volumes (20GB per node) | 3 | $4.80 |
| object storage (state, backups) | S3 Bucket (Terraform Remote State) | 1 | $0.50 |
| DNS / domain | DuckDNS | 1 | $0.00 |
| **Total** |  |  | **$35.95** |

*Note: The Elastic IP is free while attached to a running instance. We bypass expensive AWS Application Load Balancers (~$16+/mo) by using K3s's native ServiceLB routing directly to the instance.*

## Compared to the single-server Compose+Portainer deploy

* That stack cost roughly: $9.00 (Single t3.micro + 20GB EBS)
* This cluster costs: $35.95
* **What the extra spend buys:** From a strict financial administration perspective, this $26.95 premium acts as operational insurance. A single-server Docker Compose setup represents a single point of failure; if that node reboots, the business experiences total downtime. This Kubernetes cluster buys High Availability (HA), zero-downtime rolling deployments, and automated self-healing. If a worker node crashes, ArgoCD and K3s immediately reschedule the pods to the surviving node without human intervention.

When is it NOT worth it? If the application handles non-critical internal workloads, batch processing that can tolerate delays, or is a prototype where the cost of occasional downtime is lower than the $300/year premium of maintaining a distributed system.

## How I'd halve this

To optimize the ledger and cut this cost by 50% or more, I would transition the worker nodes to AWS Spot Instances, which typically offer up to a 70% discount compared to On-Demand rates. Because Kubernetes is inherently designed to handle node termination gracefully, spot interruptions would simply trigger a pod reschedule. Additionally, for lower-traffic environments, we could collapse the architecture into a two-node cluster (one control plane, one worker) or even a single-node K3s deployment, sacrificing High Availability to bring the monthly baseline back down to roughly $15.

---

**For full deployment instructions, CI/CD pipeline details, and troubleshooting, please see the [Deployment Runbook](RUNBOOK.md).**
