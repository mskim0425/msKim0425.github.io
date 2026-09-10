#!/usr/bin/env bash
# 빠른 로컬 미리보기
#   ./tools/dev.sh          → 최근 글 5개만 빌드 + 증분 재생성 + 라이브리로드 + 미래 날짜 포함
#   ./tools/dev.sh 20       → 최근 글 20개
#   ./tools/dev.sh all      → 전체 글 (배포 전 최종 확인용)
#
# 주의
#   --limit_posts N : 날짜 기준 최신 N개만 빌드. 옛날 글 수정 중이면 N을 키우거나 all 사용
#   --incremental   : 바뀐 글만 재생성. 홈/아카이브 목록이 옛 상태로 보일 수 있음 → push 전 all 로 한 번 확인
set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-5}"
ARGS=(--config _config.yml,_config.dev.yml --livereload --incremental --future)
[[ "$N" != "all" ]] && ARGS+=(--limit_posts "$N")

export JEKYLL_ENV=development
exec bundle exec jekyll serve "${ARGS[@]}"
