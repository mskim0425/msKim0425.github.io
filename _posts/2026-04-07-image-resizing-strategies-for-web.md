---
title: "이미지 리사이징 & 최적화 전략 총정리 — 실무에서 쓰는 7가지 기법"
date: 2026-04-07 10:00:00 +0900
categories: [Backend, Infrastructure]
tags: [image-resizing, webp, avif, sharp, imagick, cloudinary, s3-presigned-url, responsive-image, lazy-loading, image-optimization, cdn, tus-upload]
description: "WebP 변환, CDN 리사이징, Pre-signed URL 업로드, 반응형 이미지까지 — 실무에서 자주 쓰이는 이미지 최적화 전략을 코드 예시와 함께 정리합니다."
---

## 왜 이미지 최적화가 중요한가

웹 페이지 전체 용량의 평균 50% 이상이 이미지다. 5MB짜리 원본 사진을 그대로 올리면, 모바일 유저는 로딩만 3초를 기다린다. Google은 Core Web Vitals에서 LCP(Largest Contentful Paint)를 2.5초 이내로 권장하는데, 이미지 하나가 이걸 깨뜨린다.

이 글에서는 실무에서 실제로 쓰이는 7가지 이미지 최적화 전략을 다룬다.

---

## 1. 포맷 변환 — WebP / AVIF

가장 간단하면서도 효과가 큰 방법이다.

| 포맷 | 압축률 (JPEG 대비) | 브라우저 지원 | 특징 |
|------|-------------------|-------------|------|
| JPEG | 기준 | 전체 | 손실 압축, 사진에 적합 |
| PNG | 1.5~3x 큼 | 전체 | 무손실, 투명 배경 지원 |
| WebP | 25~35% 작음 | 97%+ | 손실/무손실 모두 지원 |
| AVIF | 40~50% 작음 | 92%+ | 차세대 포맷, 인코딩 느림 |

### Python (Pillow)

```python
from PIL import Image, ImageOps

img = Image.open("photo.jpg")
img = ImageOps.exif_transpose(img)  # EXIF 회전 보정
img = img.convert("RGB")

# WebP 변환 — quality 80이면 육안 차이 거의 없음
img.save("photo.webp", "WEBP", quality=80, method=6)

# AVIF 변환 — Pillow 10.0+ 필요
img.save("photo.avif", "AVIF", quality=60)
```

### Node.js (Sharp)

```javascript
const sharp = require('sharp');

await sharp('photo.jpg')
  .webp({ quality: 80 })
  .toFile('photo.webp');

// AVIF — 인코딩이 WebP보다 3~5배 느림, 빌드 타임에 미리 처리 권장
await sharp('photo.jpg')
  .avif({ quality: 50 })
  .toFile('photo.avif');
```

### HTML에서 포맷 분기 — `<picture>` 태그

브라우저가 지원하는 포맷을 자동 선택하게 할 수 있다:

```html
<picture>
  <source srcset="/images/photo.avif" type="image/avif">
  <source srcset="/images/photo.webp" type="image/webp">
  <img src="/images/photo.jpg" alt="fallback" loading="lazy">
</picture>
```

AVIF를 지원하면 AVIF, 아니면 WebP, 둘 다 안 되면 JPEG. 이 패턴 하나로 구형 브라우저 호환까지 해결된다.

---

## 2. 반응형 리사이징 — srcset & sizes

같은 이미지를 모바일(360px), 태블릿(768px), 데스크탑(1200px)에 동일한 사이즈로 내려줄 이유가 없다.

```html
<img
  srcset="
    /images/hero-400w.webp 400w,
    /images/hero-800w.webp 800w,
    /images/hero-1200w.webp 1200w
  "
  sizes="(max-width: 600px) 400px, (max-width: 1024px) 800px, 1200px"
  src="/images/hero-800w.webp"
  alt="Hero image"
  loading="lazy"
>
```

빌드 타임에 Sharp로 여러 사이즈를 미리 생성해두는 스크립트:

```javascript
const sharp = require('sharp');
const sizes = [400, 800, 1200];

for (const width of sizes) {
  await sharp('hero.jpg')
    .resize(width)
    .webp({ quality: 80 })
    .toFile(`hero-${width}w.webp`);
}
```

모바일 유저에게 1200px 이미지를 내려주는 것과 400px을 내려주는 것은 용량 차이가 3~5배다. 체감 로딩 속도가 확연히 다르다.

---

## 3. CDN 기반 On-the-fly 리사이징

미리 여러 사이즈를 만들어두는 게 번거롭다면, CDN에서 요청 시 동적으로 리사이징하는 방법이 있다.

### Cloudinary

```html
<!-- 원본 -->
<img src="https://res.cloudinary.com/demo/image/upload/sample.jpg">

<!-- 가로 400px, WebP 자동 변환, 얼굴 인식 크롭 -->
<img src="https://res.cloudinary.com/demo/image/upload/w_400,f_auto,c_fill,g_face/sample.jpg">
```

URL 파라미터만 바꾸면 리사이징, 포맷 변환, 크롭이 전부 된다. 한 번 생성된 변환 결과는 CDN에 캐싱되므로, 두 번째 요청부터는 원본 서버를 거치지 않는다.

### imgix

```html
<img src="https://your-domain.imgix.net/photo.jpg?w=400&auto=format,compress">
```

### Cloudflare Images

```html
<img src="https://your-domain.com/cdn-cgi/image/width=400,format=auto/images/photo.jpg">
```

이 방식의 핵심 장점은 **원본 하나만 관리**하면 된다는 것이다. 다만 요청량에 따라 비용이 발생한다.

| 서비스 | 무료 티어 | 특징 |
|--------|----------|------|
| Cloudinary | 25GB 대역폭/월 | URL 기반 변환, AI 크롭 |
| imgix | 1,000 원본/월 | 퍼포먼스 특화 |
| Cloudflare Images | $5/월 100K 이미지 | Cloudflare 생태계 통합 |

---

## 4. 업로드 전략 — Multipart vs Pre-signed URL vs Chunked

이미지를 서버에 올리는 방법도 성능에 큰 영향을 미친다.

### (A) 전통적 Multipart Upload

```
Client → App Server → S3
```

클라이언트가 이미지를 앱 서버로 보내고, 앱 서버가 S3에 저장한다. 가장 단순하지만, 앱 서버가 바이너리 데이터를 전부 메모리에 올려야 한다.

```ruby
# Rails 예시 — 서버 메모리를 점유
def upload
  file = params[:image]  # 10MB 파일이 서버 메모리에 올라감
  S3.put_object(bucket: 'images', key: file.original_filename, body: file.read)
end
```

**문제**: 동시 업로드 10개면 서버 메모리 100MB 점유. 대용량 이미지가 많은 서비스에서는 서버가 OOM(Out of Memory)으로 죽을 수 있다.

### (B) Pre-signed URL 직접 업로드 (권장)

```
Client → App Server (URL 발급)
Client → S3 (직접 업로드)
```

앱 서버는 S3 업로드용 임시 URL만 발급하고, 클라이언트가 S3에 직접 올린다. 서버는 바이너리 데이터를 전혀 다루지 않는다.

```ruby
# Rails — Pre-signed URL 발급 (서버 부담 거의 없음)
def presign
  url = S3.presigned_url(:put_object,
    bucket: 'images',
    key: "uploads/#{SecureRandom.uuid}.webp",
    content_type: 'image/webp',
    expires_in: 300  # 5분 유효
  )
  render json: { upload_url: url }
end
```

```javascript
// 클라이언트 — S3에 직접 업로드
const { upload_url } = await fetch('/api/presign').then(r => r.json());

await fetch(upload_url, {
  method: 'PUT',
  headers: { 'Content-Type': 'image/webp' },
  body: file  // S3로 직접 전송
});
```

서버 메모리 사용량: 거의 0. 동시 업로드 1,000개도 서버에 영향 없다.

### (C) Chunked / Resumable Upload (tus 프로토콜)

대용량 파일(50MB+)이나 불안정한 네트워크에서 유용하다. 파일을 작은 chunk로 나눠서 보내고, 중단되면 이어서 업로드한다.

```javascript
// tus-js-client
import * as tus from 'tus-js-client';

const upload = new tus.Upload(file, {
  endpoint: 'https://your-server.com/files/',
  chunkSize: 5 * 1024 * 1024,  // 5MB chunks
  retryDelays: [0, 1000, 3000, 5000],
  onProgress: (bytesUploaded, bytesTotal) => {
    const pct = (bytesUploaded / bytesTotal * 100).toFixed(1);
    console.log(`${pct}%`);
  }
});

upload.start();
```

### 비교 정리

| 방식 | 서버 부하 | 구현 난이도 | 적합한 상황 |
|------|----------|------------|------------|
| Multipart | 높음 | 쉬움 | 소규모, 작은 파일 |
| Pre-signed URL | 없음 | 보통 | 대부분의 서비스 (권장) |
| Chunked (tus) | 낮음 | 높음 | 대용량, 불안정 네트워크 |

---

## 5. 서버사이드 이미지 처리 파이프라인

업로드 후 리사이징을 서버에서 처리할 때, 동기적으로 하면 API 응답이 느려진다. 비동기 파이프라인을 구성하는 게 정석이다.

```
Client → S3 (원본 업로드)
         ↓ (S3 Event Trigger)
      Lambda / Worker
         ↓
  리사이징 + WebP 변환 + 메타데이터 추출
         ↓
      S3 (변환본 저장) + DB (URL 기록)
```

### AWS Lambda 예시

```python
import boto3
from PIL import Image
from io import BytesIO

s3 = boto3.client('s3')

def handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    # 원본 다운로드
    response = s3.get_object(Bucket=bucket, Key=key)
    img = Image.open(BytesIO(response['Body'].read()))

    sizes = {'thumb': 200, 'medium': 800, 'large': 1600}

    for name, width in sizes.items():
        resized = img.copy()
        resized.thumbnail((width, width), Image.LANCZOS)

        buffer = BytesIO()
        resized.save(buffer, 'WEBP', quality=80)
        buffer.seek(0)

        new_key = key.replace('uploads/', f'processed/{name}/')
        new_key = new_key.rsplit('.', 1)[0] + '.webp'

        s3.put_object(
            Bucket=bucket, Key=new_key,
            Body=buffer, ContentType='image/webp'
        )

    return {'statusCode': 200}
```

원본 업로드 즉시 Lambda가 트리거되어 thumb(200px), medium(800px), large(1600px) 세 가지 WebP를 만든다. API 서버는 전혀 관여하지 않는다.

---

## 6. Lazy Loading & Placeholder

이미지 최적화는 파일 크기만의 문제가 아니다. **언제 로드하느냐**도 중요하다.

### Native Lazy Loading

```html
<img src="/images/photo.webp" alt="photo" loading="lazy">
```

브라우저가 뷰포트에 가까워질 때까지 이미지 요청을 지연한다. 한 줄 추가로 초기 페이지 로드를 대폭 줄일 수 있다.

### LQIP (Low Quality Image Placeholder)

이미지가 로드되기 전에 흐린 미리보기를 보여주는 기법이다. Medium, Pinterest 등에서 사용한다.

```javascript
// 빌드 타임에 10px 크기의 블러 이미지 생성
const placeholder = await sharp('photo.jpg')
  .resize(10)
  .blur()
  .toBuffer();

const base64 = `data:image/jpeg;base64,${placeholder.toString('base64')}`;
// → "data:image/jpeg;base64,/9j/4AAQSkZJRg..."  (약 200bytes)
```

```html
<!-- 초기: 블러 placeholder 표시 -->
<img
  src="data:image/jpeg;base64,/9j/4AAQSkZJRg..."
  data-src="/images/photo.webp"
  class="lazy-img"
  style="filter: blur(20px); transition: filter 0.3s;"
>
```

```javascript
// Intersection Observer로 실제 이미지 로드
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const img = entry.target;
      img.src = img.dataset.src;
      img.onload = () => img.style.filter = 'none';
      observer.unobserve(img);
    }
  });
});

document.querySelectorAll('.lazy-img').forEach(img => observer.observe(img));
```

사용자 경험이 크게 달라진다: 빈 공간 → 흐린 미리보기 → 선명한 이미지. 로딩을 "기다리는" 느낌이 줄어든다.

---

## 7. 클라이언트 사이드 리사이징 (업로드 전 처리)

서버에 올리기 전에 브라우저에서 미리 줄이면, 업로드 시간과 서버 비용을 동시에 절약할 수 있다.

```javascript
function resizeBeforeUpload(file, maxWidth = 1600, quality = 0.8) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');

      let { width, height } = img;
      if (width > maxWidth) {
        height = Math.round(height * maxWidth / width);
        width = maxWidth;
      }

      canvas.width = width;
      canvas.height = height;
      canvas.getContext('2d').drawImage(img, 0, 0, width, height);

      canvas.toBlob(resolve, 'image/webp', quality);
    };
    img.src = URL.createObjectURL(file);
  });
}

// 사용 예
const input = document.querySelector('input[type="file"]');
input.addEventListener('change', async (e) => {
  const original = e.target.files[0];  // 8MB JPEG
  const resized = await resizeBeforeUpload(original);  // ~500KB WebP

  console.log(`${(original.size/1024/1024).toFixed(1)}MB → ${(resized.size/1024).toFixed(0)}KB`);

  // resized Blob을 서버에 업로드
  const formData = new FormData();
  formData.append('image', resized, 'photo.webp');
  await fetch('/api/upload', { method: 'POST', body: formData });
});
```

5MB 원본이 500KB WebP로 줄어드니 업로드 시간이 10분의 1이 된다. 모바일 환경에서 특히 효과적이다.

---

## 실무 조합 추천

모든 기법을 다 쓸 필요는 없다. 서비스 규모에 맞게 조합하면 된다:

| 단계 | 개인 블로그 / 소규모 | 중규모 서비스 | 대규모 서비스 |
|------|---------------------|-------------|-------------|
| 포맷 | WebP 변환 | WebP + AVIF | WebP + AVIF + `<picture>` |
| 리사이징 | 빌드 타임 고정 크기 | 빌드 타임 다중 크기 | CDN on-the-fly |
| 업로드 | Multipart | Pre-signed URL | Pre-signed URL + tus |
| 처리 | 로컬 스크립트 | Lambda 파이프라인 | Lambda + SQS 큐 |
| 로딩 | `loading="lazy"` | Lazy + LQIP | Lazy + LQIP + priority hints |
| CDN | GitHub Pages / Vercel | CloudFront | Cloudflare + imgix |

---

## 결론

이미지 최적화는 한 가지 기법이 아니라, **포맷 → 사이즈 → 업로드 → 처리 → 전달 → 로딩** 전체 파이프라인의 문제다. 어디서 시작해야 할지 모르겠다면, 이 순서를 추천한다:

1. **WebP 변환** — 가장 쉽고 효과 큼 (평균 30~50% 절감)
2. **`loading="lazy"`** — 한 줄 추가로 초기 로드 개선
3. **반응형 srcset** — 모바일 사용자 경험 개선
4. **Pre-signed URL** — 서버 부하 제거
5. **CDN on-the-fly** — 스케일이 커지면 고려

작은 것부터 하나씩. 완벽한 파이프라인을 한 번에 구축하려 하지 말고, 지금 가장 아픈 곳부터 개선하면 된다.

---
