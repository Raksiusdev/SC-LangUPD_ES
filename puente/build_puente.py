#!/usr/bin/env python3
"""Genera el zip "puente": traduccion de Thord + textos nuevos de StarStrings.

Cuando el juego sube de version, StarStrings (MrKraken) actualiza su global.ini en ingles
y Thord82 tarda unos dias en publicar su traduccion. Este script toma la traduccion
publicada de Thord (basada en el build anterior de StarStrings) y la pone al dia:

  * claves que no cambiaron entre los dos builds de StarStrings -> texto de Thord intacto
  * claves nuevas o cambiadas -> las del archivo de traducciones (nuevas.json / cambiadas.json)
  * claves eliminadas -> se quitan

Uso:
  python build_puente.py --ss-old SHA_ANTERIOR --ss-new SHA_NUEVO \
      --thord-zip Star_citizen_ES.zip --traducciones 4.10.2 --salida salida/

Si faltan traducciones escribe pendientes.json (clave -> ingles) y termina con codigo 2.
Solo usa la libreria estandar.
"""
import argparse, json, os, sys, urllib.request, zipfile

SS_PATH = 'src/For_Players/Data/Localization/english/global.ini'
LIVE_INI = 'LIVE/data/Localization/spanish_(spain)/global.ini'


def fetch_ss(sha):
    url = f'https://raw.githubusercontent.com/MrKraken/StarStrings/{sha}/{SS_PATH}'
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'sc-puente'})) as r:
        return r.read().decode('utf-8-sig')


def parse(text):
    d = {}
    for line in text.split('\n'):
        line = line.rstrip('\r')
        if '=' in line:
            k, v = line.split('=', 1)
            d[k] = v
    return d


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ss-old', required=True, help='commit de StarStrings del que parte la traduccion de Thord')
    ap.add_argument('--ss-new', required=True, help='commit de StarStrings al que se quiere llegar')
    ap.add_argument('--thord-zip', required=True)
    ap.add_argument('--traducciones', required=True, help='carpeta con nuevas.json y cambiadas.json')
    ap.add_argument('--salida', required=True)
    a = ap.parse_args()

    en_old_text, en_new_text = fetch_ss(a.ss_old), fetch_ss(a.ss_new)
    en_old, en_new = parse(en_old_text), parse(en_new_text)
    zin = zipfile.ZipFile(a.thord_zip)
    thord = parse(zin.read(LIVE_INI).decode('utf-8-sig'))
    if set(thord) != set(en_old):
        print(f'AVISO: las claves de Thord no coinciden con StarStrings {a.ss_old[:10]} '
              f'(faltan {len(set(en_old) - set(thord))}, sobran {len(set(thord) - set(en_old))}); '
              'el puente podria no corresponder a esa base', file=sys.stderr)

    def load(name):
        p = os.path.join(a.traducciones, name)
        return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else {}
    nuevas, cambiadas = load('nuevas.json'), load('cambiadas.json')

    add = [k for k in en_new if k not in en_old]
    chg = [k for k in en_new if k in en_old and en_old[k] != en_new[k]]
    pend = {k: en_new[k] for k in add if k not in nuevas}
    pend.update({k: en_new[k] for k in chg if k not in cambiadas and k in thord})
    if pend:
        os.makedirs(a.salida, exist_ok=True)
        json.dump(pend, open(os.path.join(a.salida, 'pendientes.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        print(f'Faltan {len(pend)} traducciones: ver pendientes.json', file=sys.stderr)
        return 2

    out, huerfanas = [], 0
    for line in en_new_text.split('\n'):
        line = line.rstrip('\r')
        if '=' not in line:                 # cadena partida en origen: se descartan las continuaciones
            if line.strip():
                huerfanas += 1
            else:
                out.append(line)
            continue
        k = line.split('=', 1)[0]
        v = nuevas.get(k, cambiadas.get(k, thord.get(k)))
        if v is None:
            raise SystemExit(f'clave sin traduccion ni origen en Thord: {k}')
        out.append(f'{k}={v}')
    while out and out[-1] == '':
        out.pop()
    data = b'\xef\xbb\xbf' + ('\r\n'.join(out) + '\r\n').encode('utf-8')

    os.makedirs(a.salida, exist_ok=True)
    zp = os.path.join(a.salida, 'Star_citizen_ES.zip')       # el nombre lo exige el script
    with zipfile.ZipFile(zp, 'w', zipfile.ZIP_DEFLATED) as z:
        for n in zin.namelist():
            if not n.endswith('/'):
                z.writestr(n, data if n == LIVE_INI else zin.read(n))
    print(f'{len(add)} nuevas, {len(chg)} cambiadas, {len(set(en_old) - set(en_new))} eliminadas, '
          f'{huerfanas} lineas huerfanas descartadas -> {zp}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
