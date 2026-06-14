#!/usr/bin/env bash
# =============================================================================
# 03 — Build & Deploy the Demo Applications
# =============================================================================
# Builds Docker images inside Minikube, loads custom Falco rules,
# and deploys the arena-security-api, rogue-player, and alert-dashboard.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

PROFILE="falco-demo"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo "================================================"
echo "  Falco in Action — Build & Deploy"
echo "================================================"
echo ""

# ---- Point Docker at Minikube -----------------------------------------------

info "Configuring Docker to use Minikube's daemon..."
eval $(minikube docker-env -p "$PROFILE")

# ---- Build Images ------------------------------------------------------------

info "Building arena-security-api..."
docker build -t arena-security-api:v1 "$PROJECT_DIR/apps/arena-security-api"

info "Building rogue-player..."
docker build -t rogue-player:v1 "$PROJECT_DIR/apps/rogue-player"

info "Building alert-dashboard..."
docker build -t alert-dashboard:v1 "$PROJECT_DIR/apps/alert-dashboard"

# ---- Create Namespace --------------------------------------------------------

info "Creating namespace..."
kubectl apply -f "$PROJECT_DIR/k8s/namespace.yaml"

# ---- Load Custom Falco Rules ------------------------------------------------

info "Loading custom Falco rules..."
helm upgrade falco falcosecurity/falco \
    --namespace falco-system \
    --reuse-values \
    --set-file "customRules.custom-rules\.yaml=$PROJECT_DIR/falco/custom-rules.yaml" \
    --wait \
    --timeout 120s

# Wait for Falco to reload
info "Waiting for Falco to reload rules..."
sleep 10
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=falco \
    -n falco-system \
    --timeout=60s 2>/dev/null || warn "Falco pods restarting..."

# ---- Deploy Applications ----------------------------------------------------

info "Deploying arena-security-api (compliant app)..."
kubectl apply -f "$PROJECT_DIR/k8s/arena-security-api.yaml"

info "Deploying rogue-player (attacker pod)..."
kubectl apply -f "$PROJECT_DIR/k8s/rogue-player.yaml"

info "Deploying alert-dashboard (SOC receiver)..."
kubectl apply -f "$PROJECT_DIR/k8s/alert-dashboard.yaml"

# ---- Wait for deployments ---------------------------------------------------

info "Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/arena-security-api \
    -n falco-demo --timeout=60s
kubectl wait --for=condition=available deployment/rogue-player \
    -n falco-demo --timeout=60s
kubectl wait --for=condition=available deployment/alert-dashboard \
    -n falco-demo --timeout=60s

echo ""
info "✅ All applications deployed."
echo ""
echo "  Demo pods:"
kubectl get pods -n falco-demo
echo ""
echo "  Falco pods:"
kubectl get pods -n falco-system
echo ""
echo "Access the apps:"
echo "  kubectl port-forward svc/arena-security-api 9080:8080 -n falco-demo"
echo "  kubectl port-forward svc/rogue-player 9081:8080 -n falco-demo"
echo "  kubectl port-forward svc/alert-dashboard 9082:8080 -n falco-demo"
echo ""
echo "Next step:"
echo "  ./scripts/04-demo-scenarios.sh"
echo ""
