# Géocode les pharmacies Firestore (adresse/commune → lat/lng) via Nominatim.
# 1. --sample 10 : vérifier la qualité sur un échantillon (rien écrit)
# 2. --write : géocodage complet + écriture lat/lng dans Firestore
import argparse
import json
import time
import urllib.parse
import urllib.request

import firebase_admin
from firebase_admin import credentials, firestore

UA = {'User-Agent': 'PharmaScan/1.0 (geocoding pharmacies CI; contact: tobossinonleonard@gmail.com)'}
SA_KEY = r'C:\Users\LEO\projects\pharmascan\play\firebase-adminsdk.json'
NOMINATIM = 'https://nominatim.openstreetmap.org/search'


def geocode(query: str) -> dict | None:
    """Géocode une requête → {'lat', 'lon', 'display'} ou None."""
    params = urllib.parse.urlencode({'q': query, 'format': 'json', 'limit': 1,
                                     'countrycodes': 'ci'})
    req = urllib.request.Request(f'{NOMINATIM}?{params}', headers=UA)
    try:
        data = json.loads(urllib.request.urlopen(req, timeout=30).read().decode())
    except Exception:
        return None
    if not data:
        return None
    d = data[0]
    return {'lat': float(d['lat']), 'lon': float(d['lon']), 'display': d.get('display_name', '')}


def clean_commune(commune: str | None) -> str:
    """Coupe aux repères d'adresse (« FACE », « APRES », « / »...) hérités
    du parsing PDF — ils polluent la requête Nominatim."""
    if not commune:
        return ''
    c = commune
    for token in ('FACE', 'APRES', 'PRES ', 'CARREFOUR', 'ROUTE', 'AVENUE',
                  'BOULEVARD', 'RUE ', 'TEL', 'ENTRE', 'DERRIERE', '/'):
        i = c.upper().find(token)
        if i > 0:
            c = c[:i].strip()
    return c[:30].strip() if len(c) > 30 else c.strip()


def queries_for(name: str, commune: str | None, address: str | None):
    """Cascade de requêtes : pharmacie+commune → pharmacie seule →
    commune seule. La commune est nettoyée de ses repères."""
    qs = []
    commune = clean_commune(commune)
    if name and commune:
        qs.append(f'Pharmacie {name}, {commune}, Abidjan, Côte d\'Ivoire')
    if name:
        qs.append(f'Pharmacie {name}, Côte d\'Ivoire')
    if commune:
        qs.append(f'{commune}, Abidjan, Côte d\'Ivoire')
    return qs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sample', type=int, default=0, help='N pharmacies à tester (sans écriture)')
    ap.add_argument('--write', action='store_true', help='Écrire lat/lng dans Firestore')
    ap.add_argument('--limit', type=int, default=0, help='Limite du nombre de pharmacies à traiter')
    args = ap.parse_args()

    if not firebase_admin._apps:
        cred = credentials.Certificate(SA_KEY)
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    pharms = list(db.collection('pharmacies').get())
    print(f'Pharmacies dans Firestore: {len(pharms)}')

    to_process = [p for p in pharms
                  if not p.to_dict().get('lat') or not p.to_dict().get('lng')]
    print(f'Sans coordonnées: {len(to_process)}')

    if args.sample > 0:
        to_process = to_process[:args.sample]
    if args.limit > 0:
        to_process = to_process[:args.limit]

    ok = fail = skipped = 0
    for p in to_process:
        d = p.to_dict()
        name = d.get('name', '')
        commune = d.get('commune')
        address = d.get('address')
        result = None
        for q in queries_for(name, commune, address):
            result = geocode(q)
            if result:
                break
            time.sleep(1.1)  # Nominatim ToS : max 1 req/s
        if result:
            if args.write:
                p.reference.update({'lat': result['lat'], 'lng': result['lon']})
            ok += 1
            print(f'  ✅ {name[:38]:38s} → {result["lat"]:.5f},{result["lon"]:.5f} '
                  f'({result["display"][:40]}...)')
        else:
            fail += 1
            print(f'  ❌ {name[:38]:38s} → introuvable (commune: {commune})')
        time.sleep(1.1)

    print(f'\nRésultat: {ok} OK, {fail} échoués' +
          (' | ÉCRIT dans Firestore' if args.write else ' | TEST (rien écrit)'))


if __name__ == '__main__':
    main()
