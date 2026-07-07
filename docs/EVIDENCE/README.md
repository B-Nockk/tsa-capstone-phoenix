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
- `zero-downtime.log` — unbroken 200s during a rollout
- `hpa-scale.png` — replicas climbing under load
- `argocd-synced.png` — Argo CD Synced + Healthy
- `failover.png` — app up after a node drain
