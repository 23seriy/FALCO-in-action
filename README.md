# 🛡️ Falco in Action

A hands-on project demonstrating **Falco** — runtime security for Kubernetes powered by eBPF. Built around an NBA scenario: the cluster is the arena, Falco is the security camera system, and the rogue-player pod is an intruder you catch in real-time.

While [Kyverno](https://github.com/23seriy/kyverno-in-action) stops bad pods at the door (admission control), Falco catches threats once they're inside — shell access, credential theft, crypto mining, and more — by monitoring Linux kernel syscalls.

![Falco](https://img.shields.io/badge/Falco-0.40+-00AEC7?logo=falco&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes&logoColor=white)
![Minikube](https://img.shields.io/badge/Minikube-local-F7B93E?logo=kubernetes&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![eBPF](https://img.shields.io/badge/eBPF-kernel-FF6600?logoColor=white)

> 📝 **Read the full walkthrough on Medium:** *(link to be added after publishing)*

## 📖 Documentation

- **[CLAUDE.md](CLAUDE.md)** — Architecture, file structure, and common development tasks
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — How to contribute (features, fixes, docs)
- **[TESTING.md](TESTING.md)** — Manual and automated testing procedures
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Common issues and solutions
- **[SECURITY.md](SECURITY.md)** — Security policies and responsible disclosure
- **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)** — Community guidelines

## 🏗️ Architecture

```text
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │                                                  │
 User ────────►  │  arena-security-api     rogue-player             │
 localhost:9080 │  (compliant, non-root)   (attacker, root)        │
                 │       │                      │                   │
                 │       │ normal behavior      │ 🔴 attacks        │
                 │       │ (no alerts)          │ (triggers Falco)  │
                 │       │                      │                   │
                 │       └──────────┬───────────┘                   │
                 │                  │ kernel syscalls                │
                 │                  ▼                                │
                 │         Falco (eBPF driver)                      │
                 │         watches ALL containers                   │
                 │                  │                                │
                 │                  ▼                                │
                 │         Falcosidekick                             │
                 │         ┌────────┴────────┐                      │
                 │         ▼                 ▼                      │
                 │    alert-dashboard   Falcosidekick UI            │
                 │    (webhook recv)   (built-in web UI)            │
                 └──────────────────────────────────────────────────┘
```

**arena-security-api** — Compliant NBA arena security service. Runs as non-root, read-only filesystem, drops all capabilities. The "good citizen" that never triggers Falco.

**rogue-player** — Intentionally malicious pod with HTTP endpoints that trigger specific attacks on demand. Runs as root. Each endpoint maps to a Falco rule.

**alert-dashboard** — Custom webhook receiver that stores and displays Falco alerts forwarded by Falcosidekick. The arena's security operations center (SOC).

**Falco** — eBPF-based runtime security. Monitors kernel syscalls across all containers. Detects shells, file reads, network connections, and more.

**Falcosidekick** — Alert router. Receives Falco events and forwards them to the alert-dashboard webhook and its own built-in UI.

## 📋 What You'll Learn

| Falco Feature | What It Does | Demo Scenario |
|---|---|---|
| **Shell Detection** | Catch interactive shells in containers | `kubectl exec` into rogue-player |
| **Sensitive File Monitoring** | Alert on reads of `/etc/shadow`, SSH keys | rogue-player reads `/etc/shadow` |
| **Binary Dir Protection** | Detect writes to `/usr/bin`, `/usr/sbin` | rogue-player plants a backdoor |
| **Package Management Detection** | Alert on `apt-get`, `apk` in containers | rogue-player runs a package manager |
| **K8s Credential Theft** | Detect ServiceAccount token reads | rogue-player reads the SA token |
| **Outbound Connection Monitoring** | Catch connections to external IPs | rogue-player connects to 1.1.1.1 |
| **Crypto Mining Detection** | Alert on mining pool port connections | rogue-player connects to port 45700 |
| **Custom Rule Authoring** | Write rules for your environment | 5 custom rules in `falco/custom-rules.yaml` |
| **Alert Routing** | Forward alerts to webhooks, UI, Slack | Falcosidekick → alert-dashboard |
| **eBPF Driver** | Kernel-level monitoring without modules | Modern eBPF driver, no kernel headers needed |

## 🚀 Quick Start

### Step 0: Clone the Repository

```bash
git clone https://github.com/23seriy/falco-in-action.git
cd falco-in-action
```

### Prerequisites

- **macOS** (scripts use Homebrew; adapt for Linux)
- **Docker Desktop** running
- ~8 GB RAM available for Minikube (Falco + eBPF + demo apps)

### Step 1: Install Tools

```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
```

Installs `minikube`, `kubectl`, `helm`, and `docker` via Homebrew.

### Step 2: Start Cluster + Install Falco

```bash
./scripts/02-start-cluster.sh
```

Creates the `falco-demo` Minikube profile on **Kubernetes v1.32.0** with the **containerd** runtime, installs Falco with the **modern eBPF driver**, and installs Falcosidekick for alert routing.

### Step 3: Build & Deploy

```bash
./scripts/03-deploy-app.sh
```

Builds Docker images inside Minikube's Docker daemon, loads custom Falco rules, and deploys all three demo apps.

### Step 4: Access the Apps

```bash
# Terminal 1: Arena Security API (compliant app)
kubectl port-forward svc/arena-security-api 9080:8080 -n falco-demo

# Terminal 2: Rogue Player (attacker pod)
kubectl port-forward svc/rogue-player 9081:8080 -n falco-demo

# Terminal 3: Alert Dashboard (SOC)
kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo

# Terminal 4: Watch Falco logs live
kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f
```

Try it:

```bash
# Normal behavior — no alerts
curl http://localhost:9080/security/status

# Trigger attacks — watch Falco fire
curl http://localhost:9081/attack/shell
curl http://localhost:9081/attack/sensitive
curl http://localhost:9081/attack/credentials

# Check what Falco caught
curl http://localhost:9082/alerts/summary
```

### Step 5: Run the Demo Scenarios

```bash
./scripts/04-demo-scenarios.sh
```

Ten interactive scenarios, one attack at a time.

## 🎮 Demo Scenarios

### 1. Baseline — The Good Citizen

No attacks. The compliant arena-security-api handles requests normally. No Falco alerts. This is what "secure by default" looks like.

### 2. 🐚 Shell in Container — Breaking Into the Arena

```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "whoami"
```

Falco detects: **"A shell was spawned in a container"**. The most basic and most common attack vector. NBA analogy: a fan jumping the barrier and running onto the court.

### 3. 📄 Read Sensitive File — Raiding the Locker Room

```bash
kubectl exec -n falco-demo deploy/rogue-player -- cat /etc/shadow
```

Falco detects: **"Sensitive file opened for reading"**. Attackers harvest password hashes or SSH keys for lateral movement.

### 4. 💀 Write Below Binary Dir — Planting a Backdoor

```bash
kubectl exec -n falco-demo deploy/rogue-player -- \
  /bin/sh -c "echo '#!/bin/sh' > /usr/bin/backdoor"
```

Falco detects: **"Write below binary dir"**. Classic persistence technique — drop a backdoor that survives container restarts.

### 5. 📦 Package Management — Installing Attack Tools

```bash
kubectl exec -n falco-demo deploy/rogue-player -- apt-get --version
```

Falco detects: **"Package management process launched in container"**. Containers should be immutable — packages belong in the image, not at runtime.

### 6. 🔑 K8s Credential Theft — Stealing the Playbook

```bash
kubectl exec -n falco-demo deploy/rogue-player -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

Custom rule fires: **"K8s credential access detected in arena pod"**. The first thing attackers do after getting a shell: read the SA token to pivot within the cluster.

### 7. 🌐 Outbound Connection — Sneaking Out the Back Door

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',443))"
```

Custom rule fires: **"Outbound connection from arena pod"**. Catches data exfiltration and C2 callbacks.

### 8. ⛏️ Crypto Mining — Using the Arena's Power Grid

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',45700))"
```

Custom rule fires: **"Possible crypto mining detected in arena pod"**. Connections to known mining pool ports (3333, 4444, 45700).

### 9. 📊 Alert Dashboard — The Security Operations Center

Check what accumulated in the alert-dashboard:

```bash
curl http://localhost:9082/alerts/summary
curl http://localhost:9082/alerts/critical
```

Also open the Falcosidekick UI:

```bash
kubectl port-forward svc/falcosidekick-ui 2802:2802 -n falco-system
# Open http://localhost:2802
```

### 10. 📋 Full Audit — The Post-Game Security Report

Review all Falco alerts from the demo:

```bash
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=500 | \
  grep -oP '"rule":"[^"]*"' | sort | uniq -c | sort -rn
```

## 🔧 Useful Commands

```bash
# Falco status
kubectl get pods -n falco-system
kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f

# Falcosidekick status
kubectl logs -n falco-system -l app.kubernetes.io/name=falcosidekick

# Demo pods
kubectl get pods -n falco-demo

# Trigger attacks via HTTP (alternative to kubectl exec)
curl http://localhost:9081/attack/shell
curl http://localhost:9081/attack/sensitive
curl http://localhost:9081/attack/network
curl http://localhost:9081/attack/writeback
curl http://localhost:9081/attack/package
curl http://localhost:9081/attack/credentials
curl http://localhost:9081/attack/crypto
curl http://localhost:9081/attack/dns

# Check alert dashboard
curl http://localhost:9082/alerts
curl http://localhost:9082/alerts/summary
curl http://localhost:9082/alerts/critical

# Falcosidekick UI
kubectl port-forward svc/falcosidekick-ui 2802:2802 -n falco-system
```

## 📁 Project Structure

```text
falco-in-action/
├── apps/
│   ├── arena-security-api/       # Compliant NBA arena security service
│   │   ├── app.py                # Flask app — security zones, incidents, status
│   │   ├── Dockerfile            # Multi-stage, runs as UID 10001
│   │   └── requirements.txt
│   ├── rogue-player/             # Attack simulation pod (runs as root)
│   │   ├── app.py                # HTTP endpoints that trigger Falco rules
│   │   ├── Dockerfile            # Single-stage, runs as root (intentional)
│   │   └── requirements.txt
│   └── alert-dashboard/          # Falcosidekick webhook receiver
│       ├── app.py                # Stores and displays forwarded alerts
│       ├── Dockerfile            # Multi-stage, runs as UID 10001
│       └── requirements.txt
├── k8s/                          # Kubernetes manifests
│   ├── namespace.yaml            # falco-demo
│   ├── arena-security-api.yaml   # Compliant Deployment + Service
│   ├── rogue-player.yaml         # Attacker Deployment + Service (no securityContext)
│   └── alert-dashboard.yaml      # SOC Deployment + Service
├── falco/                        # Falco configuration
│   ├── custom-rules.yaml         # 5 custom detection rules (NBA-themed)
│   ├── falco-values.yaml         # Falco Helm values (eBPF driver)
│   └── falcosidekick-values.yaml # Falcosidekick Helm values (webhook + UI)
├── scripts/                      # Automation scripts
│   ├── 01-install-prerequisites.sh
│   ├── 02-start-cluster.sh       # Minikube + Falco + Falcosidekick
│   ├── 03-deploy-app.sh          # Build images + deploy apps + load rules
│   ├── 04-demo-scenarios.sh      # 10 interactive attack scenarios
│   └── 05-teardown.sh
├── docs/
│   └── medium-story.md           # Full Medium article draft
├── CLAUDE.md                     # Developer guide
├── CONTRIBUTING.md               # How to contribute
├── TESTING.md                    # Testing procedures
├── TROUBLESHOOTING.md            # Debug guide
├── SECURITY.md                   # Security policy
├── CODE_OF_CONDUCT.md            # Community standards
├── LICENSE                       # MIT
└── .gitignore
```

## 🧹 Teardown

```bash
./scripts/05-teardown.sh
```

Deletes all demo resources, uninstalls Falco and Falcosidekick, and removes the Minikube cluster.

## 💡 Key Takeaways

1. **Admission control isn't enough.** A perfectly compliant pod can still be compromised at runtime. Falco watches what containers actually *do*, not just how they're configured.

2. **eBPF is the enabler.** Falco's modern eBPF driver monitors kernel syscalls without kernel modules, sidecars, or code changes. Zero instrumentation of your apps.

3. **Custom rules close the gap.** Default rules cover 80% of threats. Write custom rules for your environment: unexpected outbound connections, credential access patterns, mining indicators.

4. **Alert routing makes it actionable.** Falcosidekick routes alerts to Slack, PagerDuty, SIEM, or custom webhooks. Detection without notification is just logging.

5. **Defense in depth is not optional.** Kyverno at admission + Falco at runtime = no blind spots. Layer your defenses like an NBA arena layers its security: ID checks at the door, cameras inside, and a SOC watching the feeds.

## 📚 Resources

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [Falco Built-in Rules](https://github.com/falcosecurity/rules)
- [Falcosidekick](https://github.com/falcosecurity/falcosidekick)
- [Falcosidekick UI](https://github.com/falcosecurity/falcosidekick-ui)
- [eBPF.io — What is eBPF?](https://ebpf.io/)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

## 📝 License

MIT — Use freely for learning, demos, and presentations.
