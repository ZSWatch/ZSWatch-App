#!/bin/sh
# Run dev_ota.py at login and expose it on the tailnet at /zswatch-ota.
set -eu

PORT="${PORT:-8787}"
LABEL=dev.zswatch.devota
# launchd may not read ~/Documents (macOS privacy), so run an installed copy.
SCRIPT="$HOME/.zswatch_dev_ota/dev_ota.py"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/.zswatch_dev_ota/server.log"
mkdir -p "$HOME/.zswatch_dev_ota" "$HOME/Library/LaunchAgents"
cp "$(dirname "$0")/dev_ota.py" "$SCRIPT"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string><string>$SCRIPT</string>
    <string>serve</string><string>--port</string><string>$PORT</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

tailscale serve --bg --set-path /zswatch-ota "http://127.0.0.1:$PORT"

HOST="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
echo "URL:   https://$HOST/zswatch-ota"
echo "Token: $(python3 "$SCRIPT" token)"
