#!/usr/bin/env python3
"""Vigilante de la traduccion puente: abre issues cuando hay que actuar.

Comprueba tres cosas (solo libreria estandar):
  * ultima release de Thord82/Star_citizen_ES  (tag y version del juego)
  * ultimo build LIVE de MrKraken/StarStrings  (commit "Update for build ...")
  * la ultima pre-release "bridge-*" de este repo (lineas BASE= y SS= de su descripcion)

Avisos (un issue por aviso, sin duplicados):
  1. StarStrings tiene un build mas nuevo que Thord y que el puente -> regenerar el puente.
  2. Thord publico algo posterior a la BASE del puente -> revisar el CSV y archivar el puente.

No traduce ni publica nada: solo avisa. Variables: GITHUB_TOKEN, GITHUB_REPOSITORY.
Uso: vigilante.py [--dry-run] [--fixture datos.json]
"""
import json, os, re, sys, urllib.request

THORD = 'Thord82/Star_citizen_ES'
STARSTRINGS = 'MrKraken/StarStrings'
LABEL = 'vigilante'


def version_tuple(text):
    m = re.search(r'(\d+)\.(\d+)(?:\.(\d+))?', text or '')
    return tuple(int(x or 0) for x in m.groups()) if m else None


def thord_version(release):
    """Version del juego a la que llega Thord: del nombre de la release o, si va vacio, de la descripcion."""
    for src in (release.get('name') or '', release.get('body') or ''):
        m = re.search(r'LIVE\s*(\d+\.\d+(?:\.\d+)?)', src)
        if m:
            return version_tuple(m.group(1))
    return None


def ss_latest_build(commits):
    for c in commits:
        m = re.search(r'Update for build (sc-alpha-(\d+\.\d+(?:\.\d+)?)_live_\d+)', c.get('commit', {}).get('message', ''))
        if m:
            return m.group(1), version_tuple(m.group(2))
    return None, None


def bridge_info(releases):
    for r in releases:
        if r.get('prerelease') and not r.get('draft') and str(r.get('tag_name', '')).startswith('bridge-'):
            body = r.get('body') or ''
            base = re.search(r'(?im)^\s*BASE\s*=\s*(\S+)\s*$', body)
            ss = re.search(r'(?im)^\s*SS\s*=\s*(\S+)\s*$', body)
            return {'tag': r['tag_name'], 'base': base.group(1) if base else None, 'ss': ss.group(1) if ss else None}
    return None


def decide(thord_release, ss_commits, bridge_releases):
    """Devuelve la lista de avisos [(titulo, cuerpo)]."""
    alerts = []
    tag = thord_release.get('tag_name')
    t_ver = thord_version(thord_release)
    build, s_ver = ss_latest_build(ss_commits)
    bridge = bridge_info(bridge_releases)
    norm = lambda x: re.sub(r'^v\.?', '', x or '')

    if build and s_ver and (t_ver is None or s_ver > t_ver) and not (bridge and bridge['ss'] == build):
        t_txt = '.'.join(map(str, t_ver)) if t_ver else 'desconocida'
        b_txt = f'{bridge["tag"]} (SS={bridge["ss"]})' if bridge else 'ninguno'
        alerts.append((
            f'Nuevo build de StarStrings {build}: regenerar el puente',
            f'StarStrings publico `{build}` y Thord solo llega a la version {t_txt} (release `{tag}`).\n\n'
            f'Puente actual: {b_txt}.\n\n'
            'Pasos: ver `puente/README.md` (build_puente.py con `--ss-old` = build en el que se basa Thord y '
            '`--ss-new` = este build; traducir `pendientes.json`; publicar la pre-release `bridge-*` con '
            f'`BASE={tag}` y `SS={build}`).'))
    if bridge and bridge['base'] and norm(bridge['base']) != norm(tag):
        alerts.append((
            f'Thord publico {tag}: revisar y archivar el puente {bridge["tag"]}',
            f'La release `{tag}` de Thord es posterior a la BASE (`{bridge["base"]}`) del puente `{bridge["tag"]}`. '
            'Los usuarios ya reciben la de Thord automaticamente.\n\n'
            'Pendiente: comparar `puente/<version>/revision.csv` con la traduccion de Thord para aprovechar o '
            'corregir lo que difiera, y despues borrar o dejar archivada la pre-release del puente.'))
    return alerts


def api(path, token, method='GET', data=None):
    headers = {'User-Agent': 'sc-vigilante', 'Accept': 'application/vnd.github+json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request('https://api.github.com' + path, method=method, headers=headers,
                                 data=json.dumps(data).encode() if data is not None else None)
    with urllib.request.urlopen(req) as r:
        return json.load(r)


def main(argv):
    dry = '--dry-run' in argv
    fixture = '--fixture' in argv
    repo = os.environ.get('GITHUB_REPOSITORY', 'Raksiusdev/SC-LangUPD_ES')
    token = os.environ.get('GITHUB_TOKEN')
    if fixture:
        fx = json.load(open(argv[argv.index('--fixture') + 1], encoding='utf-8'))
        thord, commits, releases, existing = fx['thord'], fx['commits'], fx['releases'], fx.get('issues', [])
    else:
        thord = api(f'/repos/{THORD}/releases/latest', token)
        commits = api(f'/repos/{STARSTRINGS}/commits?per_page=10', token)
        releases = api(f'/repos/{repo}/releases?per_page=20', token)
        existing = [] if (dry and not token) else api(f'/repos/{repo}/issues?state=all&labels={LABEL}&per_page=100', token)
    titles = {i['title'] for i in existing}
    alerts = decide(thord, commits, releases)
    for title, body in alerts:
        if title in titles:
            print(f'(ya existe) {title}')
            continue
        print(f'AVISO: {title}')
        if not dry and not fixture:
            api(f'/repos/{repo}/issues', token, 'POST', {'title': title, 'body': body, 'labels': [LABEL]})
    if not alerts:
        print('Sin novedades.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
