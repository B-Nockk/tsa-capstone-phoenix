# EVIDENCE

Drop screenshots/logs here, named so a grader knows what each proves:

- `nodes-ready.png` — multi-node `kubectl get nodes`
```log
NAME            STATUS   ROLES                  AGE   VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
ip-10-0-2-21    Ready    <none>                 20h   v1.28.8+k3s1   10.0.2.21     <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
ip-10-0-1-212   Ready    <none>                 20h   v1.28.8+k3s1   10.0.1.212    <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
ip-10-0-1-14    Ready    control-plane,master   20h   v1.28.8+k3s1   10.0.1.14     <none>        Ubuntu 22.04.5 LTS   6.8.0-1060-aws   containerd://1.7.11-k3s2
```

- `pods-spread.png` — replicas on different nodes (`-o wide`)
```log
NAME                                   READY   STATUS      RESTARTS        AGE     IP               NODE            NOMINATED NODE   READINESS GATES
backend-6fd5cbdb4b-zg55c               1/1     Running     2 (15h ago)     17h     192.168.222.82   ip-10-0-1-212   <none>           <none>
taskapp-dev-db-backup-29721720-mlff6   0/1     Completed   0               11h     <none>           ip-10-0-1-14    <none>           <none>
cm-acme-http-solver-b22xs              1/1     Running     1 (6m21s ago)   3h30m   192.168.71.243   ip-10-0-1-14    <none>           <none>
frontend-7897487fb7-tdgf5              1/1     Running     7 (6m21s ago)   20h     192.168.71.244   ip-10-0-1-14    <none>           <none>
postgres-0                             1/1     Running     0               20h     192.168.161.76   ip-10-0-2-21    <none>           <none>
frontend-7897487fb7-kjdtl              1/1     Running     0               20h     192.168.161.77   ip-10-0-2-21    <none>           <none>
backend-6fd5cbdb4b-vvsbw               1/1     Running     0               17h     192.168.161.78   ip-10-0-2-21    <none>           <none>
```

- `tls-valid.png` — valid cert (curl -vI / SSL Labs)
- `pvc-persist.log` — data survives a Pod kill
- `zero-downtime.log` — unbroken 200s during a rollout
- `hpa-scale.png` — replicas climbing under load
- `argocd-synced.png` — Argo CD Synced + Healthy
- `failover.png` — app up after a node drain
