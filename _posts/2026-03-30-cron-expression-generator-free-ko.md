---
title: "무료 크론 표현식 생성기 — Cron 스케줄 시각적으로 만들기"
date: 2026-03-30 12:30:00 +0900
categories: [Dev Life, Tools]
tags: [cron, 크론, crontab, 스케줄러, 개발자도구, 무료도구, linux, devops, github-actions, 크론표현식]
description: "크론 표현식을 시각적 에디터로 생성하고 테스트. 다음 5회 실행 시간을 즉시 확인. 11가지 프리셋 제공. 회원가입 불필요."
---

크론 표현식을 시각적으로 만들고, 다음 5회 실행 시간을 바로 확인하세요. **[크론 생성기 바로가기 →](/tools/#cron)**

11가지 프리셋, 영문 설명, 치트시트, 원클릭 복사 지원. crontab, Kubernetes CronJob, GitHub Actions, Spring `@Scheduled` 모두 호환.

---

## FAQ

**6필드/7필드 크론도 지원하나요?**
표준 5필드 Unix 형식만 지원합니다. Quartz(Java)의 초/연도 필드는 미지원. crontab, K8s, GitHub Actions에는 5필드면 충분합니다.

**다음 실행 시간이 정확한가요?**
네, 브라우저의 현재 시간과 타임존 기준으로 계산합니다. 서버 타임존이 다를 수 있으니 확인하세요.

**GitHub Actions에서 쓸 수 있나요?**
네. 다만 GitHub Actions의 크론은 UTC 기준이므로 한국 시간에서 9시간을 빼야 합니다.
