# Contributing to Falco in Action

Thank you for considering a contribution! This project is a hands-on learning resource for Kubernetes runtime security with Falco.

## How to Contribute

### 🐛 Bug Reports
1. Open an issue describing what you expected vs. what happened.
2. Include your environment: macOS version, Minikube version, Kubernetes version.
3. Paste relevant Falco logs if the issue involves rule detection.

### ✨ Feature Requests
- New attack scenarios (with corresponding Falco rules)
- Additional Falcosidekick integrations (Slack, PagerDuty, etc.)
- New demo microservices
- Documentation improvements

### 🔧 Pull Requests
1. Fork the repository and create a feature branch.
2. Follow the existing code style (Python for apps, Bash for scripts, YAML for K8s/Falco).
3. Test your changes end-to-end with `./scripts/02-start-cluster.sh` through `04-demo-scenarios.sh`.
4. Update documentation if you add new scenarios or change behavior.
5. Submit a PR with a clear description of what changed and why.

## Code Standards
- **Python**: Flask apps, minimal dependencies, comprehensive error handling.
- **Bash scripts**: `set -euo pipefail`, colored output, numbered sequence.
- **Kubernetes YAML**: Include resource limits, labels, and security contexts (except for intentionally insecure pods).
- **Falco rules**: Follow the [Falco rule writing guide](https://falco.org/docs/rules/) and include descriptive `desc` fields.

## Testing
- Run the full demo flow after any changes.
- Verify Falco alerts fire for attack scenarios.
- Check that the alert-dashboard receives forwarded alerts.
