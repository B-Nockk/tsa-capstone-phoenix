# EVIDENCE

Drop screenshots/logs here, named so a grader knows what each proves:

- `nodes-ready.png` — multi-node `kubectl get nodes`
    ```log
    NAME            STATUS   ROLES                  AGE     VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
    ip-10-0-2-183   Ready    <none>                 3h17m   v1.28.8+k3s1   10.0.2.183    <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
    ip-10-0-1-251   Ready    control-plane,master   3h18m   v1.28.8+k3s1   10.0.1.251    <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
    ip-10-0-1-244   Ready    <none>                 3h17m   v1.28.8+k3s1   10.0.1.244    <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
    ```

- `pods-spread.png` — replicas on different nodes (`-o wide`)
    ```log
    NAME                                READY   STATUS      RESTARTS   AGE     IP               NODE            NOMINATED NODE   READINESS GATES
    postgres-0                          1/1     Running     0          3h17m   192.168.98.141   ip-10-0-2-183   <none>           <none>
    backend-6fd5cbdb4b-ffpz4            1/1     Running     0          3h15m   192.168.31.139   ip-10-0-1-244   <none>           <none>
    frontend-7897487fb7-m42vl           1/1     Running     0          3h15m   192.168.98.142   ip-10-0-2-183   <none>           <none>
    frontend-7897487fb7-n4g6w           1/1     Running     0          3h15m   192.168.174.75   ip-10-0-1-251   <none>           <none>
    taskapp-dev-migrate-5d6b8fc-4zbk6   0/1     Completed   0          15m     192.168.31.143   ip-10-0-1-244   <none>           <none>
    backend-6fd5cbdb4b-rr5fl            1/1     Running     0          3h15m   192.168.174.74   ip-10-0-1-251   <none>           <none>
    ```

- `tls-valid.png` — valid cert (curl -vI / SSL Labs)
    ```log
    ubuntu@ip-10-0-1-251:~$ curl -vI https://nockk-tsa-capstone.duckdns.org 2>&1 | grep -E "subject|issuer|SSL certificate|CN="
    *  subject: CN=nockk-tsa-capstone.duckdns.org
    *  subjectAltName: host "nockk-tsa-capstone.duckdns.org" matched cert's "nockk-tsa-capstone.duckdns.org"
    *  issuer: C=US; O=Let's Encrypt; CN=YR2
    *  SSL certificate verify ok.
    ```

- `pvc-persist.log` — data survives a Pod kill
    ```log
    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev exec -it postgres-0 -- psql -U taskapp_user -d taskapp -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"
    Defaulted container "postgres" out of: postgres, fix-volume-permissions (init)
    table_name
    --------------
    alembic_version
    tasks
    users
    (3 rows)

    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev exec -it postgres-0 -- psql -U taskapp_user -d taskapp -c "SELECT * FROM users LIMIT 5;"
    Defaulted container "postgres" out of: postgres, fix-volume-permissions (init)
    id |  username  |                                                           password_hash                                                            |         created_at
    ----+------------+------------------------------------------------------------------------------------------------------------------------------------+----------------------------
    1 | adminADMIN | scrypt:32768:8:1$wgVKDkO56JYDIMif$c32dd14ce81c7e3dad24258bf541802c3be21f0c29019e0b2658471e0410c882a756218301e301881a3ae077905882859c6c22858a59a3e2f1170d8ed7e80082 | 2026-07-07 09:26:42.695441
    (1 row)

    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev exec -it postgres-0 -- psql -U taskapp_user -d taskapp -c "SELECT * FROM tasks LIMIT 5;"
    Defaulted container "postgres" out of: postgres, fix-volume-permissions (init)
    id |                 title                 |                       description                       | priority |   status    |         created_at         |         updated_at
    ----+---------------------------------------+---------------------------------------------------------+----------+-------------+----------------------------+----------------------------
    1 | Optimize LinkedIn Profile             | Optimize linkedIn profile to be Devops focused          | high     | in_progress | 2026-07-07 09:28:09.667195 | 2026-07-07 09:28:09.667198
    2 | Gather Capstone Project Evidence      | Get logs                                               +| high     | in_progress | 2026-07-07 09:29:00.487084 | 2026-07-07 09:29:00.487087
      |                                       | Get Images                                              |          |             |                            |
    3 | Submit Capstone Project               |                                                         | high     | todo        | 2026-07-07 09:29:19.718862 | 2026-07-07 09:29:19.718865
    4 | Add Monitoring to Capstone Project    | Add graphana & Prometheus                               | medium   | todo        | 2026-07-07 09:29:59.785392 | 2026-07-07 09:29:59.785395
    (4 rows)

    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev get pvc
    NAME                          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
    postgres-storage-postgres-0   Bound    pvc-e2eaddc6-1b1f-41f0-bfc0-c3d2414a972e   10Gi       RWO            local-path     3h40m

    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev delete pod postgres-0
    pod "postgres-0" deleted

    ubuntu@ip-10-0-1-251:~$ kubectl -n taskapp-dev exec -it postgres-0 -- psql -U taskapp_user -d taskapp -c "SELECT * FROM tasks LIMIT 5;"
    Defaulted container "postgres" out of: postgres, fix-volume-permissions (init)
    id |                 title                 |                       description                       | priority |   status    |         created_at         |         updated_at
    ----+---------------------------------------+---------------------------------------------------------+----------+-------------+----------------------------+----------------------------
    1 | Optimize LinkedIn Profile             | Optimize linkedIn profile to be Devops focused          | high     | in_progress | 2026-07-07 09:28:09.667195 | 2026-07-07 09:28:09.667198
    2 | Gather Capstone Project Evidence      | Get logs                                               +| high     | in_progress | 2026-07-07 09:29:00.487084 | 2026-07-07 09:29:00.487087
      |                                       | Get Images                                              |          |             |                            |
    3 | Submit Capstone Project               |                                                         | high     | todo        | 2026-07-07 09:29:19.718862 | 2026-07-07 09:29:19.718865
    4 | Add Monitoring to Capstone Project    | Add graphana & Prometheus                               | medium   | todo        | 2026-07-07 09:29:59.785392 | 2026-07-07 09:29:59.785395
    (4 rows)

    ubuntu@ip-10-0-1-251:~$
    ```

- `zero-downtime.log` — unbroken 200s during a rollout
    ```log
    🚀 Starting rollout at 2026-07-07 13:07:11
    deployment.apps/backend restarted
    ⏳ Waiting 2 seconds...
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    📊 Running 20 health checks...

    [13:07:14] ✅ HTTP 200 (326ms)
    [13:07:15] ✅ HTTP 200 (139ms)
    [13:07:22] ✅ HTTP 200 (6326ms)
    [13:07:22] ✅ HTTP 200 (143ms)
    [13:07:23] ✅ HTTP 200 (101ms)
    [13:07:24] ✅ HTTP 200 (78ms)
    [13:07:24] ✅ HTTP 200 (70ms)
    [13:07:25] ✅ HTTP 200 (118ms)
    [13:07:25] ✅ HTTP 200 (105ms)
    [13:07:26] ✅ HTTP 200 (114ms)
    [13:07:27] ✅ HTTP 200 (90ms)
    [13:07:27] ✅ HTTP 200 (77ms)
    [13:07:32] ✅ HTTP 200 (4312ms)
    [13:07:33] ✅ HTTP 200 (208ms)
    [13:07:33] ✅ HTTP 200 (90ms)
    [13:07:34] ✅ HTTP 200 (93ms)
    [13:07:35] ✅ HTTP 200 (92ms)
    [13:07:35] ✅ HTTP 200 (210ms)
    [13:07:36] ✅ HTTP 200 (84ms)
    [13:07:37] ✅ HTTP 200 (107ms)

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ✅ ALL 20 CHECKS PASSED - Zero downtime achieved!
    🏁 Completed at 2026-07-07 13:07:37
    ```

- `argocd-synced.png` — Argo CD Synced + Healthy

    **Command**
    > kubectl get application taskapp-dev -n argocd -o custom-columns=NAME:.metadata.name,REPO:.spec.source.repoURL,SYNC_STATUS:.status.sync.status,HEALTH_STATUS:.status.health.status,REVISION:.status.sync.revision

    **Output**
    ```log
    NAME          REPO                                                  SYNC_STATUS   HEALTH_STATUS   REVISION
    taskapp-dev   https://github.com/B-Nockk/tsa-capstone-phoenix.git   Synced        Healthy         644a467926aaea193bed44cd67efafe405901f0d
    ```

- `failover.png` — app up after a node drain

---

## ADVANCED

---


- `hpa-scale.png` — replicas climbing under load
    ```log
    ubuntu@ip-10-0-1-251:~$ ./hey -c 50 -z 5m https://nockk-tsa-capstone.duckdns.org/api/health
    ^C
    Summary:
    Total:        137.4000 secs
    Slowest:      1.2761 secs
    Fastest:      0.0032 secs
    Average:      0.1330 secs
    Requests/sec: 375.6477

    Total data:   4387190 bytes
    Size/request: 85 bytes

    Response time histogram:
    0.003 [1]     |
    0.131 [27258] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
    0.258 [18418] |■■■■■■■■■■■■■■■■■■■■■■■■■■■
    0.385 [5352]  |■■■■■■■■
    0.512 [229]   |
    0.640 [85]    |
    0.767 [104]   |
    0.894 [87]    |
    1.022 [38]    |
    1.149 [20]    |
    1.276 [22]    |


    Latency distribution:
    10%% in 0.0073 secs
    25%% in 0.0327 secs
    50%% in 0.1186 secs
    75%% in 0.2095 secs
    90%% in 0.2626 secs
    95%% in 0.2789 secs
    99%% in 0.4137 secs

    Details (average, fastest, slowest):
    DNS+dialup:   0.0002 secs, 0.0000 secs, 0.2579 secs
    DNS-lookup:   0.0002 secs, 0.0000 secs, 0.2683 secs
    req write:    0.0000 secs, 0.0000 secs, 0.1506 secs
    resp wait:    0.1325 secs, 0.0031 secs, 1.2760 secs
    resp read:    0.0002 secs, 0.0000 secs, 0.1302 secs

    Status code distribution:
    [200] 51614 responses

    ubuntu@ip-10-0-1-251:~$
    ```

- `security context.png` - security hardening

    ```log
    creationTimestamp: "2026-07-07T09:08:09Z"
    generation: 17
    labels:
        app.kubernetes.io/instance: taskapp-dev
    name: backend
    namespace: taskapp-dev
    resourceVersion: "38192"
    uid: 85488cc4-992e-4193-a7e5-48992fd8c38c
    spec:
    progressDeadlineSeconds: 600
    replicas: 2
    revisionHistoryLimit: 10
    selector:
        matchLabels:
        app: backend
    --
            securityContext:
            allowPrivilegeEscalation: false
            capabilities:
                drop:
                - ALL
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
        dnsPolicy: ClusterFirst
        restartPolicy: Always
        schedulerName: default-scheduler
        securityContext:
            runAsGroup: 10001
            runAsNonRoot: true
            runAsUser: 10001
            seccompProfile:
            type: RuntimeDefault
        terminationGracePeriodSeconds: 30
        topologySpreadConstraints:
        - labelSelector:
            matchLabels:
                app: backend
            maxSkew: 1
            topologyKey: kubernetes.io/hostname
            whenUnsatisfiable: DoNotSchedule
    status:
    availableReplicas: 2
    ```

- `network policy.png` - network policy
    ```log
    ubuntu@ip-10-0-1-251:~$ echo "🌐 ACTIVE NETWORK POLICY RULES" && echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && kubectl describe networkpolicy -n taskapp-dev
    🌐 ACTIVE NETWORK POLICY RULES
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Name:         default-deny-ingress
    Namespace:    taskapp-dev
    Labels:       app.kubernetes.io/instance=taskapp-dev
    Spec:
    PodSelector:     <none> (Allowing the specific traffic to all pods in this namespace)
    Allowing ingress traffic:
        <none> (Selected pods are isolated for ingress connectivity)
    Not affecting egress traffic
    Policy Types: Ingress

    Name:         allow-backend-to-postgres
    Namespace:    taskapp-dev
    Labels:       app.kubernetes.io/instance=taskapp-dev
    Spec:
    PodSelector:     app=postgres
    Allowing ingress traffic:
        To Port: 5432/TCP
        From:
        PodSelector: app=backend
    Not affecting egress traffic
    Policy Types: Ingress

    Name:         allow-frontend-to-backend
    Namespace:    taskapp-dev
    Labels:       app.kubernetes.io/instance=taskapp-dev
    Spec:
    PodSelector:     app=backend
    Allowing ingress traffic:
        To Port: 5000/TCP
        From:
        PodSelector: app=frontend
    Not affecting egress traffic
    Policy Types: Ingress

    Name:         allow-ingress-to-frontend
    Namespace:    taskapp-dev
    Labels:       app.kubernetes.io/instance=taskapp-dev
    Spec:
    PodSelector:     app=frontend
    Allowing ingress traffic:
        To Port: 8000/TCP
        From:
        NamespaceSelector: kubernetes.io/metadata.name=ingress-nginx
    Not affecting egress traffic
    Policy Types: Ingress
    ```

- `pod-disruption-budget.png` - pod disruption budget

    ```log
    ubuntu@ip-10-0-1-251:~$ eecho "🛡️ POD DISRUPTION BUDGETS" && echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" && kubectl get pdb -n taskapp-dev && echo -e "\n📋 PDB DETAILS:" && echo "----------------------------------------" && kubectl get pdb -n taskapp-dev -o yaml | grep -E "name:|minAvailable:|maxUnavailable:|matchLabels:"
    🛡️ POD DISRUPTION BUDGETS
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    NAME           MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
    backend-pdb    1               N/A               1                     25h
    postgres-pdb   1               N/A               0                     25h
    frontend-pdb   1               N/A               1                     25h

    📋 PDB DETAILS:
    ----------------------------------------
        name: backend-pdb
        minAvailable: 1
        matchLabels:
        name: postgres-pdb
        minAvailable: 1
        matchLabels:
        name: frontend-pdb
        minAvailable: 1
        matchLabels:
    ```

- `storageclass.png` - storage class
