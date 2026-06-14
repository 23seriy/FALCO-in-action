"""
Rogue Player — Intentionally malicious pod for Falco demos.

This pod simulates an attacker or compromised workload inside the cluster.
It provides HTTP endpoints that trigger specific attack behaviors on demand,
letting the demo operator fire attacks one at a time from `curl`.

Each endpoint maps to a Falco rule scenario:
  /attack/shell        — Spawns a shell process (terminal shell in container)
  /attack/sensitive    — Reads /etc/shadow (read sensitive file)
  /attack/network      — Makes outbound connection (unexpected outbound)
  /attack/package      — Runs apt/apk install (package management in container)
  /attack/credentials  — Reads Kubernetes service account token
  /attack/crypto       — Simulates crypto mining behavior
  /attack/dns          — Resolves suspicious domains
  /attack/writeback    — Writes to /usr/bin (modify binary dirs)
"""

import os
import socket
import subprocess
import logging
from flask import Flask, jsonify

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


@app.route("/")
def index():
    return jsonify(
        {
            "service": "Rogue Player",
            "description": "Attack simulation pod — triggers Falco rules on demand",
            "attacks": [
                "GET /attack/shell",
                "GET /attack/sensitive",
                "GET /attack/network",
                "GET /attack/package",
                "GET /attack/credentials",
                "GET /attack/crypto",
                "GET /attack/dns",
                "GET /attack/writeback",
            ],
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})


@app.route("/attack/shell")
def attack_shell():
    """Trigger: Terminal shell in container (Falco default rule)."""
    logger.info("ATTACK: Spawning shell process")
    try:
        result = subprocess.run(
            ["/bin/sh", "-c", "whoami && id && hostname"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return jsonify(
            {
                "attack": "shell_in_container",
                "falco_rule": "Terminal shell in container",
                "output": result.stdout.strip(),
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify({"attack": "shell_in_container", "error": str(e)}), 500


@app.route("/attack/sensitive")
def attack_sensitive():
    """Trigger: Read sensitive file (Falco default rule)."""
    logger.info("ATTACK: Reading /etc/shadow")
    try:
        with open("/etc/shadow", "r") as f:
            content = f.read()[:200]
        return jsonify(
            {
                "attack": "read_sensitive_file",
                "falco_rule": "Read sensitive file untrusted / Read sensitive file trusted after startup",
                "file": "/etc/shadow",
                "preview": content,
                "triggered": True,
            }
        )
    except PermissionError:
        return jsonify(
            {
                "attack": "read_sensitive_file",
                "falco_rule": "Read sensitive file untrusted",
                "file": "/etc/shadow",
                "note": "Permission denied (non-root) — Falco still detects the attempt",
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify({"attack": "read_sensitive_file", "error": str(e)}), 500


@app.route("/attack/network")
def attack_network():
    """Trigger: Unexpected outbound connection."""
    logger.info("ATTACK: Outbound connection to external host")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        sock.connect(("1.1.1.1", 443))
        sock.close()
        return jsonify(
            {
                "attack": "outbound_connection",
                "falco_rule": "Unexpected outbound connection destination",
                "target": "1.1.1.1:443",
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify(
            {
                "attack": "outbound_connection",
                "falco_rule": "Unexpected outbound connection destination",
                "target": "1.1.1.1:443",
                "note": f"Connection failed ({e}) — Falco still detects the syscall",
                "triggered": True,
            }
        )


@app.route("/attack/package")
def attack_package():
    """Trigger: Launch Package Management Process in Container."""
    logger.info("ATTACK: Running package manager")
    try:
        # Try apt first (Debian-based), fall back to apk (Alpine)
        for cmd in ["apt", "apt-get", "apk"]:
            try:
                result = subprocess.run(
                    [cmd, "--version"],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                if result.returncode == 0 or result.stdout:
                    return jsonify(
                        {
                            "attack": "package_management",
                            "falco_rule": "Launch Package Management Process in Container",
                            "command": f"{cmd} --version",
                            "output": result.stdout.strip()[:200],
                            "triggered": True,
                        }
                    )
            except FileNotFoundError:
                continue

        # If no package manager found, simulate with a known binary name
        result = subprocess.run(
            ["/bin/sh", "-c", "echo 'simulated apt-get install'"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        return jsonify(
            {
                "attack": "package_management",
                "falco_rule": "Launch Package Management Process in Container",
                "note": "No package manager binary found; used shell simulation",
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify({"attack": "package_management", "error": str(e)}), 500


@app.route("/attack/credentials")
def attack_credentials():
    """Trigger: Read ServiceAccount token from filesystem."""
    logger.info("ATTACK: Reading Kubernetes service account token")
    token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token"
    try:
        with open(token_path, "r") as f:
            token = f.read()[:50] + "..."
        return jsonify(
            {
                "attack": "credential_access",
                "falco_rule": "Read sensitive file untrusted",
                "file": token_path,
                "token_preview": token,
                "triggered": True,
            }
        )
    except FileNotFoundError:
        return jsonify(
            {
                "attack": "credential_access",
                "file": token_path,
                "note": "Token not mounted (automountServiceAccountToken: false)",
                "triggered": False,
            }
        )
    except Exception as e:
        return jsonify({"attack": "credential_access", "error": str(e)}), 500


@app.route("/attack/crypto")
def attack_crypto():
    """Trigger: Detect crypto miners using the stratum protocol."""
    logger.info("ATTACK: Simulating crypto mining behavior")
    try:
        # Attempt to resolve a mining pool domain (triggers DNS + connect rules)
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        try:
            sock.connect(("pool.minergate.com", 45700))
            sock.send(
                b'{"method":"login","params":{"login":"attacker"}}\n'
            )
        except Exception:
            pass
        finally:
            sock.close()

        return jsonify(
            {
                "attack": "crypto_mining",
                "falco_rule": "Detect crypto miners using the Stratum protocol",
                "target": "pool.minergate.com:45700",
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify({"attack": "crypto_mining", "error": str(e)}), 500


@app.route("/attack/dns")
def attack_dns():
    """Trigger: Suspicious DNS resolution."""
    logger.info("ATTACK: Resolving suspicious domains")
    domains = [
        "evil-c2-server.example.com",
        "data-exfil.attacker.io",
        "cryptominer.bad-domain.net",
    ]
    results = []
    for domain in domains:
        try:
            ip = socket.getaddrinfo(domain, 443)
            results.append({"domain": domain, "resolved": True, "ip": str(ip[0][4])})
        except socket.gaierror:
            results.append({"domain": domain, "resolved": False, "reason": "NXDOMAIN"})

    return jsonify(
        {
            "attack": "suspicious_dns",
            "falco_rule": "Custom DNS exfiltration detection",
            "domains": results,
            "triggered": True,
        }
    )


@app.route("/attack/writeback")
def attack_writeback():
    """Trigger: Write below binary dir (Falco default rule)."""
    logger.info("ATTACK: Writing to /usr/bin")
    target = "/usr/bin/backdoor"
    try:
        with open(target, "w") as f:
            f.write("#!/bin/sh\necho hacked\n")
        os.chmod(target, 0o755)
        return jsonify(
            {
                "attack": "write_binary_dir",
                "falco_rule": "Write below binary dir",
                "file": target,
                "triggered": True,
            }
        )
    except PermissionError:
        return jsonify(
            {
                "attack": "write_binary_dir",
                "falco_rule": "Write below binary dir",
                "file": target,
                "note": "Permission denied (non-root) — mount /usr/bin as writable for full demo",
                "triggered": True,
            }
        )
    except Exception as e:
        return jsonify({"attack": "write_binary_dir", "error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info("Starting Rogue Player on port %d", port)
    app.run(host="0.0.0.0", port=port)
