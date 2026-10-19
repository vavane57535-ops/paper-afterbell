# Paquet Windows complet : exe officiel Godot 4.5.1 + pck + docs, découpé en morceaux de 19 Mo + assemble.bat.
# Usage : package.py <exe> <pck> <dossier_docs_repo> <dossier_sortie> <version, ex. 0_17>
import hashlib, os, sys, zipfile
exe, pck, docs, out, ver = sys.argv[1:6]
name = "PaperAfterbell-%s-Windows.zip" % ver
os.makedirs(out, exist_ok=True)
zpath = os.path.join(out, name)
SKIP = {"REFERENCE-OM.md", "AUDIO-SOURCES.json"}
with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    z.write(exe, "PaperAfterbell.exe")
    z.write(pck, "PaperAfterbell.pck")
    for root, _dirs, files in os.walk(docs):
        rel = os.path.relpath(root, docs)
        if rel.split(os.sep)[0] == "Launcher": continue
        for f in sorted(files):
            if f in SKIP: continue
            arc = f if rel == "." else os.path.join(rel, f)
            z.write(os.path.join(root, f), arc)
data = open(zpath, "rb").read()
sha = hashlib.sha256(data).hexdigest()
size = len(data)
part = 19 * 1000 * 1000
parts = []
pdir = os.path.join(out, "morceaux")
os.makedirs(pdir, exist_ok=True)
for i in range(0, size, part):
    pn = "%s.part%02d" % (name, len(parts) + 1)
    open(os.path.join(pdir, pn), "wb").write(data[i:i + part])
    parts.append(pn)
joined = "+".join('"%s"' % p for p in parts)
bat = r'''@echo off
setlocal
cd /d "%~dp0"
set "ZIP=@@NAME@@"
echo Assemblage de %ZIP% a partir de @@COUNT@@ morceaux...
for %%P in (@@PARTS@@) do if not exist "%%~P" (echo Morceau manquant : %%~P & echo Mets les @@COUNT@@ morceaux et assemble.bat dans le meme dossier. & pause & exit /b 1)
copy /b @@JOINED@@ "%ZIP%" >nul
if errorlevel 1 (echo Echec de l'assemblage. & pause & exit /b 1)
for %%A in ("%ZIP%") do if not "%%~zA"=="@@SIZE@@" (echo Taille inattendue : %%~zA octets au lieu de @@SIZE@@. Un morceau est abime : retelecharge-le. & pause & exit /b 1)
set "H="
for /f "skip=1 delims=" %%L in ('certutil -hashfile "%ZIP%" SHA256') do if not defined H set "H=%%L"
set "H=%H: =%"
if /i not "%H%"=="@@SHA@@" (echo Empreinte SHA-256 differente : un morceau est abime, retelecharge-le. & pause & exit /b 1)
echo.
echo OK : %ZIP% est pret et verifie.
echo Decompresse-le entierement dans un nouveau dossier, puis lance PaperAfterbell.exe.
echo Tu peux ensuite supprimer les morceaux .partXX et ce fichier.
pause
'''
bat = (bat.replace("@@NAME@@", name).replace("@@COUNT@@", str(len(parts))).replace("@@PARTS@@", " ".join('"%s"' % p for p in parts))
       .replace("@@JOINED@@", joined).replace("@@SIZE@@", str(size)).replace("@@SHA@@", sha))
open(os.path.join(pdir, "assemble.bat"), "w", newline="\r\n").write(bat)
open(os.path.join(out, "SHA256.txt"), "w").write("%s  %s\n%d octets, %d morceaux\n" % (sha, name, size, len(parts)))
print(name, size, sha, len(parts), "morceaux")
