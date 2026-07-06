Here are the exact commands you can run from your control-plane SSH session to generate the text-based log evidence for your Capstone markdown file.

I have formatted these as copy-pasteable blocks that will output clean, verifiable logs for your grader.

### 1. `tls-valid.log` (Valid Certificate)

This command fetches the HTTP headers and SSL handshake details, proving that Let's Encrypt successfully secured your domain and traffic is encrypted.

```bash
curl -vI https://nockk-tsa-capstone.duckdns.org 2>&1 | awk '
  /^\* (Server certificate|subject:|start date:|expire date:|issuer:|SSL connection)/ {print}
  /^> (GET|Host:)/ {print}
  /^< (HTTP\/)/ {print}
'

```

*You can also grab the Kubernetes Certificate status:*

```bash
kubectl get certificate taskapp-dev-tls -n taskapp-dev

```

### 2. `pvc-persist.log` (Data Survives a Pod Kill)

Because your database is a StatefulSet named `postgres` , we can write a text file directly to the mounted Persistent Volume path (`/var/lib/postgresql/data` ), kill the pod, and prove the file is still there when the new pod boots.

Run this block all at once:

```bash
echo "--- 1. Writing test data to PVC ---"
kubectl exec -n taskapp-dev postgres-0 -- sh -c 'echo "Capstone PVC Test - $(date)" > /var/lib/postgresql/data/evidence.txt'
kubectl exec -n taskapp-dev postgres-0 -- cat /var/lib/postgresql/data/evidence.txt

echo -e "\n--- 2. Nuking the Postgres Pod ---"
kubectl delete pod postgres-0 -n taskapp-dev

echo -e "\n--- 3. Waiting for Pod to recover ---"
kubectl wait --for=condition=ready pod/postgres-0 -n taskapp-dev --timeout=120s

echo -e "\n--- 4. Verifying data survived ---"
kubectl exec -n taskapp-dev postgres-0 -- cat /var/lib/postgresql/data/evidence.txt

```

### 3. `zero-downtime.log` (Unbroken 200s during Rollout)

This script runs a continuous `curl` every 0.5 seconds in the background while forcing Kubernetes to perform a rolling update of your backend Deployment.

Run this block:

```bash
echo "--- Starting continuous curl ---"
# Start curling in the background
while true; do
  curl -s -o /dev/null -w "%{time_local} | HTTP %{http_code}\n" https://nockk-tsa-capstone.duckdns.org/api/health
  sleep 0.5
done > zero-downtime.log &
CURL_PID=$!

echo "--- Triggering Backend Rollout ---"
kubectl rollout restart deployment backend -n taskapp-dev
kubectl rollout status deployment backend -n taskapp-dev

echo "--- Stopping curl and checking logs ---"
kill $CURL_PID
echo "Total requests made: $(wc -l < zero-downtime.log)"
echo "Non-200 responses (should be empty):"
grep -v "HTTP 200" zero-downtime.log || echo "SUCCESS: 100% Uptime!"

```

*(Copy the terminal output and the contents of the `zero-downtime.log` file).*

### 4. `hpa-scale.log` (Replicas climbing under load)

Because you configured an HPA for the backend, we can spin up a temporary pod inside the cluster to violently hammer the backend Service with traffic until the CPU spikes and triggers a scale-up.

**Terminal 1 (Watch the HPA and Pods):**

```bash
kubectl get hpa backend-hpa -n taskapp-dev -w

```

**Terminal 2 (Generate the Load):**

```bash
kubectl run -i --tty load-generator --rm --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://backend.taskapp-dev.svc.cluster.local:5000/api/health > /dev/null; done"

```

*Wait about 60-90 seconds. In Terminal 1, you will see the CPU % shoot up and the Replicas scale from `2` up to `5`. Copy that output as your evidence, then `Ctrl+C` the load generator.*

### 5. `argocd-synced.log` (ArgoCD Healthy)

This outputs a clean table proving your GitOps pipeline is fully synchronized and healthy. Because you deployed it to the `argocd` namespace, you can query the Application Custom Resource directly:

```bash
kubectl get application taskapp-dev -n argocd -o custom-columns=NAME:.metadata.name,REPO:.spec.source.repoURL,SYNC_STATUS:.status.sync.status,HEALTH_STATUS:.status.health.status,REVISION:.status.sync.revision

```

### 6. `failover.log` (App up after node drain)

To prove High Availability (HA), we will purposefully evict all pods from one of your worker nodes (e.g., `ip-10-0-2-21`) while the application is running.

Run this block:

```bash
# 1. Identify the worker node to kill
WORKER_NODE="ip-10-0-2-21"

# 2. Drain the node (forces pods to move)
echo "--- Evicting pods from $WORKER_NODE ---"
kubectl drain $WORKER_NODE --ignore-daemonsets --delete-emptydir-data --force

# 3. Prove they moved to the other node
echo -e "\n--- New Pod Distribution ---"
kubectl get pods -n taskapp-dev -o wide

# 4. Prove the app is still accessible
echo -e "\n--- API Health Check ---"
curl -s -I https://nockk-tsa-capstone.duckdns.org/api/health | head -n 1

# 5. Restore the cluster capacity
echo -e "\n--- Restoring Node ---"
kubectl uncordon $WORKER_NODE

```
