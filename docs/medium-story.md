# Falco in Action: Runtime Security for Kubernetes — Catching Threats After They're Inside the Arena

> *Kyverno stops bad pods at the door. Falco catches them once they're on the court.*

## The Problem: Admission Control Isn't Enough

If you've read my [Kyverno in Action](https://medium.com/@sergeiolshanetski/kyverno-in-action-policy-as-code-admission-control-for-kubernetes-from-free-for-all-to-17e41becf176) article, you know how to stop bad pods at admission time. Required labels, no `:latest`, non-root enforcement, image signature verification — all before a single byte hits etcd.

But what happens when a perfectly compliant pod gets compromised *after* it's admitted? What if an attacker finds an RCE vulnerability in your web app and spawns a shell inside the container? What if a supply chain attack sneaks malicious code into a trusted image?

Admission control can't help you here. You need **runtime security** — something watching what containers actually *do* at the kernel level, in real-time.

That something is **Falco**.

## What is Falco?

[Falco](https://falco.org/) is a CNCF graduated project (same maturity level as Kubernetes itself) that monitors Linux kernel syscalls in real-time using eBPF. When a container does something suspicious — opens `/etc/shadow`, spawns a shell, connects to a crypto mining pool — Falco detects it and fires an alert.

Think of it this way:
- **Kyverno** = the bouncer at the arena door (admission control)
- **Falco** = the security camera system inside the arena (runtime detection)

You need both. A bouncer checks IDs at the entrance, but security cameras catch the fan who snuck in through the loading dock and is now running across the court.

## The Demo: NBA Arena Security

Following the same pattern as my other *-in-action projects, this demo uses an NBA theme:

| Component | NBA Analogy | Role |
|---|---|---|
| **arena-security-api** | The arena's security ops center | Compliant, well-behaved pod |
| **rogue-player** | A rogue player/intruder | Intentionally malicious pod with attack endpoints |
| **alert-dashboard** | The big board in the SOC | Receives Falco alerts via Falcosidekick webhook |
| **Falco** | The security camera system | eBPF-based syscall monitoring |
| **Falcosidekick** | The alarm routing system | Forwards alerts to dashboard, UI, Slack, etc. |

## Architecture

```
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │                                                  │
 User ────────►  │  arena-security-api     rogue-player             │
 localhost:9080 │  (compliant, non-root)   (attacker, root)        │
                 │       │                      │                   │
                 │       │ normal behavior      │ attacks           │
                 │       │                      │                   │
                 │       └──────────┬───────────┘                   │
                 │                  │                                │
                 │    Falco (eBPF) watches ALL syscalls              │
                 │         │                                        │
                 │         ▼                                        │
                 │    Falcosidekick ──► alert-dashboard             │
                 │         │           (webhook receiver)           │
                 │         └────────► Falcosidekick UI              │
                 └──────────────────────────────────────────────────┘
```

## Setup (5 Minutes)

```bash
git clone https://github.com/23seriy/falco-in-action.git
cd falco-in-action
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
```

## The Attack Scenarios

### 1. 🐚 Shell in Container — Breaking Into the Arena

The most fundamental attack: spawning a shell inside a running container. In production, this happens when an attacker exploits an RCE vulnerability and gets interactive access.

```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c "whoami && id"
```

Falco immediately fires:
```
Warning: A shell was spawned in a container with an attached terminal
(pod=rogue-player ns=falco-demo container=rogue-player shell=sh)
```

**NBA analogy:** A fan jumping the barrier and running onto the court.

### 2. 📄 Read Sensitive File — Raiding the Locker Room

Attackers read `/etc/shadow` to harvest password hashes, or SSH keys for lateral movement:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- cat /etc/shadow
```

Falco catches it:
```
Warning: Sensitive file opened for reading (file=/etc/shadow pod=rogue-player)
```

**NBA analogy:** Sneaking into the opponent's locker room to steal their playbook.

### 3. 💀 Write Below Binary Dir — Planting a Backdoor

Persistence technique — drop a backdoor binary into `/usr/bin` so it survives container restarts:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- /bin/sh -c \
  "echo '#!/bin/sh' > /usr/bin/backdoor && chmod +x /usr/bin/backdoor"
```

Falco alerts:
```
Error: Write below binary dir (file=/usr/bin/backdoor pod=rogue-player)
```

**NBA analogy:** Rigging the scoreboard with your own equipment.

### 4. 📦 Package Management — Installing Attack Tools

Running `apt-get install nmap` inside a container is a red flag — containers should be immutable. Packages belong in the image build, not at runtime:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- apt-get --version
```

Falco detects:
```
Error: Package management process launched in container (command=apt-get pod=rogue-player)
```

**NBA analogy:** A player bringing outside equipment onto the court mid-game.

### 5. 🔑 Kubernetes Credential Theft — Stealing the Playbook

The first thing an attacker does after getting a shell: read the ServiceAccount token to pivot within the cluster:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token
```

Our custom rule fires:
```
Critical: K8s credential access detected in arena pod (pod=rogue-player file=/var/run/secrets/kubernetes.io/serviceaccount/token)
```

**NBA analogy:** Stealing the coach's iPad with all the play diagrams.

### 6. 🌐 Outbound Connection — Sneaking Out the Back Door

A compromised pod phoning home to a C2 server:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',443))"
```

Custom rule catches it:
```
Warning: Outbound connection from arena pod (pod=rogue-player dest=1.1.1.1:443)
```

**NBA analogy:** A player sneaking out of the arena to meet their agent during the game.

### 7. ⛏️ Crypto Mining — Using the Arena's Power Grid

The most common container attack in the wild — cryptojacking:

```bash
kubectl exec -n falco-demo deploy/rogue-player -- python -c \
  "import socket; s=socket.socket(); s.settimeout(2); s.connect(('1.1.1.1',45700))"
```

Custom rule detects the mining pool port:
```
Critical: Possible crypto mining detected in arena pod (pod=rogue-player dest_port=45700)
```

**NBA analogy:** Using the arena's generator to power your Bitcoin rig hidden under the bleachers.

## Custom Rules: Teaching Falco Your Arena's Layout

Falco ships with excellent default rules, but every environment has unique threats. Writing custom rules is straightforward:

```yaml
- rule: Arena Pod Making Outbound Connection
  desc: Detect when a demo pod connects to external IPs
  condition: >
    evt.type in (connect, sendto) and
    container.id != host and
    k8s.ns.name = "falco-demo" and
    not fd.snet in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
  output: >
    Outbound connection from arena pod
    (pod=%k8s.pod.name connection=%fd.name dest=%fd.sip:%fd.sport)
  priority: WARNING
  tags: [network, nba-arena, mitre_exfiltration]
```

The rule anatomy:
- **condition**: Falco's filter language over syscall events. Uses fields like `evt.type`, `k8s.ns.name`, `fd.name`.
- **output**: What appears in the alert. `%k8s.pod.name` is a runtime-resolved field.
- **priority**: Emergency → Debug. Drives routing decisions in Falcosidekick.
- **tags**: For categorization and MITRE ATT&CK mapping.

## Alert Routing with Falcosidekick

Falco writes alerts to stdout. Falcosidekick receives them and routes to 60+ outputs:

- **Webhook** → our alert-dashboard (this demo)
- **Slack** → #security-alerts channel
- **PagerDuty** → on-call rotation for Critical alerts
- **AWS CloudWatch / S3** → audit trail
- **Elasticsearch** → searchable alert history
- **Falcosidekick UI** → built-in web dashboard

In this demo, alerts flow to both our custom alert-dashboard and the Falcosidekick UI:

```bash
# Custom dashboard
kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo
curl http://localhost:9082/alerts/summary

# Falcosidekick UI
kubectl port-forward svc/falcosidekick-ui 2802:2802 -n falco-system
open http://localhost:2802
```

## Kyverno + Falco: The Complete Defense

| Layer | Tool | When | Example |
|---|---|---|---|
| **Admission** | Kyverno | Before pod runs | Block `:latest` tags, require non-root, verify signatures |
| **Runtime** | Falco | While pod runs | Detect shell access, credential theft, crypto mining |

Kyverno prevents *known bad configurations*. Falco detects *unknown bad behavior*.

Together, they cover the full lifecycle:

1. A pod passes all Kyverno policies (good config) ✅
2. An attacker exploits an RCE bug in the app 💀
3. The attacker spawns a shell → Falco alerts 🚨
4. The attacker reads the SA token → Falco alerts 🚨
5. The attacker connects to a C2 server → Falco alerts 🚨

Without Falco, steps 3–5 happen silently.

## Key Takeaways

1. **Admission control isn't enough** — Compliant pods can still be compromised at runtime. Falco watches what containers actually do, not just how they're configured.

2. **eBPF is the enabler** — Falco's modern eBPF driver monitors syscalls without kernel modules, sidecars, or code changes. Zero instrumentation of your apps.

3. **Custom rules close the gap** — Default rules cover 80% of threats. Write custom rules for your environment: unexpected outbound connections, credential access, mining indicators.

4. **Alert routing makes it actionable** — Falcosidekick routes alerts to Slack, PagerDuty, SIEM, or custom webhooks. Detection without notification is just logging.

5. **Defense in depth is not optional** — Kyverno at admission + Falco at runtime = no blind spots. Layer your defenses like an NBA arena layers its security: ID checks at the door, cameras inside, and a SOC watching the feeds.

## Resources

- [Falco Documentation](https://falco.org/docs/)
- [Falco Rules Reference](https://falco.org/docs/rules/)
- [Falcosidekick](https://github.com/falcosecurity/falcosidekick)
- [MITRE ATT&CK for Containers](https://attack.mitre.org/matrices/enterprise/containers/)
- [GitHub: falco-in-action](https://github.com/23seriy/falco-in-action)

---

*This is part of my "in Action" series — hands-on Kubernetes projects you can run on your laptop. See also: [Kyverno in Action](https://medium.com/@sergeiolshanetski/kyverno-in-action), [Crossplane in Action](https://medium.com/@sergeiolshanetski/crossplane-in-action), [Cilium in Action](https://medium.com/@sergeiolshanetski/cilium-in-action), and more on my [Medium profile](https://medium.com/@sergeiolshanetski).*
