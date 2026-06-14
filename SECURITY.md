# Security Policy

## ⚠️ Important Notice

This project **intentionally contains insecure workloads** for educational purposes. The `rogue-player` pod runs as root and performs actions that would be security violations in production. This is by design — it's the attacker simulation for the Falco demo.

**Never deploy the rogue-player workload in a production environment.**

## Reporting Vulnerabilities

If you discover a security vulnerability in the project code (not the intentional demo vulnerabilities), please:

1. **Do NOT** open a public GitHub issue.
2. Email the maintainer directly.
3. Include a description of the vulnerability and steps to reproduce.

## Security Best Practices Demonstrated

This project demonstrates several security best practices:

- **Runtime detection** with Falco (eBPF-based syscall monitoring)
- **Alert routing** with Falcosidekick (webhook, UI)
- **Least privilege** in the compliant arena-security-api (non-root, read-only FS, drop ALL caps)
- **Custom rule authoring** for environment-specific threats
- **Defense in depth** — admission control (Kyverno) + runtime detection (Falco)
