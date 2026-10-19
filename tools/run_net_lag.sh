#!/usr/bin/env bash
# Test de retard réseau : relais (ping + jitter simulés), hôte et client headless, puis analyse.
#   tools/run_net_lag.sh DOSSIER PING_MS JITTER_MS [ÉTIQUETTE] [PORT_DE_BASE]
# Exemple : tools/run_net_lag.sh /tmp/lag50 50 6 apres 28511
# Le relais écoute sur PORT_DE_BASE+1 et renvoie vers l'hôte (PORT_DE_BASE) ; le jeu n'utilise
# pas son port habituel, pour ne pas gêner d'autres parties locales.
set -u
OUT=$(realpath -m "$1"); PING=$2; JITTER=$3; LABEL=${4:-run}; BASE=${5:-28511}
HOST_PORT=$BASE; PROXY_PORT=$((BASE + 1))
ROOT=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$OUT/xdg_host" "$OUT/xdg_client"
rm -f "$OUT/host.json" "$OUT/client.json"
cd "$ROOT"
python3 tools/net_lag_proxy.py --listen "$PROXY_PORT" --target "$HOST_PORT" --ping "$PING" --jitter "$JITTER" --duration 230 --stats "$OUT/proxy.json" > "$OUT/proxy.log" 2>&1 &
PROXY=$!
sleep 0.5
XDG_DATA_HOME="$OUT/xdg_host" timeout 220 godot --headless -- --tool test_net_lag --lag-role host --lag-port "$HOST_PORT" --lag-out "$OUT" --lag-label "$LABEL" ${LAG_EXTRA:-} > "$OUT/host.log" 2>&1 &
HOST_PID=$!
sleep 2
XDG_DATA_HOME="$OUT/xdg_client" timeout 215 godot --headless -- --tool test_net_lag --lag-role client --lag-port "$PROXY_PORT" --lag-out "$OUT" --lag-label "$LABEL" > "$OUT/client.log" 2>&1 &
CLIENT_PID=$!
wait "$HOST_PID"; wait "$CLIENT_PID"
kill -TERM "$PROXY" 2>/dev/null; wait "$PROXY" 2>/dev/null
grep -h -E "SCRIPT ERROR|Parse Error" "$OUT/host.log" "$OUT/client.log" | head -5
python3 tools/net_lag_report.py "$OUT" --ping "$PING" --jitter "$JITTER" --label "$LABEL" | tee "$OUT/report.txt"
