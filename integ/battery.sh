#!/bin/bash
# Batterie d'intégration 0.17 (sans rendu).
# Usage : battery.sh <racine_projet> <dossier_sortie> [groupes : errors sims tools net] ; JOBS=3 par défaut.
ROOT=$1; OUT=$2; shift 2
GROUPS_=${*:-errors sims tools net}
export XDG_DATA_HOME=$OUT/xdg
mkdir -p "$OUT/logs" "$XDG_DATA_HOME"
cd "$ROOT" || exit 1
: > "$OUT/summary.txt"
J=${JOBS:-3}
pool() { while [ "$(jobs -rp | wc -l)" -ge "$J" ]; do wait -n; done; }
errs() { grep -E "SCRIPT ERROR|Parse Error|ERROR:" "$1" | grep -v -i -E "alsa|audio driver|pulseaudio|resources still in use|ObjectDB instances leaked"; }
run() { # nom délai args...
	local name=$1 to=$2; shift 2
	local t0=$(date +%s)
	timeout "$to" nice -n 5 godot "$@" > "$OUT/logs/$name.log" 2>&1
	local rc=$?
	local e; e=$(errs "$OUT/logs/$name.log" | wc -l)
	local res; res=$(grep -E "FAIL|PASS|RESULT|ÉCHEC|ECHEC" "$OUT/logs/$name.log" | grep -v -E "^\s*#" | tail -3 | tr '\n' ' ' | cut -c1-300)
	echo "$name rc=$rc erreurs=$e durée=$(( $(date +%s) - t0 ))s ${res}" >> "$OUT/summary.txt"
}
if [[ " $GROUPS_ " == *" errors "* ]]; then
	run demarrage 240 --headless --quit-after 400
fi
if [[ " $GROUPS_ " == *" sims "* ]]; then
	i=0
	for spec in "Simon school 60 x" "Usayuko forest 60 x" "Ashura snow 60 x" "Lysia school 60 x" "Elly forest 60 x" "Bleuette snow 60 x" "Alice school 60 x" \
		"Bleuette school 220 lms" "Usayuko forest 220 lms" "Alice snow 700 killer_win" "Simon forest 60 survivor_win" "Ashura school 380 full"; do
		set -- $spec; i=$((i+1))
		extra=(); sp=(); [ "$4" = "lms" ] || [ "$4" = "killer_win" ] || [ "$4" = "survivor_win" ] && extra=(--scenario "$4")
		[ "$3" -gt 100 ] && sp=(--speed 4)
		pool; run "sim_$1_$2_$4" 900 --headless -- --simulate "$1" --map "$2" --duration "$3" "${sp[@]}" "${extra[@]}" --seed $((40 + i)) --report "$OUT/sim_$1_$2_$4.json" &
	done
	wait
	python3 - "$OUT" >> "$OUT/summary.txt" <<'PY'
import json, glob, math, sys, os
for p in sorted(glob.glob(os.path.join(sys.argv[1], "sim_*.json"))):
    try: d = json.load(open(p))
    except Exception as e:
        print("RAPPORT ILLISIBLE", os.path.basename(p), e); continue
    bad = []
    for a in d.get("actors", []):
        x, y, z = a["position"]
        if any(math.isnan(v) for v in (x, y, z)) or y < -3 or y > 60: bad.append("%s y=%.1f" % (a["character"], y))
    print("RAPPORT %-34s phase=%s issue=%s temps=%.0f reste=%.0f lms=%s acteurs=%d %s" % (os.path.basename(p), d.get("phase"), d.get("outcome"), d.get("time", 0), d.get("remaining", 0), d.get("lms"), len(d.get("actors", [])), ("HORS CARTE: " + ", ".join(bad)) if bad else "positions ok"))
PY
fi
if [[ " $GROUPS_ " == *" tools "* ]]; then
	pool; run t_mechanics 600 --headless -- --simulate Lysia --duration 400 --speed 3 --tool test_mechanics &
	pool; run t_training_lms 300 --headless -- --tool test_training_lms &
	pool; run t_kills 900 --headless -- --tool test_kills --kill all --both &
	pool; run t_intro_scan 900 --headless -- --tool test_intro --intro-mode scan &
	pool; run t_menu_nav 300 --headless -- --tool test_menu_nav &
	pool; run t_menu_perf 300 --headless -- --tool test_menu_perf &
	pool; run t_menu_i18n 400 --headless -- --tool test_menu_i18n --i18n-all &
	pool; run t_ingame_i18n 300 --headless -- --tool test_ingame_i18n &
	pool; run t_gender 300 --headless -- --tool test_gender_labels &
	pool; run t_crosscode 900 --headless -- --tool test_crosscode &
	pool; run t_forfeit 400 --headless -- --tool test_forfeit_solo &
	pool; run t_victory_lms 600 --headless -- --simulate Simon --scenario lms --speed 4 --duration 200 --tool test_victory_lms &
	pool; run t_camera 400 --headless -- --tool test_camera --out "$OUT/camera" &
	pool; run t_badge 300 --headless -- --simulate Simon --duration 60 --tool test_ingame_badge &
	pool; run t_collage 300 --headless -- --tool test_collage_titles --ct-all &
	pool; run t_ingame_mix 400 --headless -- --simulate Simon --duration 120 --tool test_ingame_mix &
	pool; run t_exit 400 --headless -- --simulate Simon --duration 70 --tool test_exit --exit-plan quick &
	wait
fi
if [[ " $GROUPS_ " == *" net "* ]]; then
	port=28417
	for sc in client_alice host_alice lobby_reset bot_alice leader; do
		port=$((port+1))
		run "n_alice_${sc}_host" 240 --headless -- --tool test_network_alice --alice-role host --alice-scenario $sc --alice-port $port &
		sleep 3
		run "n_alice_${sc}_client" 240 --headless -- --tool test_network_alice --alice-role client --alice-scenario $sc --alice-port $port &
		wait
	done
	port=$((port+1))
	run n_alice_trio_host 240 --headless -- --tool test_network_alice --alice-role host --alice-scenario trio --alice-port $port &
	sleep 3; run n_alice_trio_client1 240 --headless -- --tool test_network_alice --alice-role client --alice-scenario trio --alice-port $port &
	sleep 2; run n_alice_trio_client2 240 --headless -- --tool test_network_alice --alice-role client --alice-scenario trio --alice-port $port &
	wait
	pair() { # nom hôte_args -- client_args
		local name=$1; shift; local h=() c=(); while [ "$1" != "--" ]; do h+=("$1"); shift; done; shift; c=("$@")
		run "${name}_host" 300 --headless -- --host-test "${h[@]}" &
		sleep 3
		run "${name}_client" 300 --headless -- --join-test "${c[@]}" &
		wait
	}
	pair n_emote --duration 45 --tool test_emote_net -- --duration 40 --tool test_emote_net --out "$OUT/emote_net"
	pair n_kills --duration 70 --tool test_kills_net -- --duration 66 --tool test_kills_net
	pair n_victory --tool test_victory_net --vnet host -- --tool test_victory_net --vnet client
	pair n_camera --duration 30 --tool test_camera_net -- --duration 27 --tool test_camera_net
	pair n_effects --duration 120 --tool test_mechanics -- --duration 110 --tool watch_net_effects
fi
echo "FIN $(date -u +%H:%M)" >> "$OUT/summary.txt"
