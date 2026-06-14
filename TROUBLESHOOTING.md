# Troubleshooting

## Common Issues

### Falco pods stuck in CrashLoopBackOff

**Symptom:** Falco pods restart continuously.

**Cause:** eBPF driver compatibility issue with the Minikube kernel.

**Fix:**
```bash
# Check Falco logs for the specific error
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --previous

# If eBPF probe loading fails, try recreating the cluster
minikube delete -p falco-demo
./scripts/02-start-cluster.sh
```

### No Falco alerts appearing

**Symptom:** Attacks fire but no alerts in Falco logs.

**Cause:** Falco may still be loading rules, or the rule conditions don't match.

**Debug:**
```bash
# Verify Falco is running and rules are loaded
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | head -30

# Check for rule loading errors
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep -i "error\|invalid\|failed"

# Verify custom rules ConfigMap exists
kubectl get configmap -n falco-system | grep custom
```

### Alert dashboard not receiving alerts

**Symptom:** Attacks trigger Falco alerts but the dashboard shows zero alerts.

**Cause:** Falcosidekick not routing to the webhook.

**Debug:**
```bash
# Check Falcosidekick logs
kubectl logs -n falco-system -l app.kubernetes.io/name=falcosidekick

# Verify the webhook URL is correct
kubectl get configmap -n falco-system -o yaml | grep webhook

# Test direct connectivity from Falcosidekick to alert-dashboard
kubectl exec -n falco-system deploy/falcosidekick -- wget -qO- http://alert-dashboard.falco-demo.svc.cluster.local:8080/health 2>/dev/null
```

### Minikube out of memory

**Symptom:** Pods evicted or stuck in Pending.

**Cause:** Falco + Falcosidekick + demo apps need ~8 GB.

**Fix:**
```bash
minikube delete -p falco-demo
# Edit 02-start-cluster.sh to increase MEMORY
./scripts/02-start-cluster.sh
```

### Docker images not found (ImagePullBackOff)

**Symptom:** Pods show `ErrImagePull` or `ImagePullBackOff`.

**Cause:** Docker daemon not pointed at Minikube.

**Fix:**
```bash
# Re-point Docker at Minikube
eval $(minikube docker-env -p falco-demo)

# Rebuild images
docker build -t arena-security-api:v1 apps/arena-security-api
docker build -t rogue-player:v1 apps/rogue-player
docker build -t alert-dashboard:v1 apps/alert-dashboard

# Restart deployments
kubectl rollout restart deployment -n falco-demo
```

### Permission denied on scripts

**Fix:**
```bash
chmod +x scripts/*.sh
```

## Useful Debug Commands

```bash
# Full cluster overview
kubectl get all -n falco-demo
kubectl get all -n falco-system

# Falco detailed status
kubectl describe daemonset falco -n falco-system

# Pod events
kubectl get events -n falco-demo --sort-by=.metadata.creationTimestamp
kubectl get events -n falco-system --sort-by=.metadata.creationTimestamp

# Falco configuration
kubectl get configmap -n falco-system -o yaml | less
```
