"""Real HTTP/STOMP checks. Restricted to the isolated localhost test backend."""
from datetime import datetime, timedelta, timezone
import json
import math
from pathlib import Path
import secrets
import statistics
import time
import urllib.request
from urllib.parse import urlencode
from playwright.sync_api import sync_playwright
from browser_smoke import API, request
from audit_locations_and_doa import audit

ROOT = Path(__file__).resolve().parents[1]


def account():
    suffix = secrets.token_hex(6)
    return request('/api/auth/register', {
        'name': 'Audit', 'surname': 'Local', 'email': f'audit_{suffix}@ecovision.invalid',
        'password': 'Local!8aA-' + suffix, 'dateOfBirth': '2000-01-01',
        'city': 'Kayseri', 'district': 'Talas', 'username': 'audit_' + suffix,
        'termsAccepted': True, 'privacyAccepted': True,
    })


def timed(path, token):
    durations, sizes = [], []
    for _ in range(5):
        start = time.perf_counter()
        body = request(path, token=token)
        durations.append((time.perf_counter() - start) * 1000)
        sizes.append(len(json.dumps(body, ensure_ascii=False, separators=(',', ':')).encode()))
    return {'medianMs': round(statistics.median(durations), 2),
            'samplesMs': [round(value, 2) for value in durations],
            'serializedBytes': int(statistics.median(sizes))}


def main():
    for attempt in range(90):
        try:
            with urllib.request.urlopen(API + '/actuator/health', timeout=2) as response:
                if json.loads(response.read()).get('status') == 'UP':
                    break
        except Exception:
            pass
        time.sleep(1)
    else:
        raise RuntimeError('Isolated backend did not become healthy')
    owner, member = account(), account()
    token = owner['accessToken']
    source, _ = audit()
    inventory = request('/api/map-pins/locations', token=token)
    expected = {row['city']: row for row in source['cityTotals']}
    assert inventory['total'] == 4037 and inventory['unresolved'] == 3
    assert len(inventory['cities']) == 81
    for city in inventory['cities']:
        assert city['counts'] == {kind: expected[city['name']][kind] for kind in inventory['counts']}, city['name']
    ids, total = set(), 0
    while True:
        page = request('/api/map-pins/search?' + urlencode({
            'lat': 39, 'lng': 35, 'pointTypes': 'DIM,MIN,KIM,SDM,UNKNOWN', 'offset': len(ids), 'limit': 100,
        }), token=token)
        total = page['total']
        for point in page['items']:
            assert point['id'] not in ids
            assert math.isfinite(point['latitude']) and math.isfinite(point['longitude'])
            ids.add(point['id'])
        if not page['hasMore']:
            break
    assert len(ids) == total == 4037
    city_page = '/api/map-pins/search?' + urlencode({'lat': 38.72, 'lng': 35.48, 'city': 'Kayseri', 'limit': 100})
    assert request(city_page, token=token)['total'] == 29
    legacy = timed('/api/map-pins/nearby?lat=38.72&lng=35.48&limit=500', token)
    scoped = timed(city_page, token)

    group = request('/api/groups', {'name': 'Local audit group', 'description': 'Temporary isolated test fixture',
        'city': 'Kayseri', 'district': 'Talas', 'memberLimit': 20, 'privateGroup': False}, token)
    group_id = group['id']
    request(f'/api/groups/{group_id}/join', {}, member['accessToken'])
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path=r'C:\Program Files\Google\Chrome\Application\chrome.exe', headless=True)
        page = browser.new_page()
        page.goto(API + '/api/health')
        # Subscribe and send through the actual STOMP endpoint, not mocks/polling.
        live = page.evaluate("""({token, group}) => new Promise((resolve, reject) => {
          const socket = new WebSocket('ws://127.0.0.1:18081/ws');
          const deadline = setTimeout(() => { socket.close(); reject(new Error('STOMP timeout')); }, 15000);
          let text = false, typing = false;
          const frame = (command, headers, body='') => socket.send(command+'\\n'+Object.entries(headers).map(([k,v])=>k+':'+v).join('\\n')+'\\n\\n'+body+'\\0');
          socket.onopen = () => frame('CONNECT', {'accept-version':'1.2', host:'localhost', Authorization:'Bearer '+token, 'heart-beat':'0,0'});
          socket.onmessage = event => {
            const data = String(event.data);
            if (data.startsWith('ERROR')) {clearTimeout(deadline);socket.close();reject(new Error('STOMP rejected'));}
            if (data.startsWith('CONNECTED')) {
              frame('SUBSCRIBE', {id:'messages',destination:'/topic/groups/'+group});
              frame('SUBSCRIBE', {id:'typing',destination:'/topic/groups/'+group+'/typing'});
              setTimeout(() => {
                frame('SEND', {destination:'/app/groups/'+group+'/messages','content-type':'application/json'}, JSON.stringify({message:'Audit real-time message'}));
                frame('SEND', {destination:'/app/groups/'+group+'/typing','content-type':'application/json'}, JSON.stringify({typing:true}));
              }, 300);
            }
            if (data.startsWith('MESSAGE')) {
              text ||= data.includes('Audit real-time message'); typing ||= data.includes('"typing":true');
              if (text && typing) { clearTimeout(deadline);socket.close();resolve({text, typing}); }
            }
          };
          socket.onerror = () => {clearTimeout(deadline);reject(new Error('WebSocket failed'));};
        })""", {'token': member['accessToken'], 'group': group_id})
        browser.close()
    history = request(f'/api/chat/groups/{group_id}?limit=50&offset=0', token=token)
    assert any(message['message'] == 'Audit real-time message' for message in history)
    poll = request(f'/api/chat/groups/{group_id}/polls', {'question': 'Which material?', 'options': ['PET', 'Glass']}, token)
    request(f'/api/chat/groups/{group_id}/messages/{poll["id"]}/vote', {'optionIndex': 0}, member['accessToken'])
    request(f'/api/chat/groups/{group_id}/polls/{poll["id"]}', token=token, method='DELETE')
    event = request(f'/api/groups/{group_id}/events', {
        'title': 'Local audit cleanup', 'description': 'Isolated event verification',
        'eventDate': (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        'city': 'Kayseri', 'district': 'Talas', 'exactAddress': 'Test address', 'capacity': 20,
    }, token)
    request(f'/api/groups/{group_id}/events/{event["id"]}/rsvp', {'status': 'ATTENDING'}, member['accessToken'])
    attendees = request(f'/api/groups/{group_id}/events/{event["id"]}/attendees', token=token)
    assert attendees
    request(f'/api/groups/{group_id}/events/{event["id"]}', token=token, method='DELETE')
    report = {'environment': 'isolated localhost PostgreSQL/Java17 only', 'sourcePoints': total,
        'provincesMatched': 81, 'uniqueApiIds': len(ids), 'unknownAddressCount': inventory['unresolved'],
        'oldGlobal500': legacy, 'newKayseri100': scoped,
        'performanceCaveat': 'Different query scopes; local samples are not a Render capacity or mobile FPS benchmark.',
        'stomp': live, 'groupJoin': True, 'pollCreateVoteDelete': True, 'eventCreateRsvpDelete': True}
    (ROOT / 'docs/final-runtime-verification.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
