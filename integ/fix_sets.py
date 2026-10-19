# Résout le conflit de anim_library.gd : SETS = union ordonnée des listes des deux côtés.
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
pat = re.compile(r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n", re.S)
def names(block):
    return re.findall(r'"([^"]+)"', block)
def repl(m):
    a, b = m.group(1), m.group(2)
    if "const SETS" not in a and "const SETS" not in b:
        raise SystemExit("conflit hors SETS: " + p)
    out = []
    for n in names(a) + names(b):
        if n not in out: out.append(n)
    return "const SETS: Array[String] = [" + ", ".join('"%s"' % n for n in out) + "]\n"
s2, n = pat.subn(repl, s)
if "<<<<<<<" in s2: raise SystemExit("conflit restant")
open(p, "w", encoding="utf-8").write(s2)
print("SETS résolu (%d bloc)" % n)
