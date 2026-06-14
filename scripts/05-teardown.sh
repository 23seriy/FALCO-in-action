#!/usr/bin/env bash
# =============================================================================
# 05 — Teardown
# =============================================================================
# Deletes all demo resources, uninstalls Falco + Falcosidekick,
# and removes the Minikube cluster.
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

PROFILE="falco-demo"

echo ""
echo "================================================"
echo "  Falco in Action — Teardown"
echo "================================================"
echo ""

# ---- Delete demo namespace ---------------------------------------------------

info "Deleting demo namespace..."
kubectl delete namespace falco-demo --ignore-not-found --timeout=30s 2>/dev/null || true

# ---- Uninstall Falcosidekick -------------------------------------------------

info "Uninstalling Falcosidekick..."
helm uninstall falcosidekick -n falco-system 2>/dev/null || true

# ---- Uninstall Falco ---------------------------------------------------------

info "Uninstalling Falco..."
helm uninstall falco -n falco-system 2>/dev/null || true

# ---- Delete falco-system namespace -------------------------------------------

info "Deleting falco-system namespace..."
kubectl delete namespace falco-system --ignore-not-found --timeout=30s 2>/dev/null || true

# ---- Delete Minikube cluster -------------------------------------------------

info "Deleting Minikube profile '$PROFILE'..."
minikube delete -p "$PROFILE" 2>/dev/null || true

echo ""
info "✅ Teardown complete. Cluster and all resources removed."
echo ""
