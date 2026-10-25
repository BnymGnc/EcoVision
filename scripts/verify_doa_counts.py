"""Compare the packaged DOA snapshot with database counts, without writes.

Use --live-neon-read-only explicitly to read the Neon database configured by
Compose. Credentials stay in memory/stdin and are never printed or CLI args.
Requires the existing local ecovision-validation-db container's psql client.
"""
import argparse
from collections import Counter
import json
import re
from pathlib import Path
import shlex
import subprocess
from urllib.parse import urlsplit
from audit_locations_and_doa import audit

ROOT = Path(__file__).resolve().parents[1]
QUERY = """
select json_build_object(
 'total_rows', count(*),
 'doa_rows', count(*) filter(where provider='DOA'),
 'dim', count(*) filter(where provider='DOA' and point_type='DIM'),
 'min', count(*) filter(where provider='DOA' and point_type='MIN'),
 'sdm', count(*) filter(where provider='DOA' and point_type='SDM'),
 'source_points', json_agg(json_build_array(external_id,latitude,longitude,point_type)) filter(where provider='DOA')
) from map_pins
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--live-neon-read-only', action='store_true')
    args = parser.parse_args()
    records = json.loads((ROOT / 'backend/src/main/resources/data/data/doa_points_raw.json').read_text(encoding='utf-8'))
    if not isinstance(records, list):
        records = records['rvmList']
    source = {'rows': len(records), 'unique_ids': len({row['id'] for row in records}),
              'types': dict(Counter(row['depositPointType']['name'] for row in records))}
    print('SOURCE ' + json.dumps(source), flush=True)
    values = {'PGHOST': '127.0.0.1', 'PGPORT': '5432', 'PGDATABASE': 'ecovision_test',
              'PGUSER': 'ecovision_test', 'PGPASSWORD': 'local-validation-only'}
    if args.live_neon_read_only:
        config = subprocess.run(['docker', 'compose', 'config', '--format', 'json'],
                                cwd=ROOT, capture_output=True, check=True, timeout=15)
        env = json.loads(config.stdout)['services']['ecovision-backend']['environment']
        uri = urlsplit(env['SPRING_DATASOURCE_URL'].removeprefix('jdbc:'))
        if not (uri.hostname or '').endswith('.neon.tech'):
            raise ValueError('Live count check is restricted to a configured Neon hostname')
        values = {'PGHOST': uri.hostname, 'PGPORT': str(uri.port or 5432),
                  'PGDATABASE': uri.path.lstrip('/'), 'PGUSER': env['SPRING_DATASOURCE_USERNAME'],
                  'PGPASSWORD': env['SPRING_DATASOURCE_PASSWORD'], 'PGSSLMODE': 'require'}
    values['PGCONNECT_TIMEOUT'] = '10'
    shell = '\n'.join('export ' + key + '=' + shlex.quote(value) for key, value in values.items())
    read_only = "BEGIN READ ONLY; SET LOCAL statement_timeout='10s'; " + QUERY + '; COMMIT;'
    shell += '\npsql -X -qAt -v ON_ERROR_STOP=1 -v VERBOSITY=sqlstate -c ' + shlex.quote(read_only)
    # Binary stdin prevents Windows from appending CR to Linux shell values.
    result = subprocess.run(['docker', 'exec', '-i', 'ecovision-validation-db', 'sh'],
                            input=shell.encode('utf-8'), capture_output=True, timeout=25)
    if result.returncode:
        sqlstate = re.search(r'(?:ERROR|FATAL):\s+([0-9A-Z]{5})\b', result.stderr.decode('utf-8', errors='replace'))
        print('DATABASE_ERROR ' + (sqlstate.group(1) if sqlstate else 'CONNECTION_OR_CLIENT_ERROR'))
        raise RuntimeError('Read-only database count check failed; connection details withheld')
    counts = json.loads(result.stdout)
    actual_points = {row[0]: (row[1], row[2]) for row in counts.pop('source_points') or []}
    _, city_index = audit()
    urfa_ids = {row['id'] for row in city_index if row['city'] == 'Şanlıurfa' and row['pointType'] == 'DIM'}
    counts['sanliurfa_dim'] = len(urfa_ids.intersection(actual_points))
    source_points = {row['id']: (row['latitude'], row['longitude']) for row in records}
    ids_match = actual_points.keys() == source_points.keys()
    coordinates_match = ids_match and all(
        abs(actual_points[key][0] - coordinate[0]) < 1e-8 and
        abs(actual_points[key][1] - coordinate[1]) < 1e-8
        for key, coordinate in source_points.items())
    print(('LIVE_NEON_READ_ONLY ' if args.live_neon_read_only else 'LOCAL_TEST ') + json.dumps(counts))
    print('SOURCE_COUNT_MATCH ' + str(counts['doa_rows'] == source['unique_ids']))
    print('SOURCE_IDS_MATCH ' + str(ids_match))
    print('SOURCE_COORDINATES_MATCH ' + str(coordinates_match))
    if counts['doa_rows'] != source['unique_ids'] or not coordinates_match:
        raise RuntimeError('Source/database catalog mismatch')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        # Never print subprocess output/connection strings from configuration.
        print('Count verification could not complete; connection details withheld.')
        raise SystemExit(1)
