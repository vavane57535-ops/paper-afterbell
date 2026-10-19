#!/bin/bash
# Sauvegarde des branches de lots sur GitHub toutes les 10 minutes (miroir forcé claude/lot17-<axe>).
cd /home/user/paper-afterbell || exit 1
end=$(( $(date +%s) + ${1:-7000} ))
while [ $(date +%s) -lt $end ]; do
  for k in menus textes simon yiero prologue_a prologue_b lms_wins lms_losses team_blocus cartes reseau; do
    git rev-parse -q --verify lot17-$k >/dev/null || continue
    for attempt in 1 2 3; do
      git push -q origin +lot17-$k:refs/heads/claude/lot17-$k >/dev/null 2>&1 && break
      sleep $((attempt * 4))
    done
  done
  echo "$(date -u +%H:%M) sauvegarde faite"
  sleep 600
done
