#!/usr/bin/env bash
# 빠른 로컬 미리보기
#   ./tools/dev.sh            → 최근 글 5개만 빌드 + 라이브리로드 + 미래 날짜 포함 (기본)
#   ./tools/dev.sh 20         → 최근 글 20개
#   ./tools/dev.sh all        → 전체 글 (push 전 최종 확인용)
#   INC=1 ./tools/dev.sh      → 증분 빌드 켬 (기존 글 본문만 고칠 때. 새 글 추가/삭제 시엔 홈 목록이 갱신 안 됨)
#
# 속도는 _config.dev.yml(아카이브·PWA·HTML압축 끔) + --limit_posts 에서 대부분 나온다.
# --incremental 은 새 글이 홈 목록에 안 뜨는 부작용이 있어 기본에서 뺐다.
set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-5}"
ARGS=(--config _config.yml,_config.dev.yml --livereload --future)
[[ "$N" != "all" ]] && ARGS+=(--limit_posts "$N")

if [[ "${INC:-0}" == "1" ]]; then
  ARGS+=(--incremental)
else
  rm -f .jekyll-metadata          # 증분 캐시 제거 → 새 글/삭제 글이 목록에 정확히 반영
fi

export JEKYLL_ENV=development
exec bundle exec jekyll serve "${ARGS[@]}"
