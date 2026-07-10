# Runbook (fill this in — a teammate must rebuild from this alone)

> **💡 Pro-Tip (The "Easy Path"):** While the manual steps below are great for understanding the layers, the absolute fastest way to provision everything from zero is using the GitHub CLI. Simply run `make gh-deploy-full ENV=dev`. This triggers a GitHub Actions workflow that automatically handles Terraform provisioning, Ansible cluster configuration, and ArgoCD GitOps deployment in one shot.

## Provision from zero
```bash
# 1. infra
cd infra/terraform && terraform init && terraform apply
# 2. cluster
cd ../ansible && ansible-playbook -i inventory site.yml
# 3. kubeconfig
export KUBECONFIG=./kubeconfig && kubectl get nodes
# 4. platform (ingress, cert-manager, metrics-server, argocd) — exact commands:
cd ../..
make k8s-ingress-install ENV=dev
make k8s-cert-install ENV=dev
make k8s-issuer-apply-retry ENV=dev
make sec-install-controller ENV=dev
make argo-install ENV=dev

# 5. GitOps takes over
make argo-apply ENV=dev   # applies project.yaml and applicationset.yaml, then Argo syncs the app
```

## Day-2 operations
- **Scale a tier:** Edit `gitops/applicationset.yaml` (update `replicasBackend` / `replicasFrontend` in the `elements` list) or `helm/taskapp/values-dev.yaml`, commit, and push. ArgoCD will automatically sync the new replica count. *(Note: Avoid using `kubectl scale` directly, as ArgoCD's self-heal policy will revert it on the next sync).*
- **Roll back a bad deploy:** Since we use GitOps, the safest rollback is to `git revert <bad-commit>` and push. Alternatively, use the ArgoCD CLI to rollback to a previous revision: `argocd app history taskapp-dev` then `argocd app rollback taskapp-dev <id>`.
- **Run a new migration safely:** Migrations are handled by a Kubernetes Job (`helm/taskapp/templates/migration-job.yaml`) running `alembic upgrade head`. It uses ArgoCD sync-wave `"1"` so it runs *before* the backend deployment. To trigger it, update the backend image tag in Git and push. ArgoCD will deploy the new Job automatically.
- **Rotate a secret:** Secrets are managed via Sealed Secrets. Generate new secrets locally: `make sec-generate ENV=dev AUTO_INJECT=true`. This updates `helm/taskapp/templates/sealedsecret-dev.yaml`. Commit and push the updated sealed secret. ArgoCD will sync it to the cluster.

## Failure recovery (you'll demo one of these live)
- **A worker node dies / is drained:** what happens, what you do, expected recovery time. 
  Kubernetes will automatically reschedule the Pods to healthy nodes. Because we use `topologySpreadConstraints` and `PodDisruptionBudgets` (PDB), the app remains available during the drain.
  Expected recovery time: ~1-2 minutes for Pod rescheduling and readiness probes to pass.
  ```bash
  kubectl drain <node> --ignore-daemonsets --delete-emptydir-data   # the live-demo command
  kubectl get pods -n taskapp-dev -w  # watch them reschedule to other nodes
  ```
- **A backend Pod crashloops:** how you diagnose (`logs --previous`, `describe`, events). 
  1. `kubectl logs <pod-name> -n taskapp-dev --previous` to see the crash reason (e.g., missing env var, DB connection failure).
  2. `kubectl describe pod <pod-name> -n taskapp-dev` to check events (e.g., OOMKilled, Liveness probe failed).
  3. Fix the code/config, push to Git, and let ArgoCD deploy the fix.
- **A bad migration:** how you recover the DB. 
  If a migration fails, the Job will be in `Failed` state and the backend won't start.
  1. Check logs: `kubectl logs job/<job-name> -n taskapp-dev`.
  2. If the DB schema is corrupted, restore from the latest S3 backup (our CronJob `taskapp-dev-db-backup` dumps to S3 daily).
  3. Delete the failed Job: `kubectl delete job <job-name> -n taskapp-dev`.
  4. Fix the migration script in the backend code, push to Git, and let ArgoCD re-run the Job.
- **Postgres Pod is rescheduled:** prove the PVC re-attaches and data is intact. 
  Postgres is deployed as a StatefulSet with a PVC backed by AWS EBS. When the Pod is killed, the kubelet re-attaches the EBS volume to the new node.
  Prove it:
  1. Note the data: `kubectl exec -n taskapp-dev statefulset/postgres -- psql -U taskapp_user -d taskapp -c 'SELECT count(*) FROM tasks;'`
  2. Kill the pod: `kubectl delete pod postgres-0 -n taskapp-dev`
  3. Wait for it to restart: `kubectl get pods -n taskapp-dev -w`
  4. Verify data: Run the same `SELECT` query. The data will be intact.
