# Your Kubernetes Cluster Got Hacked. Kyverno Didn't Stop It. Here's What Would Have.

> *Runtime security is the last line of defense you're probably not running. This is a hands-on guide to deploying Falco — the CNCF's eBPF-powered threat detection engine — with a working demo you can run on your laptop in 5 minutes.*

<!-- 
MEDIUM PUBLISHING NOTES:
- Subtitle: "A hands-on guide to Falco, eBPF, and runtime security for Kubernetes — with 7 real attack scenarios you can run yourself"
- Tags: kubernetes, security, devops, cloud-native, ebpf
- Canonical URL: https://github.com/23seriy/FALCO-in-action
- Reading time: ~12 min
- Featured image: architecture diagram (see placeholder below)
-->

---

## The $10 Million Blind Spot

In January 2024, a [cryptojacking campaign hit Kubernetes clusters across multiple cloud providers](https://sysdig.com/blog/scarleteel-2-0/). The attackers didn't need to bypass any admission controllers. They exploited a known vulnerability in a web application, got a shell inside a legitimate container, read the Kubernetes service account token, and pivoted to steal AWS credentials — all within a pod that had passed every policy check.

The cost? Hundreds of thousands in stolen compute for mining Monero. And most victims didn't know it was happening until their cloud bill arrived.

**The attack followed a textbook pattern:**

1. ✅ Pod passed all admission policies (correct labels, non-root, signed image)
2. 💀 Attacker exploited an RCE vulnerability in the running app
3. 🐚 Attacker spawned a shell inside the container
4. 🔑 Attacker read the ServiceAccount token at `/var/run/secrets/kubernetes.io/serviceaccount/token`
5. 🌐 Attacker connected outbound to a C2 server
6. ⛏️ Attacker deployed a crypto miner on the cluster's compute

Steps 3–6 happened *inside a running container* — completely invisible to admission control tools like Kyverno, OPA Gatekeeper, or Kubernetes PSA.

If you've read my [Kyverno in Action](https://medium.com/@sergeiolshanetski/kyverno-in-action-policy-as-code-admission-control-for-kubernetes-from-free-for-all-to-17e41becf176) article, you know how to lock down step 1. But what about steps 3–6?

You need **runtime security**. And the tool the industry has converged on is **Falco**.

---

## What is Falco? (30-Second Version)

[Falco](https://falco.org/) is a **CNCF graduated project** — same maturity level as Kubernetes, Prometheus, and Envoy. It uses **eBPF** to monitor Linux kernel syscalls in real-time across every container on every node.

When a container does something suspicious — opens `/etc/shadow`, spawns a shell, connects to a mining pool — Falco detects it *at the kernel level* and fires an alert in milliseconds.

> **Kyverno** = the bouncer at the arena door (checks IDs before you enter)
> **Falco** = the security camera system inside the arena (watches what you do once you're in)

You need both. A bouncer stops the guy without a ticket. But the security cameras catch the fan who snuck in through the loading dock and is now running across the court.

<!-- 📸 IMAGE PLACEHOLDER: Insert Kyverno-vs-Falco comparison diagram here -->

---

## The Demo: NBA Arena Security

I built a full working demo that simulates this exact attack chain. Following my [*-in-action series*](https://medium.com/@sergeiolshanetski) pattern, it uses an NBA arena as the analogy:

| Component | NBA Analogy | What It Does |
|---|---|---|
| **arena-security-api** | The arena's security ops center | Compliant, hardened pod — the "good citizen" |
| **rogue-player** | An intruder on the court | Attack simulation pod with HTTP-triggered exploits |
| **alert-dashboard** | The big board in the SOC | Receives and displays Falco alerts in real-time |
| **Falco** | Security camera system | eBPF-based kernel-level monitoring |
| **Falcosidekick** | The alarm routing system | Routes alerts to webhooks, Slack, PagerDuty, etc. |

<!-- 📸 IMAGE PLACEHOLDER: Architecture diagram -->

```
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │                                                  │
 User ────────►  │  arena-security-api     rogue-player             │
                 │  (compliant, non-root)   (attacker, root)        │
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

Everything runs locally on Minikube. No cloud account needed.

---

## Setup (5 Minutes, Really)

```bash
git clone https://github.com/23seriy/FALCO-in-action.git
cd FALCO-in-action
chmod +x scripts/*.sh

./scripts/01-install-prerequisites.sh   # minikube, kubectl, helm
./scripts/02-start-cluster.sh           # minikube + Falco + Falcosidekick
./scripts/03-deploy-app.sh              # build images + deploy demo apps
```

Or run all 10 scenarios interactively:

```bash
./scripts/04-demo-scenarios.sh
```

**Prerequisites:** macOS with Docker Desktop running, ~8 GB RAM available.

---

## 7 Attack Scenarios (With Real Falco Output)

Each scenario maps to a [MITRE ATT&CK](https://attack.mitre.org/matrices/enterprise/containers/) technique — the same framework your SOC team uses to classify real-world threats.

### 🐚 1. Shell in Container — T1609

**The attack:** Spawning an interactive shell inside a running container. In production, this happens when an attacker exploits an RCE vulnerability.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "whoami && id"
```

**Falco fires:**
```json
{
  "rule": "Terminal shell in container",
  "priority": "Warning",
  "output": "A shell was spawned in a container with an attached terminal
    (pod=rogue-player container=rogue-player shell=sh)"
}
```

**🏀 NBA analogy:** A fan jumping the barrier and running onto the court.

**Why it matters:** This is the most fundamental indicator of compromise. If someone has a shell in your production container, something has already gone very wrong.

---

### 📄 2. Read Sensitive File — T1552

**The attack:** Reading `/etc/shadow` to harvest password hashes for offline cracking.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- cat /etc/shadow
```

**Falco fires:**
```json
{
  "rule": "Read sensitive file untrusted",
  "priority": "Warning",
  "output": "Sensitive file opened for reading (file=/etc/shadow user=root pod=rogue-player)"
}
```

**🏀 NBA analogy:** Sneaking into the opponent's locker room to steal their playbook.

---

### 💀 3. Write Below Binary Dir — T1525

**The attack:** Dropping a backdoor binary into `/usr/bin` for persistence.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- \
  /bin/sh -c "echo '#!/bin/sh' > /usr/bin/backdoor && chmod +x /usr/bin/backdoor"
```

**🏀 NBA analogy:** Rigging the scoreboard with your own equipment.

---

### 📦 4. Package Management — T1105

**The attack:** Running `apt-get` inside a container — a red flag in production. Containers should be immutable.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- apt-get --version
```

**🏀 NBA analogy:** A player bringing outside equipment onto the court mid-game.

---

### 🔑 5. Kubernetes Credential Theft — T1552.007

**The attack:** The first thing attackers do after getting a shell — read the ServiceAccount token to pivot within the cluster.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

**Falco fires our custom rule:**
```json
{
  "rule": "Arena Pod Reading K8s Secrets",
  "priority": "Critical",
  "output": "K8s credential access detected in arena pod
    (pod=rogue-player file=/var/run/secrets/kubernetes.io/serviceaccount/token)"
}
```

**🏀 NBA analogy:** Stealing the coach's iPad with all the play diagrams.

**Why it matters:** With the SA token, an attacker can query the Kubernetes API, list secrets, and potentially take over the entire cluster. This is why best practice is `automountServiceAccountToken: false` on every pod that doesn't need it. (Our compliant `arena-security-api` pod does this.)

---

### 🌐 6. Outbound Connection — T1041

**The attack:** A compromised pod phoning home to a C2 server.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',443))"
```

**Falco fires our custom rule:**
```json
{
  "rule": "Arena Pod Making Outbound Connection",
  "priority": "Warning",
  "output": "Outbound connection from arena pod
    (pod=rogue-player dest=1.1.1.1:443)"
}
```

**🏀 NBA analogy:** A player sneaking out of the arena to meet their agent during the game.

---

### ⛏️ 7. Crypto Mining — T1496

**The attack:** Connecting to a mining pool — the #1 container attack in the wild.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',45700))"
```

**🏀 NBA analogy:** Using the arena's generator to power your Bitcoin rig hidden under the bleachers.

---

## Writing Custom Rules: Teaching Falco Your Arena's Layout

Falco ships with 100+ built-in rules. But every environment has unique threats. Writing custom rules is straightforward — and this is where Falco really shines.

Here's one of the 5 custom rules from this demo:

```yaml
# MITRE ATT&CK: T1041 (Exfiltration Over C2 Channel)
- rule: Arena Pod Making Outbound Connection
  desc: >
    Detect when a pod in the falco-demo namespace makes an outbound
    connection to an external IP address.
  condition: >
    evt.type in (connect, sendto) and
    evt.dir = < and
    container.id != host and
    k8s.ns.name = "falco-demo" and
    fd.typechar = 4 and
    not fd.snet in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "127.0.0.0/8")
  output: >
    Outbound connection from arena pod
    (pod=%k8s.pod.name connection=%fd.name dest=%fd.sip:%fd.sport user=%user.name)
  priority: WARNING
  tags: [T1041, network, nba-arena, mitre_exfiltration]
```

**The anatomy of a Falco rule:**

| Field | Purpose | Example |
|---|---|---|
| **condition** | Falco's filter language over syscall events | `evt.type = connect and k8s.ns.name = "prod"` |
| **output** | Template for the alert message | `%k8s.pod.name` is resolved at runtime |
| **priority** | Emergency → Debug — drives routing in Falcosidekick | `CRITICAL` pages the on-call |
| **tags** | MITRE ATT&CK IDs + your own categories | `[T1041, network]` |

**Pro tip:** Always tag rules with MITRE ATT&CK technique IDs. This gives your SOC team a common language and maps directly to their incident response playbooks.

---

## Alert Routing with Falcosidekick

Falco writes alerts to stdout. That's useful for `kubectl logs`, but useless for incident response. Enter **Falcosidekick** — it receives Falco events and routes them to **60+ outputs**:

- **Slack** → `#security-alerts` channel
- **PagerDuty** → on-call rotation for Critical alerts
- **AWS CloudWatch / S3** → audit trail
- **Elasticsearch / Splunk** → searchable alert history
- **Webhook** → your custom SOC dashboard (what this demo does)
- **Falcosidekick UI** → built-in web dashboard (included)

In this demo, after running all 7 attack scenarios:

```bash
curl http://localhost:9082/alerts/summary
```
```json
{
  "total_alerts": 15,
  "by_rule": {
    "Arena Pod Making Outbound Connection": 2,
    "Arena Pod Reading K8s Secrets": 1,
    "Arena Pod Suspicious DNS Lookup": 4,
    "Read sensitive file untrusted": 1
  },
  "by_priority": {
    "Critical": 8,
    "Warning": 3,
    "Notice": 4
  }
}
```

**Every alert routed automatically. Zero manual log parsing.**

---

## The MITRE ATT&CK Mapping

Every scenario in this demo maps to a real-world attack technique. This isn't academic — it's how your incident response team will classify and prioritize threats:

| Scenario | MITRE Technique | ID | Falco Rule | Priority |
|---|---|---|---|---|
| Shell in Container | Exec Into Container | T1609 | Terminal shell in container | Warning |
| Read Sensitive File | Unsecured Credentials | T1552 | Read sensitive file untrusted | Warning |
| Write Below Binary Dir | Implant Internal Image | T1525 | Write below binary dir | Error |
| Package Management | Ingress Tool Transfer | T1105 | Launch Package Management | Error |
| K8s Credential Theft | Container API Server | T1552.007 | Arena Pod Reading K8s Secrets | Critical |
| Outbound Connection | Exfiltration Over C2 | T1041 | Arena Pod Making Outbound Connection | Warning |
| Crypto Mining | Resource Hijacking | T1496 | Arena Pod Crypto Mining Activity | Critical |

---

## Kyverno + Falco: The Complete Defense

If you've followed my series, you know the punchline:

| Layer | Tool | When | What It Stops |
|---|---|---|---|
| **Admission** | Kyverno | Before pod starts | Bad *configuration* — missing labels, `:latest` tags, root containers |
| **Runtime** | Falco | While pod runs | Bad *behavior* — shell access, credential theft, crypto mining |

Kyverno prevents *known bad configurations*. Falco detects *unknown bad behavior*.

The attack chain from the opening story:

1. ✅ Pod passes all Kyverno policies → admitted to the cluster
2. 💀 Attacker exploits an RCE bug in the app
3. 🐚 Attacker spawns a shell → **Falco alerts** 🚨
4. 🔑 Attacker reads the SA token → **Falco alerts** 🚨
5. 🌐 Attacker connects to C2 → **Falco alerts** 🚨
6. ⛏️ Attacker deploys crypto miner → **Falco alerts** 🚨

**Without Falco, steps 3–6 happen in complete silence.** The first sign is your next cloud bill.

---

## Key Takeaways

1. **Admission control is necessary but insufficient.** The 2024 Kubernetes security report found that 89% of clusters had at least one container with a known vulnerability. Compliant pods get compromised at runtime. Falco watches what containers actually *do*.

2. **eBPF is the industry's bet.** Falco, Cilium, Datadog, and Tetragon all use eBPF for kernel-level observability. No kernel modules, no sidecars, no code changes. It's the future of infrastructure security.

3. **Custom rules are your competitive advantage.** Built-in rules cover generic threats. The 20% specific to *your* environment — unusual outbound connections, credential access patterns, mining indicators — that's where custom rules make the difference.

4. **Alert routing makes detection actionable.** Falcosidekick routes to 60+ outputs. Detection without notification is just expensive logging.

5. **Map everything to MITRE ATT&CK.** Tag your rules with technique IDs. Your SOC team speaks MITRE. Your incident response playbooks reference MITRE. Make Falco speak it too.

6. **Defense in depth is not optional.** Kyverno at the door. Falco inside. NetworkPolicies on the wire. Like an NBA arena: ID checks, security cameras, and a SOC watching the feeds.

---

## Try It Yourself

The entire project is open source and runs on your laptop:

```bash
git clone https://github.com/23seriy/FALCO-in-action.git
cd FALCO-in-action
./scripts/01-install-prerequisites.sh
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
./scripts/04-demo-scenarios.sh    # 10 interactive scenarios
```

⭐ Star the repo if you found this useful: [github.com/23seriy/FALCO-in-action](https://github.com/23seriy/FALCO-in-action)

---

## Resources

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [Falcosidekick — 60+ Alert Outputs](https://github.com/falcosecurity/falcosidekick)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [eBPF.io — What is eBPF?](https://ebpf.io/)
- [Sysdig 2024 Container Security Report](https://sysdig.com/2024-cloud-native-security-and-usage-report/)

---

*This is part of my **"in Action" series** — hands-on Kubernetes projects you can clone and run on your laptop. Each one takes a CNCF tool, wraps it in a practical demo, and explains it through an NBA analogy because security shouldn't be boring.*

*More in the series:*
- *[Kyverno in Action](https://medium.com/@sergeiolshanetski/kyverno-in-action-policy-as-code-admission-control-for-kubernetes-from-free-for-all-to-17e41becf176) — Admission control & policy-as-code*
- *[Cilium in Action](https://medium.com/@sergeiolshanetski/cilium-in-action) — eBPF networking, L7 policies, Hubble observability*
- *[Crossplane in Action](https://medium.com/@sergeiolshanetski/crossplane-in-action) — Kubernetes-native infrastructure management*
- *[Argo Rollouts in Action](https://medium.com/@sergeiolshanetski/argo-rollouts-in-action) — Progressive delivery & canary deployments*
- *[KEDA in Action](https://medium.com/@sergeiolshanetski/keda-in-action) — Event-driven autoscaling*

*Follow me on [Medium](https://medium.com/@sergeiolshanetski) for the next one. 🏀*
