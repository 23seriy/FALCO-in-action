"""
Arena Security API — NBA arena security monitoring service.

A compliant, well-behaved microservice that serves as the "good citizen"
in the Falco demo. It provides arena security status, incident reports,
and fan safety information.

This app does NOT trigger any Falco rules — it's the baseline showing
what normal, secure behavior looks like.
"""

import os
import json
import logging
from datetime import datetime, timezone
from flask import Flask, jsonify, request

app = Flask(__name__)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "v1")

# --- In-memory data -----------------------------------------------------------

ARENAS = {
    "TD Garden": {"city": "Boston", "capacity": 19156, "team": "Celtics"},
    "Crypto.com Arena": {"city": "Los Angeles", "capacity": 18997, "team": "Lakers"},
    "Madison Square Garden": {"city": "New York", "capacity": 19812, "team": "Knicks"},
    "United Center": {"city": "Chicago", "capacity": 20917, "team": "Bulls"},
    "Chase Center": {"city": "San Francisco", "capacity": 18064, "team": "Warriors"},
    "Barclays Center": {"city": "Brooklyn", "capacity": 17732, "team": "Nets"},
}

SECURITY_ZONES = [
    {"zone": "Gate A", "status": "secure", "officers": 4, "cameras": 8},
    {"zone": "Gate B", "status": "secure", "officers": 3, "cameras": 6},
    {"zone": "Gate C", "status": "secure", "officers": 4, "cameras": 8},
    {"zone": "Gate D", "status": "secure", "officers": 3, "cameras": 6},
    {"zone": "Court Level", "status": "secure", "officers": 6, "cameras": 12},
    {"zone": "VIP Lounge", "status": "secure", "officers": 2, "cameras": 4},
    {"zone": "Press Box", "status": "secure", "officers": 1, "cameras": 4},
    {"zone": "Locker Rooms", "status": "restricted", "officers": 2, "cameras": 6},
]

RECENT_INCIDENTS = [
    {
        "id": 1,
        "type": "unauthorized_access",
        "zone": "Locker Rooms",
        "description": "Fan attempted to enter locker room area without credentials",
        "severity": "medium",
        "resolved": True,
        "timestamp": "2025-06-10T19:45:00Z",
    },
    {
        "id": 2,
        "type": "suspicious_package",
        "zone": "Gate B",
        "description": "Unattended bag found at Gate B — cleared by security",
        "severity": "high",
        "resolved": True,
        "timestamp": "2025-06-10T20:12:00Z",
    },
    {
        "id": 3,
        "type": "crowd_disturbance",
        "zone": "Court Level",
        "description": "Minor altercation between fans in Section 112",
        "severity": "low",
        "resolved": True,
        "timestamp": "2025-06-10T21:30:00Z",
    },
]


# --- Routes -------------------------------------------------------------------


@app.route("/")
def index():
    return jsonify(
        {
            "service": "Arena Security API",
            "version": APP_VERSION,
            "description": "NBA arena security monitoring and incident reporting",
            "endpoints": [
                "GET /health",
                "GET /arenas",
                "GET /security/zones",
                "GET /security/incidents",
                "GET /security/status",
                "POST /security/incidents",
            ],
        }
    )


@app.route("/health")
def health():
    return jsonify(
        {
            "status": "healthy",
            "version": APP_VERSION,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    )


@app.route("/arenas")
def arenas():
    return jsonify({"arenas": ARENAS, "count": len(ARENAS)})


@app.route("/security/zones")
def security_zones():
    return jsonify(
        {
            "zones": SECURITY_ZONES,
            "total_officers": sum(z["officers"] for z in SECURITY_ZONES),
            "total_cameras": sum(z["cameras"] for z in SECURITY_ZONES),
        }
    )


@app.route("/security/incidents")
def incidents():
    return jsonify(
        {
            "incidents": RECENT_INCIDENTS,
            "total": len(RECENT_INCIDENTS),
            "unresolved": sum(1 for i in RECENT_INCIDENTS if not i["resolved"]),
        }
    )


@app.route("/security/incidents", methods=["POST"])
def report_incident():
    data = request.get_json(silent=True) or {}
    incident = {
        "id": len(RECENT_INCIDENTS) + 1,
        "type": data.get("type", "unknown"),
        "zone": data.get("zone", "Unknown"),
        "description": data.get("description", "No description provided"),
        "severity": data.get("severity", "low"),
        "resolved": False,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    RECENT_INCIDENTS.append(incident)
    logger.info("New incident reported: %s in %s", incident["type"], incident["zone"])
    return jsonify({"message": "Incident reported", "incident": incident}), 201


@app.route("/security/status")
def security_status():
    secure_zones = sum(1 for z in SECURITY_ZONES if z["status"] == "secure")
    total_zones = len(SECURITY_ZONES)
    threat_level = "LOW" if secure_zones == total_zones else "ELEVATED"

    return jsonify(
        {
            "overall_threat_level": threat_level,
            "secure_zones": secure_zones,
            "total_zones": total_zones,
            "active_officers": sum(z["officers"] for z in SECURITY_ZONES),
            "active_cameras": sum(z["cameras"] for z in SECURITY_ZONES),
            "open_incidents": sum(1 for i in RECENT_INCIDENTS if not i["resolved"]),
            "arena": "TD Garden",
            "game_status": "IN PROGRESS — Q3 4:22",
            "version": APP_VERSION,
        }
    )


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    logger.info("Starting Arena Security API %s on port %d", APP_VERSION, port)
    app.run(host="0.0.0.0", port=port)
