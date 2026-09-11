"""Rapport Sentry PharmaScan — lit les issues non résolues + détails.

Usage : python scripts/sentry_report.py [--details]
Token lu dans le .env du projet (SENTRY_TOKEN).
"""
import json
import os
import sys
import urllib.request

ORG = 'softhubapp'
PROJECT = 'pharmascan'
API = f'https://{ORG}.sentry.io/api/0'


def load_token() -> str:
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    for line in open(path, encoding='utf-8'):
        if line.startswith('SENTRY_TOKEN='):
            return line.split('=', 1)[1].strip()
    raise SystemExit('SENTRY_TOKEN absent du .env du projet')


def api_get(path: str) -> object:
    req = urllib.request.Request(
        f'{API}{path}',
        headers={'Authorization': f'Bearer {load_token()}',
                 'Accept': 'application/json',
                 'User-Agent': 'Mozilla/5.0 (PharmaScan report)'})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    details = '--details' in sys.argv
    issues = api_get(
        '/projects/%s/%s/issues/?query=is:unresolved'
        '&sort=date&limit=15&statsPeriod=14d' % (ORG, PROJECT))
    print(f"{len(issues)} issues non résolues (30 jours)\n")
    for i in issues:
        stats = i.get('stats', {})
        print(f"- {i.get('shortId')} | {i.get('title', '?')[:80]}")
        print(f"    users affectés: {stats.get('userCount', '?')} · "
              f"events: {i.get('count', '?')} · "
              f"dernier: {i.get('lastSeen', '?')[:10]}")
        if details:
            events = api_get(f"/issues/{i.get('id')}/events/?full=true&limit=1")
            for e in (events if isinstance(events, list) else []):
                for en in e.get('entries', []):
                    if en.get('type') != 'exception':
                        continue
                    for v in en.get('data', {}).get('values', [])[:1]:
                        print(f"    -> {v.get('type')} | "
                              f"{(v.get('value') or '')[:100]}")
                        frames = (v.get('stacktrace') or {}).get('frames', [])
                        for f in frames[-3:]:
                            mod = f.get('module', '')
                            fn = f.get('function', '?')
                            file = f.get('filename', '')
                            line = f.get('lineno', '')
                            print(f"       {mod}.{fn} ({file}:{line})")
                tags = {t.get('key'): t.get('value') for t in e.get('tags', [])}
                print(f"    device: {tags.get('device.model', '?')} · "
                      f"release: {tags.get('release', '?')} · "
                      f"env: {tags.get('environment', '?')}")
    print()


if __name__ == '__main__':
    main()
