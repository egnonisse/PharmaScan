#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Scraper UNPPCI — pharmacies de garde (paramétrable).

Télécharge le PDF officiel du tour de garde d'un mois donné (UNPPCI),
le parse (semaine → section → quartier → pharmacie + titulaire + téléphones
+ adresse) et exporte en JSON/CSV. Option de synchro Firestore.

Usage:
    python scraper_unppci.py --mois 8 --annee 2026                 # export JSON
    python scraper_unppci.py --mois 9 --annee 2026 --format csv    # export CSV
    python scraper_unppci.py --dernier                             # mois courant
    python scraper_unppci.py --mois 8 --annee 2026 --sync-firestore --sa-key chemin/cle.json
"""
import argparse
import json
import re
import sys
import time
import urllib.request
from datetime import date, timedelta
from pathlib import Path

import fitz  # pymupdf

UA = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/125.0'}
BASE = 'https://www.unppci.org'

MOIS_INDEX = {
    1: 'JANVIER', 2: 'FEVRIER', 3: 'MARS', 4: 'AVRIL', 5: 'MAI', 6: 'JUIN',
    7: 'JUILLET', 8: 'AOUT', 9: 'SEPTEMBRE', 10: 'OCTOBRE', 11: 'NOVEMBRE',
    12: 'DECEMBRE',
}

# --- Parsing du PDF (format validé sur 70 PDFs, 2017-2026) ---

SEMAINE_RE = re.compile(r'SEMAINE DU\s+(.+)', re.I)
SECTION_RE = re.compile(r'^SECTION\b', re.I)
PHCIE_RE = re.compile(r'^PHCIE\s+(.+)$', re.I)
IGNORE = {'TOUR', 'PERMANENCE', 'PERMANENCES', '24', 'H/24', 'H/24H'}


def parse_gardes(pdf_path: Path) -> list[dict]:
    """Parse un PDF de garde en liste de dicts structurés.

    Retourne : [{ 'mois': 8, 'annee': 2026, 'semaine_debut': '2026-08-01',
                  'semaine_fin': '2026-08-07', 'section': ..., 'quartier': ...,
                  'pharmacie': ..., 'titulaire': ..., 'telephones': [...],
                  'adresse': ... }]
    """
    doc = fitz.open(str(pdf_path))
    lines = [l.strip() for p in doc for l in p.get_text().split('\n') if l.strip()]

    # Déterminer le mois/année du PDF
    head = '\n'.join(lines[:20]).upper()
    m = re.search(r'(JANVIER|FEVRIER|MARS|AVRIL|MAI|JUIN|JUILLET|AOUT|SEPTEMBRE|'
                  r'OCTOBRE|NOVEMBRE|DECEMBRE)\s+(\d{4})', head)
    mois, annee = None, None
    if m:
        for k, v in MOIS_INDEX.items():
            if v == m.group(1):
                mois = k
        annee = int(m.group(2))

    gardes = []
    cur_week = cur_section = cur_quartier = None
    cur_phcie = None  # dict en cours

    def flush_phcie():
        nonlocal cur_phcie
        if cur_phcie and cur_phcie.get('pharmacie'):
            gardes.append(cur_phcie)
        cur_phcie = None

    for line in lines:
        m = SEMAINE_RE.match(line)
        if m:
            flush_phcie()
            cur_week = m.group(1).strip()
            cur_section = cur_quartier = None
            continue
        if SECTION_RE.match(line):
            flush_phcie()
            cur_section = line.strip()
            cur_quartier = None
            continue
        m = PHCIE_RE.match(line)
        if m:
            flush_phcie()
            # 'NOM / TITULAIRE - TEL. 01 02...' ou 'NOM M. X - TEL...'
            content = m.group(1).strip()
            parts = re.split(r'[/–-]\s*TEL', content, flags=re.I)
            rest = parts[0] if parts else content
            # Téléphones CI = 10 chiffres (5 groupes de 2) : '07 12 67 97 65'
            telephones = re.findall(
                r'\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2}', content)
            telephones = [re.sub(r'\s+', ' ', t) for t in telephones]
            # nom = avant le premier / ou avant M./MME
            split = re.split(r'/\s*', rest)
            name = split[0].strip()
            titulaire = split[1].strip() if len(split) > 1 else ''
            if not titulaire:
                tm = re.split(r'\s+(?:M\.|MME)\s+', rest)
                name = tm[0].strip()
                titulaire = rest[len(name):].strip(' -–')
            cur_phcie = {
                'mois': mois, 'annee': annee,
                'semaine': cur_week,
                'section': cur_section,
                'quartier': cur_quartier,
                'pharmacie': name,
                'titulaire': titulaire,
                'telephones': telephones,
                'adresse': '',
            }
            continue
        # Ligne après une pharmacie = adresse (jusqu'à la suivante)
        if cur_phcie is not None and cur_week:
            up = line.upper()
            is_quartier = (line == up and len(line) <= 45 and 'TEL' not in up
                           and not line.startswith(('TOUR', 'GARDE', 'SEMAINE')))
            if is_quartier:
                flush_phcie()
                cur_quartier = line
            else:
                # adresse (complète l'adresse en cours)
                cur_phcie['adresse'] = (cur_phcie['adresse'] + ' ' + line).strip()
        # Ligne en MAJUSCULES isolée AVANT une pharmacie = commune/quartier
        elif cur_week and not cur_phcie:
            up = line.upper()
            is_quartier = (line == up and len(line) <= 45 and 'TEL' not in up
                           and not line.startswith(('TOUR', 'GARDE', 'SEMAINE',
                                                    'PERMANENCE')))
            if is_quartier:
                cur_quartier = line
    flush_phcie()
    return gardes


def semaine_dates(semaine_str: str, annee: int):
    """Convertit 'SAMEDI 01 AU VENDREDI 07 AOUT 2026' en (debut, fin) dates ISO."""
    m = re.search(r'SAMEDI\s+(\d{1,2})', semaine_str, re.I)
    if not m:
        return None, None
    day = int(m.group(1))
    for k, v in MOIS_INDEX.items():
        if v in semaine_str.upper():
            try:
                debut = date(annee, k, day)
                return debut.isoformat(), (debut + timedelta(days=6)).isoformat()
            except ValueError:
                return None, None
    return None, None


# --- Récupération du PDF depuis le site ---

def get_article_downloads(annee: int, mois: int) -> list[str]:
    """Trouve les liens downloads.php du mois en explorant la liste des articles.

    L'UNPPCI publie par SEMAINE : chaque article = une semaine de garde.
    On accumule TOUS les articles récents du mois + année (pas seulement
    le premier — sinon on ne couvre que la 1re semaine).
    """
    html = _fetch(f'{BASE}/index.php/pharmacies-de-garde')
    # Les articles récents sont listés avec ?p=articles&id=XXX
    # On scanne les IDs d'articles autour des plus récents (300 et moins)
    # et on cherche ceux dont le contenu contient le mois recherché.
    month_label = MOIS_INDEX[mois]
    results = []
    # L'UNPPCI publie par SEMAINE : chaque article = une semaine de garde.
    # On accumule TOUS les articles du mois (pas seulement le premier).
    for aid in range(310, 285, -1):  # les ~25 derniers articles
        try:
            page = _fetch(f'{BASE}/?p=articles&id={aid}')
        except Exception:
            continue
        if month_label in page.upper() and str(annee) in page:
            for dl in re.findall(r'downloads\.php\?id=(\d+)', page):
                if dl not in results:
                    results.append(dl)
        time.sleep(0.3)
    return results


def _fetch(url: str, timeout: int = 40) -> str:
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=timeout).read().decode('utf-8', errors='replace')


def download_pdf(download_id: str, out_dir: Path) -> Path | None:
    out = out_dir / f'garde_{download_id}.pdf'
    req = urllib.request.Request(f'{BASE}/controllers/downloads.php?id={download_id}', headers=UA)
    data = urllib.request.urlopen(req, timeout=90).read()
    if data[:4] == b'%PDF':
        out.write_bytes(data)
        return out
    return None


def to_firestore_records(gardes: list[dict]) -> list[dict]:
    """Convertit les gardes en records prêts pour Firestore (pharmacies)."""
    out = []
    for g in gardes:
        debut, fin = semaine_dates(g['semaine'], g['annee'] or date.today().year)
        # dates de la semaine (7 jours)
        dates = []
        if debut:
            d = date.fromisoformat(debut)
            dates = [(d + timedelta(days=i)).isoformat() for i in range(7)]
        out.append({
            'nom': g['pharmacie'],
            'quartier': g['quartier'] or '',
            'section': g['section'] or '',
            'titulaire': g['titulaire'],
            'telephones': g['telephones'],
            'adresse': g['adresse'],
            'dates_garde': dates,
            'semaine_debut': debut,
            'semaine_fin': fin,
            'mois': g['mois'],
            'annee': g['annee'],
        })
    return out


def sync_firestore(records: list[dict], sa_key_path: Path) -> dict:
    """Synchro des gardes vers Firestore via le service account (admin SDK)."""
    from firebase_admin import credentials, firestore, initialize_app
    import firebase_admin

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(sa_key_path))
        initialize_app(cred)
    db = firestore.client()
    batch = db.batch()
    count = 0
    for r in records:
        # Recherche de la pharmacie existante par nom (insensible à la casse)
        q = db.collection('pharmacies').where('name', '==', r['nom']).limit(1).stream()
        docs = list(q)
        if docs:
            doc = docs[0]
            old_dates = doc.to_dict().get('onDutyDates', [])
            new_dates = sorted(set(old_dates) | set(r['dates_garde']))
            batch.update(doc.reference, {
                'onDutyDates': new_dates,
                'phone1': r['telephones'][0] if r['telephones'] else doc.to_dict().get('phone1'),
            })
        else:
            batch.set(db.collection('pharmacies').document(), {
                'name': r['nom'],
                'commune': r['quartier'],
                'phone1': r['telephones'][0] if r['telephones'] else None,
                'phone2': r['telephones'][1] if len(r['telephones']) > 1 else None,
                'address': r['adresse'],
                'onDutyDates': r['dates_garde'],
            })
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    return {'synced': count}


def main():
    ap = argparse.ArgumentParser(description='Scraper UNPPCI pharmacies de garde')
    ap.add_argument('--mois', type=int, help='Mois (1-12)')
    ap.add_argument('--annee', type=int, help='Année (ex: 2026)')
    ap.add_argument('--dernier', action='store_true', help='Mois courant')
    ap.add_argument('--format', choices=['json', 'csv'], default='json')
    ap.add_argument('--out-dir', default='.', help='Dossier de sortie')
    ap.add_argument('--sync-firestore', action='store_true')
    ap.add_argument('--sa-key', help='Chemin de la clé service account Firebase')
    args = ap.parse_args()

    if args.dernier:
        today = date.today()
        annee, mois = today.year, today.month
    elif args.mois and args.annee:
        annee, mois = args.annee, args.mois
    else:
        ap.error('Précise --mois + --annee ou --dernier')

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f'[1/3] Recherche des PDFs pour {MOIS_INDEX[mois]} {annee}...')
    dl_ids = get_article_downloads(annee, mois)
    if not dl_ids:
        print('  Aucun lien de téléchargement trouvé pour ce mois.')
        sys.exit(1)
    print(f'  Liens trouvés: {dl_ids}')

    print('[2/3] Téléchargement et parsing...')
    all_gardes = []
    for dl_id in dl_ids:
        pdf = download_pdf(dl_id, out_dir)
        if pdf:
            gardes = parse_gardes(pdf)
            print(f'  {pdf.name}: {len(gardes)} gardes parsées')
            all_gardes.extend(gardes)

    if not all_gardes:
        print('  Aucune garde extraite.')
        sys.exit(1)

    print(f'[3/3] Export ({len(all_gardes)} gardes)...')
    records = to_firestore_records(all_gardes)

    if args.format == 'json':
        out_file = out_dir / f'gardes_{annee}_{mois:02d}.json'
        out_file.write_text(json.dumps(records, ensure_ascii=False, indent=1),
                            encoding='utf-8')
        print(f'  JSON: {out_file}')
    else:
        import csv
        out_file = out_dir / f'gardes_{annee}_{mois:02d}.csv'
        with open(out_file, 'w', newline='', encoding='utf-8-sig') as f:
            w = csv.DictWriter(f, fieldnames=['nom', 'quartier', 'section', 'titulaire',
                                              'telephones', 'semaine_debut', 'semaine_fin',
                                              'adresse'])
            w.writeheader()
            for r in records:
                w.writerow({k: r.get(k, '') for k in w.fieldnames})
        print(f'  CSV: {out_file}')

    if args.sync_firestore:
        if not args.sa_key:
            print('ERREUR: --sa-key requis pour --sync-firestore')
            sys.exit(1)
        result = sync_firestore(records, Path(args.sa_key))
        print(f'  Firestore: {result}')


if __name__ == '__main__':
    main()
