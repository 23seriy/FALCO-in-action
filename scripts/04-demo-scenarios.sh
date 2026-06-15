#!/usr/bin/env bash
# =============================================================================
# 04 — Interactive Demo Scenarios
# =============================================================================
# Walks through each Falco detection scenario interactively.
# Each scenario triggers a specific attack from the rogue-player pod
# and shows you how to observe the Falco alert.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}\n"; }
attack()  { echo -e "${RED}[ATTACK]${NC} $*"; }

ROGUE_POD=""

wait_for_enter() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue to the next scenario...${NC}"
    read -r
}

get_rogue_pod() {
    ROGUE_POD=$(kubectl get pod -n falco-demo -l app=rogue-player -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -z "$ROGUE_POD" ]]; then
        echo "❌ rogue-player pod not found. Run 03-deploy-app.sh first."
        exit 1
    fi
}

show_falco_logs() {
    local lines=${1:-10}
    sleep 2  # Give Falco a moment to process syscall events
    echo ""
    info "Recent Falco alerts (last $lines lines):"
    echo "─────────────────────────────────────────────"
    kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=50 2>/dev/null | \
        grep -i "Warning\|Critical\|Error\|Notice" | tail -"$lines" || \
        warn "No matching alerts found yet — Falco may need a moment."
    echo "─────────────────────────────────────────────"
}

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║         🛡️  Falco in Action — Demo Scenarios            ║"
echo "║                                                          ║"
echo "║  Runtime security for Kubernetes.                        ║"
echo "║  Kyverno stops threats at the door (admission).          ║"
echo "║  Falco catches them once they're inside (runtime).       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

get_rogue_pod
info "Using rogue pod: $ROGUE_POD"
echo ""

# =============================================================================
# TIP: Open a second terminal to watch Falco logs in real-time:
#   kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f
# =============================================================================

echo "💡 TIP: Open a second terminal and run:"
echo "   kubectl logs -n falco-system -l app.kubernetes.io/name=falco -f"
echo ""
echo "   This lets you see alerts appear in real-time as attacks fire."

wait_for_enter

# =============================================================================
# Scenario 1: Baseline — The Good Citizen
# =============================================================================
header "═══ Scenario 1: Baseline — The Good Citizen ═══"

echo "The arena-security-api is a compliant, well-behaved pod."
echo "It runs as non-root, has a read-only filesystem, drops all"
echo "capabilities, and never does anything suspicious."
echo ""
echo "Let's verify it works and doesn't trigger any Falco alerts:"
echo ""

info "Testing arena-security-api..."
kubectl exec -n falco-demo "$ROGUE_POD" -- \
    python -c "
import urllib.request, json
resp = urllib.request.urlopen('http://arena-security-api.falco-demo.svc.cluster.local:8080/security/status')
data = json.loads(resp.read())
print(json.dumps(data, indent=2))
" 2>/dev/null || warn "Could not reach arena-security-api from rogue pod."

echo ""
info "No Falco alerts for normal HTTP requests — that's the baseline."

wait_for_enter

# =============================================================================
# Scenario 2: Shell in Container — Breaking Into the Arena
# =============================================================================
header "═══ Scenario 2: 🐚 Shell in Container — Breaking Into the Arena ═══"

echo "The most basic attack: spawning a shell inside a running container."
echo "Falco's built-in rule 'Terminal shell in container' catches this."
echo ""
echo "NBA analogy: A fan jumping the barrier and running onto the court."
echo ""

attack "Triggering: kubectl exec into the rogue pod with /bin/sh..."
kubectl exec -n falco-demo "$ROGUE_POD" -- /bin/sh -c "echo '🏀 I am inside the arena! $(whoami) on $(hostname)'" 2>/dev/null

echo ""
info "Falco should now show: 'A shell was spawned in a container'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 3: Read Sensitive File — Raiding the Locker Room
# =============================================================================
header "═══ Scenario 3: 📄 Read Sensitive File — Raiding the Locker Room ═══"

echo "Reading /etc/shadow reveals password hashes."
echo "Falco's built-in rule catches reads of sensitive files like"
echo "/etc/shadow, /etc/passwd, and SSH keys."
echo ""
echo "NBA analogy: Sneaking into the opponent's locker room to steal their playbook."
echo ""

attack "Triggering: Reading /etc/shadow from the rogue pod..."
kubectl exec -n falco-demo "$ROGUE_POD" -- cat /etc/shadow 2>/dev/null || true

echo ""
info "Falco should now show: 'Sensitive file opened for reading'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 4: Write Below Binary Dir — Planting a Backdoor
# =============================================================================
header "═══ Scenario 4: 💀 Write Below Binary Dir — Planting a Backdoor ═══"

echo "Writing to /usr/bin or /usr/sbin is a classic persistence technique."
echo "Falco's built-in rule 'Write below binary dir' catches this."
echo ""
echo "NBA analogy: Rigging the scoreboard with your own equipment."
echo ""

attack "Triggering: Writing a fake binary to /usr/bin..."
kubectl exec -n falco-demo "$ROGUE_POD" -- /bin/sh -c "echo '#!/bin/sh' > /usr/bin/backdoor && chmod +x /usr/bin/backdoor" 2>/dev/null || true

echo ""
info "Falco should now show: 'Write below binary dir'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 5: Package Management — Installing Attack Tools
# =============================================================================
header "═══ Scenario 5: 📦 Package Management — Installing Attack Tools ═══"

echo "Running apt-get or apk inside a container is suspicious in production."
echo "Containers should be immutable — packages belong in the image, not at runtime."
echo "Falco's built-in rule 'Launch Package Management Process' catches this."
echo ""
echo "NBA analogy: A player bringing outside equipment onto the court mid-game."
echo ""

attack "Triggering: Running apt-get inside the rogue pod..."
kubectl exec -n falco-demo "$ROGUE_POD" -- /bin/sh -c "apt-get --version" 2>/dev/null || \
kubectl exec -n falco-demo "$ROGUE_POD" -- /bin/sh -c "apk --version" 2>/dev/null || true

echo ""
info "Falco should now show: 'Package management process launched in container'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 6: Kubernetes Credential Theft — Stealing the Playbook
# =============================================================================
header "═══ Scenario 6: 🔑 K8s Credential Theft — Stealing the Playbook ═══"

echo "The Kubernetes service account token at"
echo "  /var/run/secrets/kubernetes.io/serviceaccount/token"
echo "gives API access to the cluster. Attackers read it to pivot."
echo ""
echo "Our custom rule 'Arena Pod Reading K8s Secrets' catches this."
echo ""
echo "NBA analogy: Stealing the coach's iPad with all the play diagrams."
echo ""

attack "Triggering: Reading the ServiceAccount token..."
kubectl exec -n falco-demo "$ROGUE_POD" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null || \
    warn "Token not mounted — the pod may have automountServiceAccountToken: false."

echo ""
info "Falco should now show: 'K8s credential access detected in arena pod'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 7: Outbound Connection — Sneaking Out the Back Door
# =============================================================================
header "═══ Scenario 7: 🌐 Outbound Connection — Sneaking Out the Back Door ═══"

echo "Pods in production rarely need to call external IPs directly."
echo "Our custom rule 'Arena Pod Making Outbound Connection' catches"
echo "connections to IPs outside the cluster's private ranges."
echo ""
echo "NBA analogy: A player sneaking out of the arena to meet their agent"
echo "during the game."
echo ""

attack "Triggering: Connecting to 1.1.1.1:443 from the rogue pod..."
kubectl exec -n falco-demo "$ROGUE_POD" -- python -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(3)
try:
    s.connect(('1.1.1.1', 443))
    print('Connected to 1.1.1.1:443')
except Exception as e:
    print(f'Connection attempt: {e}')
finally:
    s.close()
" 2>/dev/null || true

echo ""
info "Falco should now show: 'Outbound connection from arena pod'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 8: Crypto Mining — Using the Arena's Power
# =============================================================================
header "═══ Scenario 8: ⛏️  Crypto Mining — Using the Arena's Power Grid ═══"

echo "Cryptojacking is one of the most common container attacks."
echo "Attackers deploy miners that connect to mining pools on known ports."
echo "Our custom rule 'Arena Pod Crypto Mining Activity' watches for"
echo "connections to mining pool ports (3333, 4444, 45700, etc.)."
echo ""
echo "NBA analogy: Using the arena's generator to power your Bitcoin rig"
echo "hidden under the bleachers."
echo ""

attack "Triggering: Attempting connection to mining pool port..."
kubectl exec -n falco-demo "$ROGUE_POD" -- python -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(2)
try:
    s.connect(('1.1.1.1', 45700))
except Exception as e:
    print(f'Mining pool connection attempt: {e}')
finally:
    s.close()
" 2>/dev/null || true

echo ""
info "Falco should now show: 'Possible crypto mining detected in arena pod'"
show_falco_logs 5

wait_for_enter

# =============================================================================
# Scenario 9: Check the Alert Dashboard
# =============================================================================
header "═══ Scenario 9: 📊 Check the Alert Dashboard (SOC) ═══"

echo "All of the above attacks were also forwarded by Falcosidekick"
echo "to our alert-dashboard (the arena's security operations center)."
echo ""
echo "Let's check what accumulated:"
echo ""

DASHBOARD_POD=$(kubectl get pod -n falco-demo -l app=alert-dashboard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -n "$DASHBOARD_POD" ]]; then
    info "Alert summary from the dashboard:"
    kubectl exec -n falco-demo "$DASHBOARD_POD" -- python -c "
import urllib.request, json
try:
    resp = urllib.request.urlopen('http://localhost:8080/alerts/summary')
    data = json.loads(resp.read())
    print(json.dumps(data, indent=2))
except Exception as e:
    print(f'Could not reach dashboard: {e}')
" 2>/dev/null || warn "Could not query alert dashboard."
fi

echo ""
echo "To browse alerts interactively:"
echo "  kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo"
echo "  curl http://localhost:9082/alerts"
echo ""
echo "To open the Falcosidekick UI:"
echo "  kubectl port-forward svc/falcosidekick-ui -n falco-system 2802:2802"
echo "  open http://localhost:2802"

wait_for_enter

# =============================================================================
# Scenario 10: Full Audit — The Security Report
# =============================================================================
header "═══ Scenario 10: 📋 Full Audit — The Post-Game Security Report ═══"

echo "Just like an NBA arena files a post-game security report,"
echo "let's review everything Falco caught during this demo."
echo ""

info "Falco alert counts by rule (from Falco logs):"
echo "─────────────────────────────────────────────"
kubectl logs -n falco-system -l app.kubernetes.io/name=falco --tail=500 2>/dev/null | \
    grep -oE '"rule":"[^"]*"' | \
    sort | uniq -c | sort -rn | head -20 || \
    warn "Could not parse Falco logs."
echo "─────────────────────────────────────────────"

echo ""
info "Active Falco pods:"
kubectl get pods -n falco-system

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  🏆 Demo Complete!                       ║"
echo "║                                                          ║"
echo "║  You've seen Falco detect:                               ║"
echo "║    ✅ Shell access in containers                         ║"
echo "║    ✅ Sensitive file reads (/etc/shadow)                 ║"
echo "║    ✅ Binary directory writes (backdoor persistence)     ║"
echo "║    ✅ Package management in containers                   ║"
echo "║    ✅ Kubernetes credential theft                        ║"
echo "║    ✅ Outbound connections to external IPs               ║"
echo "║    ✅ Crypto mining activity                             ║"
echo "║    ✅ Alert forwarding via Falcosidekick                 ║"
echo "║                                                          ║"
echo "║  Kyverno stops bad pods at the door.                     ║"
echo "║  Falco catches bad behavior at runtime.                  ║"
echo "║  Together, they're your cluster's complete defense.      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "To tear down:"
echo "  ./scripts/05-teardown.sh"
echo ""
