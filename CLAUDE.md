# Falco in Action — Developer Guide

## Project Overview

A hands-on Kubernetes runtime security demo using Falco. NBA-themed: the cluster is the arena, Falco is the security camera system, the rogue-player pod is an intruder.

## Architecture

- **arena-security-api** — Compliant Flask app (non-root, read-only FS, drops caps). The "good citizen."
- **rogue-player** — Intentionally insecure Flask app that runs as root. HTTP endpoints trigger specific attacks on demand.
- **alert-dashboard** — Webhook receiver for Falcosidekick. Stores and displays Falco alerts.
- **Falco** — Installed in `falco-system` namespace with modern eBPF driver. Watches syscalls cluster-wide.
- **Falcosidekick** — Routes Falco alerts to the alert-dashboard webhook and provides a built-in UI.

## File Structure

```
falco-in-action/
├── apps/
│   ├── arena-security-api/     # Compliant NBA arena security service
│   ├── rogue-player/           # Attack simulation pod (runs as root)
│   └── alert-dashboard/        # Falcosidekick webhook receiver
├── k8s/                        # Kubernetes manifests
├── falco/                      # Falco custom rules and Helm values
├── scripts/                    # Numbered automation scripts
├── docs/                       # Medium article and extra documentation
└── README.md
```

## Common Tasks

### Run the demo
```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
./scripts/04-demo-scenarios.sh
```

### Watch Falco logs live
```bash
kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f
```

### Trigger individual attacks
```bash
# From a port-forward to rogue-player on :9081
curl http://localhost:9081/attack/shell
curl http://localhost:9081/attack/sensitive
curl http://localhost:9081/attack/network
curl http://localhost:9081/attack/writeback
curl http://localhost:9081/attack/package
curl http://localhost:9081/attack/credentials
curl http://localhost:9081/attack/crypto
curl http://localhost:9081/attack/dns
```

### Check alert dashboard
```bash
kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo
curl http://localhost:9082/alerts
curl http://localhost:9082/alerts/summary
```

### Rebuild images after code changes
```bash
eval $(minikube docker-env -p falco-demo)
docker build -t rogue-player:v1 apps/rogue-player
kubectl rollout restart deployment/rogue-player -n falco-demo
```

### Clean up
```bash
./scripts/05-teardown.sh
```

## Key Design Decisions

1. **Modern eBPF driver** — No kernel headers needed, works on Docker Desktop + Minikube.
2. **HTTP attack endpoints** — Each attack is curl-able, making the demo interactive and reproducible.
3. **Falcosidekick + custom webhook** — Shows real-world alert routing (not just logs).
4. **Custom rules in falco/custom-rules.yaml** — Loaded via Helm `--set-file` to demonstrate rule authoring.
5. **NBA theme consistency** — Same pattern as other *-in-action projects.
