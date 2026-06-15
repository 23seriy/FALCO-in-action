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
├── k8s/                        # Kubernetes manifests + NetworkPolicy
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
minikube image build -t rogue-player:v1 apps/rogue-player -p falco-demo
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
6. **MITRE ATT&CK mapping** — Every custom rule tagged with technique IDs (T1041, T1496, etc.).
7. **automountServiceAccountToken: false** — Compliant pods don't mount the SA token (best practice).
8. **NetworkPolicy default-deny** — Ingress locked down per pod, rogue-player intentionally open for demo.

## LLM Coding Guidelines (Karpathy-Inspired)

Behavioral guidelines to reduce common LLM coding mistakes.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
