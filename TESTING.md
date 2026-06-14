# Testing Guide

## Automated Validation

### Verify prerequisites
```bash
command -v minikube && command -v kubectl && command -v helm && echo "All tools installed"
```

### Verify cluster health
```bash
minikube status -p falco-demo
kubectl get nodes
kubectl get pods -n falco-system
kubectl get pods -n falco-demo
```

### Verify Falco is running
```bash
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=5
```

### Verify custom rules are loaded
```bash
kubectl logs -n falco-system -l app.kubernetes.io/name=falco | grep "Arena Pod"
```

## Manual Testing — Attack Scenarios

### 1. Shell in container
```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "whoami"
# Expected Falco alert: "A shell was spawned in a container"
```

### 2. Read sensitive file
```bash
kubectl exec -n falco-demo deploy/rogue-player -- cat /etc/shadow
# Expected Falco alert: "Sensitive file opened for reading"
```

### 3. Write below binary dir
```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "echo test > /usr/bin/backdoor"
# Expected Falco alert: "Write below binary dir"
```

### 4. Package management
```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "apt-get --version"
# Expected Falco alert: "Package management process launched in container"
```

### 5. Kubernetes credential access
```bash
kubectl exec -n falco-demo deploy/rogue-player -- cat /var/run/secrets/kubernetes.io/serviceaccount/token
# Expected Falco alert: "K8s credential access detected in arena pod" (custom rule)
```

### 6. Outbound connection
```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',443)); s.close()"
# Expected Falco alert: "Outbound connection from arena pod" (custom rule)
```

## Verify Alert Dashboard
```bash
kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo &
curl -s http://localhost:9082/alerts/summary | python3 -m json.tool
```

## Full End-to-End Test
```bash
./scripts/01-install-prerequisites.sh
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
./scripts/04-demo-scenarios.sh
./scripts/05-teardown.sh
```
