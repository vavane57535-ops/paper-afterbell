#!/bin/bash
# Sauvegarde les scripts d'intégration, les briefs et le script de workflow sur la branche claude/lot17-integ.
SP=/tmp/claude-0/-home-user-paper-afterbell/3b6367fd-efb2-542d-99d0-4363092d5bea/scratchpad
WF=/root/.claude/projects/-home-user-paper-afterbell/3b6367fd-efb2-542d-99d0-4363092d5bea/workflows/scripts
cd /home/user/paper-afterbell || exit 1
export GIT_INDEX_FILE=$SP/integ/.idx
git read-tree --empty
add() { local b; b=$(git hash-object -w "$1") && git update-index --add --cacheinfo 100644,$b,"$2"; }
for f in $SP/integ/*.py $SP/integ/*.sh $SP/integ/*.gd; do [ -f "$f" ] && add "$f" "integ/$(basename $f)"; done
for f in $SP/BRIEF.md $SP/BRIEF-017.md $SP/tools/backup_loop.sh; do [ -f "$f" ] && add "$f" "$(basename $f)"; done
for f in $WF/*.js; do [ -f "$f" ] && add "$f" "workflows/$(basename $f)"; done
tree=$(git write-tree)
parent=$(git rev-parse -q --verify refs/remotes/origin/claude/lot17-integ)
c=$(git commit-tree $tree ${parent:+-p $parent} -m "Intégration 0.17 : scripts et briefs ($(date -u +%H:%M))")
for a in 1 2 3 4; do git push -q origin $c:refs/heads/claude/lot17-integ && git fetch -q origin claude/lot17-integ && break; sleep $((a*2)); done
echo "integ sauvegardé : $(git rev-parse --short $c)"
