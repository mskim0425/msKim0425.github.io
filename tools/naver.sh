#!/usr/bin/env bash
# 네이버 블로그 붙여넣기 패키지 생성
#   ./tools/naver.sh gyehyanggak      → naver-drafts/gyehyanggak/ 에 title.txt, body.txt, tags.txt, images/01-*.jpg
#   ./tools/naver.sh                  → _naver/*.md 전부
#
# 입력: _naver/{slug}.md  (frontmatter: title, images_dir, images[], tags[] / 본문: [사진N] 마커)
# 출력: 스마트에디터에 제목·본문 붙여넣고, images/ 폴더의 사진을 순서대로 [사진N] 자리에 드래그
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "$@" <<'EOF'
import sys, os, re, glob, yaml
from PIL import Image
slugs = sys.argv[1:] or [os.path.basename(p)[:-3] for p in glob.glob('_naver/*.md')]
for slug in slugs:
    src = f'_naver/{slug}.md'
    if not os.path.exists(src): print(f'!! {src} 없음'); continue
    raw = open(src, encoding='utf-8').read()
    _, fm, body = raw.split('---', 2)
    meta = yaml.safe_load(fm); body = body.strip()
    out = f'naver-drafts/{slug}'; os.makedirs(f'{out}/images', exist_ok=True)
    # 제목 / 태그
    open(f'{out}/title.txt', 'w', encoding='utf-8').write(meta['title'] + '\n')
    open(f'{out}/tags.txt', 'w', encoding='utf-8').write(' '.join('#' + t for t in meta.get('tags', [])) + '\n')
    # 본문: 마크다운 최소 변환 (## → 줄 강조, ** 제거), [사진N] 은 그대로 남겨 붙여넣기 위치 표시
    txt = re.sub(r'^## (.+)$', r'■ \1', body, flags=re.M)
    txt = re.sub(r'\*\*(.+?)\*\*', r'\1', txt)
    txt = re.sub(r'^---$', '', txt, flags=re.M)
    open(f'{out}/body.txt', 'w', encoding='utf-8').write(txt + '\n')
    # 이미지: webp → jpg, 번호 순서 = [사진N]
    imgdir = f"images/{meta['images_dir']}"
    for i, name in enumerate(meta.get('images', []), 1):
        s = f'{imgdir}/{name}.webp'
        if not os.path.exists(s): print(f'   !! 이미지 없음: {s}'); continue
        Image.open(s).convert('RGB').save(f'{out}/images/{i:02d}-{name}.jpg', 'JPEG', quality=88)
    n = len(meta.get('images', []))
    print(f'✔ {out}/  제목·본문·태그 + 사진 {n}장  ([사진1]~[사진{n}] 자리에 순서대로)')
EOF
