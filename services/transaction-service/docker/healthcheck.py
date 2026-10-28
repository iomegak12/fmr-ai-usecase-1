#!/usr/bin/env python3
"""Container health probe: exit 0 only when the given path returns HTTP 200.

Usage: healthcheck [path]
    healthcheck /health   liveness (the image HEALTHCHECK)
    healthcheck /ready    readiness, including transaction_db (Compose health checks)
"""

import os
import sys
import urllib.request

path = sys.argv[1] if len(sys.argv) > 1 else "/health"
port = os.environ.get("TXN_SERVICE_PORT", "8000")
try:
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=2) as response:
        sys.exit(0 if response.status == 200 else 1)
except OSError:  # includes URLError and HTTPError (for example 503 from /ready)
    sys.exit(1)
