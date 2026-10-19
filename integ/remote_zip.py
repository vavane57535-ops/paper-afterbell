# Extrait un seul fichier d'un ZIP distant par requêtes Range (évite de télécharger 1 Go).
import io, sys, zipfile, urllib.request, ssl, os
url, member, out = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = ssl.create_default_context(cafile=os.environ.get("SSL_CERT_FILE") or "/root/.ccr/ca-bundle.crt")
opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))
def get(start, end):
    req = urllib.request.Request(url, headers={"Range": "bytes=%d-%d" % (start, end)})
    with opener.open(req, timeout=120) as r:
        return r.read()
req = urllib.request.Request(url, method="HEAD")
with opener.open(req, timeout=60) as r:
    size = int(r.headers["Content-Length"]); final = r.geturl()
url = final
print("taille", size)
class RF(io.RawIOBase):
    def __init__(s): s.pos = 0
    def seekable(s): return True
    def readable(s): return True
    def seek(s, off, wh=0):
        s.pos = off if wh == 0 else (s.pos + off if wh == 1 else size + off); return s.pos
    def tell(s): return s.pos
    def readinto(s, b):
        n = min(len(b), size - s.pos)
        if n <= 0: return 0
        d = get(s.pos, s.pos + n - 1); b[:len(d)] = d; s.pos += len(d); return len(d)
z = zipfile.ZipFile(io.BufferedReader(RF(), buffer_size=1 << 20))
names = z.namelist()
m = [n for n in names if n.endswith(member)]
print("trouvé", m)
with z.open(m[0]) as src, open(out, "wb") as dst:
    while True:
        d = src.read(1 << 22)
        if not d: break
        dst.write(d)
print("ok", os.path.getsize(out))
