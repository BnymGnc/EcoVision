"""Reproducible source inventory, not a substitute for runtime OpenAPI validation.

Reads only controller and DTO source. Never reads .env, credentials or live services.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CONTROLLERS = ROOT / 'backend/src/main/java/com/ecovision/backend/controller'
MAPPING = re.compile(r'@(?:org\.springframework\.web\.bind\.annotation\.)?(GetMapping|PostMapping|PutMapping|DeleteMapping|PatchMapping|RequestMapping|MessageMapping)\b')
SIGNATURE = re.compile(r'public\s+([\w.<>?,\s\[\]]+?)\s+(\w+)\s*\(')


def balanced(source, start):
    depth, quoted, escaped = 0, False, False
    for index in range(start, len(source)):
        char = source[index]
        if quoted:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char == '(':
            depth += 1
        elif char == ')':
            depth -= 1
            if depth == 0:
                return index + 1
    raise ValueError('Unbalanced annotation/signature')


def annotations(source):
    for match in MAPPING.finditer(source):
        start = match.end()
        while start < len(source) and source[start].isspace():
            start += 1
        end = balanced(source, start) if source[start:start + 1] == '(' else start
        args = source[start + 1:end - 1] if end > start else ''
        yield match, end, args


def routes():
    result = []
    for path in sorted(CONTROLLERS.glob('*.java')):
        source = path.read_text(encoding='utf-8')
        class_start = re.search(r'public class \w+', source)
        if not class_start:
            continue
        prefix = ''
        for annotation, end, args in annotations(source):
            if annotation.start() < class_start.start():
                if annotation.group(1) == 'RequestMapping':
                    strings = re.findall(r'"([^"]*)"', args)
                    prefix = strings[0] if strings else ''
                continue
            method = SIGNATURE.search(source, end)
            if not method:
                raise ValueError('No handler found: ' + path.name)
            strings = re.findall(r'"([^"]*)"', args)
            route = next((value for value in strings if value.startswith('/')), '')
            verb = annotation.group(1).replace('Mapping', '').upper()
            if verb == 'MESSAGE':
                route = '/app' + route
                verb = 'STOMP SEND'
            else:
                route = prefix + route
            position = method.end() - 1
            parameters = source[position + 1:balanced(source, position) - 1]
            line = source[:annotation.start()].count('\n') + 1
            result.append({'controller': path.name, 'verb': verb, 'path': route,
                           'method': method.group(2), 'returns': ' '.join(method.group(1).split()),
                           'parameters': ' '.join(parameters.split()), 'line': line,
                           'multipart': 'MULTIPART' in args})
    return result


def render(found):
    lines = ['# EcoVision: kaynak koddan API envanteri', '',
             'Tarih: 24 Ekim 2026. `python scripts/document_api_routes.py` ile controller kaynaklarından üretilir.',
             'Bu, canlı sunucu testi değildir. Eski/uyumluluk endpoint\'leri de dahildir.',
             'Ana açıklamalar ve ekran/buton bağları: [detaylı proje rehberi](ecovision-architecture-and-flows-tr.md).', '',
             f'HTTP handler tanımı: **{sum(r["verb"] != "STOMP SEND" for r in found)}**; '
             f'STOMP uygulama handler tanımı: **{sum(r["verb"] == "STOMP SEND" for r in found)}**.',
             'Aynı URL için JSON/multipart handler\'ları ayrı sayılır. Actuator/Swagger framework yolları bu sayıda değildir.', '']
    for controller in sorted({row['controller'] for row in found}):
        lines += ['## ' + controller, '', '| Yöntem / yol | Java işlemi | Yanıt tipi | Gövde |', '|---|---|---|---|']
        for row in (r for r in found if r['controller'] == controller):
            location = '../backend/src/main/java/com/ecovision/backend/controller/' + controller
            lines.append(f'| `{row["verb"]} {row["path"]}` | [{row["method"]}]({location}#L{row["line"]}) | '
                         f'`{row["returns"]}` | {"multipart" if row["multipart"] else "JSON / query / path; aşağıdaki imza"} |')
        lines += ['', 'İstek parametreleri (annotation\'lar doğrulama ve alan adlarını gösterir):', '', '```java']
        for row in (r for r in found if r['controller'] == controller):
            lines.append(f'{row["method"]}({row["parameters"]})')
        lines += ['```', '']
    lines += ['## Yetkiyi nasıl okumalı?', '',
              'Tablo yalnız mapping/handler imzalarını çıkarır. Yetki denetimi SecurityConfig,',
              'SUPERUSER method annotation\'ları, CurrentUserService ve iş servislerinin',
              'yaş/üyelik/kurucu/yönetici/nesne sahipliği kontrolleriyle birlikte değerlendirilir.',
              'Medya URL\'sinin filtre katmanında permitAll olması, özel medya bytes\'ına',
              'anonim erişim olduğu anlamına gelmez: MediaAccessService nesne yetkisini denetler.', '']
    lines += ['## DTO alan sözleşmeleri', '',
              'Aşağıdaki record başlıkları dto klasörünün gerçek kaynaklarından alınır.',
              'Java tipleri sayı/boolean/list/object yapısını gösterir. @JsonProperty varsa JSON anahtarı o annotation değeridir.',
              'Record gövdesindeki ek getter alanları bu başlıklarda yer almaz; gerçek JSON daha fazla türetilmiş alan içerebilir.',
              'Bunlar örnek hesap, gerçek token veya anahtar değerleri içermez. Servis içi nested record\'lar ana rehberde ayrıca açıklanır.', '']
    for path in sorted((CONTROLLERS.parent / 'dto').glob('*.java')):
        source = path.read_text(encoding='utf-8')
        for match in re.finditer(r'\brecord\s+(\w+)\s*\(', source):
            start = match.end() - 1
            signature = source[match.start():balanced(source, start)]
            lines += ['### ' + match.group(1), '', '```java', signature, '```', '']
    return '\n'.join(lines)


def main():
    found = routes()
    assert any(row['path'] == '/api/users/login-history' for row in found)
    assert any(row['path'] == '/api/map-pins/search' for row in found)
    assert sum(row['verb'] == 'STOMP SEND' for row in found) == 4
    (ROOT / 'docs/api-route-inventory-tr.md').write_text(render(found), encoding='utf-8')
    print('Controller source routes:', len(found))
    print('Controllers with routes:', len({row['controller'] for row in found}))
    print('Unique HTTP verb/path pairs:', len({(row['verb'], row['path']) for row in found if row['verb'] != 'STOMP SEND'}))


if __name__ == '__main__':
    main()
