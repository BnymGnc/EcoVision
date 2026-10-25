#!/usr/bin/env python3
"""Collect public DOA map points, handling pagination and spatial clusters.

Python 3.10+, standard library only. This is the website's observed web
endpoint, not a guaranteed/versioned public API contract.
"""
import argparse
import csv
import hashlib
import json
import math
import time
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ENDPOINT = 'https://dbysmgw.doa.gov.tr/dbys/v3/web/rvm/search'
SOURCE = 'https://doa.gov.tr/ambalaj-iadesi-nereye-yapilir'
TYPE_LABELS = {'dim': 'İade Makinesi', 'kim': 'Kamusal İade Merkezi (KİM)',
               'min': 'İade Merkezi', 'sdm': 'Toplu İade Merkezi'}
STATUS_LABELS = {1: 'AÇIK', 2: 'KAPALI', 3: 'GEÇİCİ KAPALI', 4: 'KULLANIM DIŞI'}


def haversine(lat1, lon1, lat2, lon2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dlat, dlon = p2-p1, math.radians(lon2-lon1)
    a = math.sin(dlat/2)**2+math.cos(p1)*math.cos(p2)*math.sin(dlon/2)**2
    return 6371008.8*2*math.atan2(math.sqrt(a), math.sqrt(max(0, 1-a)))


def circle(box):
    south, west, north, east = box
    lat, lon = (south+north)/2, (west+east)/2
    distance = max(haversine(lat, lon, y, x)
                   for y in (south, north) for x in (west, east))
    return {'lat': lat, 'lon': lon, 'distance': math.ceil(distance*1.015+500),
            'userLat': lat, 'userLon': lon}


def split_box(box):
    s, w, n, e = box
    y, x = (s+n)/2, (w+e)/2
    return [(s,w,y,x), (s,x,y,e), (y,w,n,x), (y,x,n,e)]


class Collector:
    def __init__(self, output, delay, timeout, max_requests):
        self.output = output
        self.cache = output/'cache'
        self.cache.mkdir(parents=True, exist_ok=True)
        self.delay, self.timeout, self.max_requests = delay, timeout, max_requests
        self.calls = 0
        self.last_call = 0.0
        self.records = {}
        self.invalid = []
        self.queries = []

    def request(self, body, page=1):
        signature = json.dumps([body,page,100], sort_keys=True)
        digest = hashlib.sha256(signature.encode()).hexdigest()[:24]
        cache = self.cache/(digest+'.json')
        if cache.exists() and time.time()-cache.stat().st_mtime<3600:
            return json.loads(cache.read_text(encoding='utf-8'))
        if self.calls >= self.max_requests:
            raise RuntimeError('Request cap reached; rerun to resume cached queries.')
        req = urllib.request.Request(
            f'{ENDPOINT}?pageNumber={page}&pageSize=100',
            data=json.dumps(body).encode('utf-8'), method='POST',
            headers={'Content-Type':'application/json', 'Accept':'application/json',
                     'User-Agent':'EcoVision-DOA-Map-Export/1.0',
                     'Origin':'https://doa.gov.tr', 'Referer':SOURCE})
        for attempt in range(3):
            time.sleep(max(0, self.delay-(time.monotonic()-self.last_call)))
            self.calls += 1
            self.last_call = time.monotonic()
            try:
                with urllib.request.urlopen(req, timeout=self.timeout) as response:
                    result = json.load(response)
                if not isinstance(result,dict) or not isinstance(result.get('rvmList'),list) or not isinstance(result.get('clusterDataList'),list) or 'totalElements' not in result:
                    raise RuntimeError('Unexpected response schema; export halted.')
                cache.write_text(json.dumps(result,ensure_ascii=False),encoding='utf-8')
                self.queries.append({'body':body,'page':page,'total':result['totalElements']})
                return result
            except urllib.error.HTTPError as exc:
                if exc.code in (401,403,429):
                    raise RuntimeError(f'HTTP {exc.code}; stopped. No authentication/rate-limit bypass.') from exc
                if exc.code<500 or attempt==2:
                    raise RuntimeError(f'HTTP {exc.code}; inspect request and schema.') from exc
            except (TimeoutError, urllib.error.URLError):
                if attempt==2:
                    raise
            time.sleep(2**attempt)
        raise RuntimeError('Request failed.')

    def add(self, items):
        for item in items:
            try:
                if not item.get('id'):
                    raise ValueError('Missing id')
                y,x=float(item['latitude']),float(item['longitude'])
                if not all(map(math.isfinite,(y,x))) or not (-90<=y<=90 and -180<=x<=180):
                    raise ValueError('Invalid coordinates')
                self.records[str(item['id'])]=item
            except (KeyError,TypeError,ValueError) as exc:
                self.invalid.append({'id':item.get('id'),'reason':str(exc)})

    def prime_recent_cache(self):
        # Reuse only responses from this output directory's current hour.
        for path in sorted(self.cache.glob('*.json'),key=lambda p:p.stat().st_mtime):
            if time.time()-path.stat().st_mtime >= 3600:
                continue
            result=json.loads(path.read_text(encoding='utf-8'))
            if isinstance(result,dict) and isinstance(result.get('rvmList'),list):
                self.add(result['rvmList'])

    def query_area(self, body):
        first=self.request(body)
        self.add(first['rvmList'])
        if first['clusterDataList']:
            return False
        total=int(first['totalElements'])
        observed=len(first['rvmList'])
        if total and not observed:
            raise RuntimeError('Positive count with no points/clusters.')
        seen={str(x.get('id')) for x in first['rvmList']}
        page=2
        while observed<total:
            value=self.request(body,page)
            if value['clusterDataList']:
                return False
            items=value['rvmList']
            ids={str(x.get('id')) for x in items}
            if not items or ids<=seen:
                raise RuntimeError('Pagination incomplete or repeated; no full-coverage claim.')
            self.add(items)
            seen.update(ids)
            observed+=len(items)
            page+=1
            if page>1000:
                raise RuntimeError('Pagination safety cap reached.')
        return True

    def export(self, metadata):
        fetched=datetime.now(timezone.utc).isoformat()
        rows=[]
        for item in sorted(self.records.values(),key=lambda p:str(p['id'])):
            point_type=(item.get('depositPointType') or {}).get('name','unknown')
            rows.append({
                'id':str(item['id']), 'name':(item.get('definition') or {}).get('name'),
                'address':item.get('address'), 'latitude':float(item['latitude']),
                'longitude':float(item['longitude']), 'point_type':point_type,
                'point_type_label':TYPE_LABELS.get(point_type,'Bilinmeyen tür'),
                'active':item.get('active'), 'status':item.get('status'),
                'status_label':STATUS_LABELS.get(item.get('status'),'Bilinmiyor'),
                'accepted_materials':item.get('contentType') or [],
                'weekly_schedule':item.get('weeklySchedule'),
                'source_url':SOURCE, 'fetched_at_utc':fetched})
        self.output.mkdir(parents=True,exist_ok=True)
        raw=sorted(self.records.values(),key=lambda p:str(p['id']))
        (self.output/'doa_points_raw.json').write_text(json.dumps(raw,ensure_ascii=False,indent=2),encoding='utf-8')
        (self.output/'doa_points.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
        (self.output/'doa_machines_dim.json').write_text(json.dumps([r for r in rows if r['point_type']=='dim'],ensure_ascii=False,indent=2),encoding='utf-8')
        for name,selection in [('doa_points.csv',rows),('doa_machines_dim.csv',[r for r in rows if r['point_type']=='dim'])]:
            fields=['id','name','point_type','point_type_label','address','latitude','longitude','active','status','status_label','accepted_materials','weekly_schedule','source_url','fetched_at_utc']
            with (self.output/name).open('w',encoding='utf-8-sig',newline='') as f:
                writer=csv.DictWriter(f,fieldnames=fields,delimiter=';')
                writer.writeheader()
                for row in selection:
                    converted={k:json.dumps(v,ensure_ascii=False) if isinstance(v,(list,dict)) else v for k,v in row.items()}
                    # Prevent spreadsheet formula execution from external text.
                    converted={k:(' '+v if isinstance(v,str) and v.startswith(('=','+','-','@')) else v) for k,v in converted.items()}
                    writer.writerow(converted)
        features=[{'type':'Feature','geometry':{'type':'Point','coordinates':[r['longitude'],r['latitude']]},'properties':{k:v for k,v in r.items() if k not in ('latitude','longitude')}} for r in rows]
        (self.output/'doa_points.geojson').write_text(json.dumps({'type':'FeatureCollection','features':features},ensure_ascii=False),encoding='utf-8')
        metadata.update({'fetched_at_utc':fetched,'unique_points':len(rows),
                         'by_type':dict(Counter(r['point_type'] for r in rows)),
                         'invalid_records':self.invalid,'http_calls_this_run':self.calls,
                         'source_url':SOURCE,'endpoint':ENDPOINT})
        (self.output/'manifest.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
        return metadata


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path('doa-export'))
    parser.add_argument('--delay',type=float,default=0.75)
    parser.add_argument('--timeout',type=float,default=20)
    parser.add_argument('--max-requests',type=int,default=300)
    args=parser.parse_args()
    if args.delay<0.5:
        parser.error('Use a delay of at least 0.5 seconds.')
    collector=Collector(args.output,args.delay,args.timeout,args.max_requests)
    metadata={'coverage':'partial','root_reported_total':None,'remaining_seed_areas':None,
              'collection_method':'coarse public clusters, then paginated overlapping 100-km searches (50-km fallback)'}
    try:
        root={'lat':39.0,'lon':35.0,'distance':1200000,'userLat':39.0,'userLon':35.0}
        first=collector.request(root)
        metadata['root_reported_total']=int(first['totalElements'])
        collector.prime_recent_cache()
        if not collector.query_area(root):
            # Obtain finer public clusters from 16 broad circles covering Turkey.
            # Overlapping searches are deduplicated by the provider's point ID.
            boxes=[child for parent in split_box((35.0,25.0,43.0,46.0)) for child in split_box(parent)]
            seeds={}
            for index,box in enumerate(boxes,1):
                value=collector.request(circle(box))
                collector.add(value['rvmList'])
                for point in value['clusterDataList']:
                    key=(round(float(point['latitude']),7),round(float(point['longitude']),7))
                    seeds[key]=max(seeds.get(key,0),int(point.get('count',1)))
                print(json.dumps({'coarse_area':index,'seed_count':len(seeds),'unique':len(collector.records),'http_calls':collector.calls}),flush=True)
            centers=[]
            # 15-km overlap beyond covered centroids reduces edge omissions.
            # It is NOT a guarantee: coverage is reported only against source count.
            for coverage_radius in (85000,35000,15000):
                pending={p:n for p,n in seeds.items() if not any(haversine(*p,*q)<=coverage_radius for q in centers)}
                while pending and len(collector.records)<metadata['root_reported_total']:
                    center=max(pending,key=pending.get)
                    body={'lat':center[0],'lon':center[1],
                          'distance':100000 if coverage_radius==85000 else 50000,
                          'userLat':center[0],'userLon':center[1]}
                    if not collector.query_area(body):
                        body['distance']=50000
                        if not collector.query_area(body):
                            raise RuntimeError('50-km query returned clusters; schema/threshold changed.')
                        effective_coverage=min(coverage_radius,35000)
                    else:
                        effective_coverage=coverage_radius
                    centers.append(center)
                    pending={p:n for p,n in pending.items() if haversine(*p,*center)>effective_coverage}
                    print(json.dumps({'unique':len(collector.records),'source_total':metadata['root_reported_total'],'remaining_seed_areas':len(pending),'http_calls':collector.calls}),flush=True)
                if len(collector.records)>=metadata['root_reported_total']:
                    break
            metadata['remaining_seed_areas']=len(pending)
        metadata['coverage']='count_matched_snapshot' if len(collector.records)==metadata['root_reported_total'] and not collector.invalid else 'count_mismatch_review_required'
    except Exception as exc:
        metadata['error']=str(exc)
        print('STOPPED:',str(exc),flush=True)
    finally:
        report=collector.export(metadata)
        print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
    return 0 if metadata['coverage']=='count_matched_snapshot' else 2


if __name__=='__main__':
    raise SystemExit(main())
