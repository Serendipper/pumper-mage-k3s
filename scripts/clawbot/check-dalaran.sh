#!/usr/bin/env bash
# External K3s API health check (for hosts where in-cluster monitoring may be unavailable).
# Set on the service host, e.g. systemd Environment= or an EnvironmentFile:
#   K3S_CP_HEALTHCHECK_URL — default below uses RFC 5737 TEST-NET-II (documentation only); MUST override with your control-plane https://IP:6443/healthz
#   CLAWBOT_DISCORD_FALLBACK_CHANNEL — optional numeric Discord channel id for OpenClaw hook payload "to" field (omit in public forks; set in private env)
set -euo pipefail

STATE_DIR="/var/lib/clawbot-watch"
STATE_FILE="$STATE_DIR/dalaran.status"
REMINDER_FILE="$STATE_DIR/dalaran.last_alert_epoch"
TARGET_URL="${K3S_CP_HEALTHCHECK_URL:-https://198.51.100.10:6443/healthz}"
OPENCLAW_URL="http://127.0.0.1:18789/hooks/agent"
SECRETS_ENV="/opt/openclaw/data/secrets.env"
REMINDER_INTERVAL_SECONDS=3600

mkdir -p "$STATE_DIR"

status="up"
http_code="000"
if ! http_code=$(curl -k -sS -o /dev/null -m 8 -w "%{http_code}" "$TARGET_URL"); then
  status="down"
elif [ "$http_code" != "200" ] && [ "$http_code" != "401" ] && [ "$http_code" != "403" ]; then
  status="down"
fi

prev="unknown"
if [ -f "$STATE_FILE" ]; then
  prev=$(<"$STATE_FILE")
fi

echo "$status" > "$STATE_FILE"

should_alert=0
alert_kind="none"
now_epoch=$(date +%s)

if [ "$status" != "$prev" ]; then
  should_alert=1
  alert_kind="transition"
elif [ "$status" = "down" ]; then
  last_alert_epoch=0
  if [ -f "$REMINDER_FILE" ]; then
    last_alert_epoch=$(<"$REMINDER_FILE")
  fi
  if [ $((now_epoch - last_alert_epoch)) -ge "$REMINDER_INTERVAL_SECONDS" ]; then
    should_alert=1
    alert_kind="reminder"
  fi
fi

if [ "$should_alert" -ne 1 ]; then
  exit 0
fi

token=$(python3 - <<'PY2'
import json
with open('/opt/openclaw/data/.openclaw/openclaw.json', encoding='utf-8') as f:
    cfg = json.load(f)
print(cfg.get('hooks', {}).get('token', ''), end='')
PY2
)

if [ -z "$token" ]; then
  exit 1
fi

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [ "$status" = "down" ]; then
  if [ "$alert_kind" = "reminder" ]; then
    msg="[CRITICAL][REMINDER] dalaran API still DOWN (checker: clawbot external monitor, ts=$now, code=$http_code, target=$TARGET_URL)"
  else
    msg="[CRITICAL] dalaran API appears DOWN (checker: clawbot external monitor, ts=$now, code=$http_code, target=$TARGET_URL)"
  fi
else
  msg="[RESOLVED] dalaran API recovered (checker: clawbot external monitor, ts=$now, code=$http_code, target=$TARGET_URL)"
fi

# Prefer direct Discord webhook delivery when configured on the host.
discord_webhook=""
if [ -r "$SECRETS_ENV" ]; then
  discord_webhook=$(python3 - <<'PY3'
from pathlib import Path

for line in Path('/opt/openclaw/data/secrets.env').read_text(encoding='utf-8').splitlines():
    if line.startswith('SENSE_DISCORD_WEBHOOK_URL='):
        print(line.split('=', 1)[1].strip().strip('"'), end='')
        break
PY3
)
fi

if [ -n "$discord_webhook" ]; then
  curl -sS -m 10 -X POST "$discord_webhook" \
    -H 'Content-Type: application/json' \
    -d "{\"content\":\"$msg\"}" >/dev/null
  if [ "$status" = "down" ]; then
    echo "$now_epoch" > "$REMINDER_FILE"
  else
    rm -f "$REMINDER_FILE"
  fi
  exit 0
fi

# Fallback to OpenClaw hooks if no direct webhook is configured.
export CLAWBOT_MSG="$msg"
payload=$(CLAWBOT_DISCORD_FALLBACK_CHANNEL="${CLAWBOT_DISCORD_FALLBACK_CHANNEL:-}" python3 <<'PY'
import json, os
msg = os.environ["CLAWBOT_MSG"]
ch = os.environ.get("CLAWBOT_DISCORD_FALLBACK_CHANNEL", "").strip()
body = {"message": msg, "deliver": True, "channel": "discord"}
if ch:
    body["to"] = f"channel:{ch}"
print(json.dumps(body))
PY
)
curl -sS -m 10 -X POST "$OPENCLAW_URL" \
  -H "Authorization: Bearer $token" \
  -H 'Content-Type: application/json' \
  -d "$payload" >/dev/null

if [ "$status" = "down" ]; then
  echo "$now_epoch" > "$REMINDER_FILE"
else
  rm -f "$REMINDER_FILE"
fi
