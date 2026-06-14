#!/usr/bin/env bash
# =============================================================================
# 02 — Start Cluster + Install Falco
# =============================================================================
# Creates a Minikube profile 'falco-demo', installs Falco with the modern
# eBPF driver, and installs Falcosidekick for alert routing.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }

PROFILE="falco-demo"
K8S_VERSION="v1.32.0"
CPUS=4
MEMORY=8192

echo ""
echo "================================================"
echo "  Falco in Action — Start Cluster"
echo "================================================"
echo ""

# ---- Minikube Cluster -------------------------------------------------------

if minikube status -p "$PROFILE" &>/dev/null; then
    info "Minikube profile '$PROFILE' already exists and is running."
else
    info "Creating Minikube profile '$PROFILE' (K8s $K8S_VERSION, ${CPUS} CPUs, ${MEMORY}MB RAM)..."
    minikube start \
        -p "$PROFILE" \
        --kubernetes-version="$K8S_VERSION" \
        --cpus="$CPUS" \
        --memory="$MEMORY" \
        --driver=docker \
        --container-runtime=containerd
fi

info "Setting kubectl context to '$PROFILE'..."
kubectl config use-context "$PROFILE"

# ---- Falco -------------------------------------------------------------------

info "Adding Falcosecurity Helm repo..."
helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
helm repo update falcosecurity

if helm status falco -n falco-system &>/dev/null; then
    info "Falco is already installed."
else
    info "Installing Falco with modern eBPF driver..."
    kubectl create namespace falco-system --dry-run=client -o yaml | kubectl apply -f -

    helm install falco falcosecurity/falco \
        --namespace falco-system \
        --set driver.kind=modern_ebpf \
        --set falco.json_output=true \
        --set falco.json_include_output_property=true \
        --set tty=false \
        --wait \
        --timeout 300s
fi

# ---- Falcosidekick -----------------------------------------------------------

if helm status falcosidekick -n falco-system &>/dev/null; then
    info "Falcosidekick is already installed."
else
    info "Installing Falcosidekick..."

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

    helm install falcosidekick falcosecurity/falcosidekick \
        --namespace falco-system \
        -f "$PROJECT_DIR/falco/falcosidekick-values.yaml" \
        --wait \
        --timeout 120s
fi

# ---- Configure Falco to send events to Falcosidekick -------------------------

info "Patching Falco to forward events to Falcosidekick..."
SIDEKICK_SVC="http://falcosidekick.falco-system.svc.cluster.local:2801"

helm upgrade falco falcosecurity/falco \
    --namespace falco-system \
    --reuse-values \
    --set falco.http_output.enabled=true \
    --set falco.http_output.url="$SIDEKICK_SVC" \
    --wait \
    --timeout 120s

# ---- Wait for pods -----------------------------------------------------------

info "Waiting for Falco pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=falco \
    -n falco-system \
    --timeout=120s 2>/dev/null || warn "Falco pods not fully ready yet — they may need another minute for eBPF setup."

info "Waiting for Falcosidekick pods to be ready..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=falcosidekick \
    -n falco-system \
    --timeout=60s 2>/dev/null || warn "Falcosidekick pods still starting."

echo ""
info "✅ Cluster is ready. Falco + Falcosidekick installed."
echo ""
echo "  Falco pods:"
kubectl get pods -n falco-system
echo ""
echo "Next step:"
echo "  ./scripts/03-deploy-app.sh"
echo ""
