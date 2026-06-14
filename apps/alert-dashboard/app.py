"""
Alert Dashboard — Falcosidekick webhook receiver and display.

Receives Falco alerts forwarded by Falcosidekick via HTTP POST,
stores them in memory, and provides endpoints to view recent alerts.

Think of this as the arena's security operations center (SOC) where
all the camera feeds and alarms are displayed on a big board.
"""

import os
import logging
from datetime import datetime, timezone
from flask import Flask, jsonify, request

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# In-memory alert store (last N alerts)
MAX_ALERTS = 200
alerts = []

# Priority color mapping (for display)
PRIORITY_COLORS = {
    "Emergency": "🔴",
    "Alert": "🔴",
    "Critical": "🔴",
    "Error": "🟠",
    "Warning": "🟡",
    "Notice": "🔵",
    "Informational": "⚪",
    "Debug": "⚫",
}


@app.route("/")
def index():
    return jsonify(
        {
            "service": "Alert Dashboard",
            "description": "Falcosidekick webhook receiver — arena security SOC",
            "endpoints": [
                "GET /health",
                "GET /alerts",
                "GET /alerts/summary",
                "GET /alerts/critical",
                "POST /webhook (Falcosidekick target)",
                "DELETE /alerts (clear all)",
            ],
            "total_alerts": len(alerts),
        }
    )


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "total_alerts": len(alerts),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.route("/webhook", methods=["POST"])
def webhook():
    """Receive alerts from Falcosidekick."""
    data = request.get_json(silent=True) or {}

    alert = {
        "received_at": datetime.now(timezone.utc).isoformat(),
        "rule": data.get("rule", "unknown"),
        "priority": data.get("priority", "unknown"),
        "output": data.get("output", ""),
        "source": data.get("source", "falco"),
        "hostname": data.get("hostname", ""),
        "tags": data.get("tags", []),
        "output_fields": data.get("output_fields", {}),
    }

    alerts.append(alert)

    # Trim to max size
    while len(alerts) > MAX_ALERTS:
        alerts.pop(0)

    priority_icon = PRIORITY_COLORS.get(alert["priority"], "❓")
    logger.info(
        "%s [%s] %s: %s",
        priority_icon,
        alert["priority"],
        alert["rule"],
        alert["output"][:120],
    )

    return jsonify({"status": "accepted", "alert_count": len(alerts)}), 200


@app.route("/alerts")
def get_alerts():
    """Return all stored alerts, newest first."""
    limit = request.args.get("limit", 50, type=int)
    return jsonify(
        {
            "alerts": list(reversed(alerts[-limit:])),
            "total": len(alerts),
            "showing": min(limit, len(alerts)),
        }
    )


@app.route("/alerts/summary")
def alerts_summary():
    """Aggregate alert counts by rule and priority."""
    by_rule = {}
    by_priority = {}

    for a in alerts:
        rule = a["rule"]
        priority = a["priority"]
        by_rule[rule] = by_rule.get(rule, 0) + 1
        by_priority[priority] = by_priority.get(priority, 0) + 1

    return jsonify(
        {
            "total_alerts": len(alerts),
            "by_rule": dict(sorted(by_rule.items(), key=lambda x: -x[1])),
            "by_priority": by_priority,
        }
    )


@app.route("/alerts/critical")
def critical_alerts():
    """Return only Critical / Emergency / Alert priority alerts."""
    critical = [
        a for a in reversed(alerts)
        if a["priority"] in ("Emergency", "Alert", "Critical")
    ]
    return jsonify({"critical_alerts": critical, "count": len(critical)})


@app.route("/alerts", methods=["DELETE"])
def clear_alerts():
    """Clear all stored alerts."""
    count = len(alerts)
    alerts.clear()
    logger.info("Cleared %d alerts", count)
    return jsonify({"message": f"Cleared {count} alerts"})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info("Starting Alert Dashboard on port %d", port)
    app.run(host="0.0.0.0", port=port)
