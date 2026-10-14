import csv
import io
import json
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REVISION = '81d20919845b6a445969b9265aab5cec6b04cece'
BASE = f'https://raw.githubusercontent.com/PokeAPI/pokeapi/{REVISION}'


def download(path):
    request = urllib.request.Request(f'{BASE}/{path}', headers={'User-Agent': 'PokeCapture-catalog-builder'})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode('utf-8')


def entries(filename, identifier):
    grouped = {}
    for row in csv.DictReader(io.StringIO(download(f'data/v2/csv/{filename}'))):
        language = int(row['local_language_id'])
        if language not in (8, 9):
            continue
        entry = grouped.setdefault(int(row[identifier]), {})
        entry[language] = row['name']
    return [{'id': key, 'name': names.get(9, names.get(8)),
             'aliases': sorted(set(names.values()))} for key, names in sorted(grouped.items())]


def main():
    catalog = {
        'sourceRevision': REVISION,
        'languages': ['en', 'it'],
        'species': entries('pokemon_species_names.csv', 'pokemon_species_id'),
        'moves': entries('move_names.csv', 'move_id'),
    }
    resources = ROOT / 'ios' / 'Resources'
    resources.mkdir(parents=True, exist_ok=True)
    (resources / 'pokemon-catalog.json').write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8'
    )
    notices = ROOT / 'docs' / 'third-party'
    notices.mkdir(parents=True, exist_ok=True)
    license_text = download('LICENSE.md')
    (notices / 'PokeAPI-LICENSE.txt').write_text(license_text, encoding='utf-8')
    (resources / 'PokeAPI-LICENSE.txt').write_text(license_text, encoding='utf-8')
    print(f'Generated {len(catalog["species"])} species and {len(catalog["moves"])} moves (English/Italian).')


if __name__ == '__main__':
    main()
