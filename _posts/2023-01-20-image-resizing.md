---
layout: post
title:  "Marvin 라이브러리를 활용한 S3에 리사이징된 이미지 업로드"
date:   2023-01-20 13:11:04 +0900
categories: [Spring, troubleshooting]
tags: [spring, troubleshooting]
---

# 이미지 리사이징을 하게 된 계기

S3 프리티어 저장공간의 수용량이 90%가 넘으면서 이미지에 대한 용량관리를 해야할 필요성을 느꼈다.   
초고화질 이미지가 우리의 서비스에서는 굳이 원본상태로 보일 필요성을 못느꼈다. 400px*300px 정도의 이미지면 충분한 서비스에 배경화면 2450x1440 사이즈를 그대로 저장할 필요가 없었다. 

## #1 해결과정 3mb 이상 이미지를 허용하지않는다.  
단순하게 용량을 제한 하는것 만으로도 무지막지한 용량의 이미지를 차단할 수 있는 장점이 있었다.  
또한, java.awt.Graphics2D, Imgscalr, Marvin 등 이미지 리사이징 라이브러리 사용 시 ,이미지IO와 변환과정에서 3mb이상의 이미지는 리사이징하는데 상당히 오랜 시간이 소요된다.  
따라서, 아래와 같이 multipart 사이즈에 제약 조건을 application.yml파일에 설정하였다.

```yml
spring:
  servlet:
    multipart:
      max-file-size: 3MB
      max-request-size: 3MB
```

##  #2 해결과정  AWS LAMBDA
앞서 언급한 3mb이상의 이미지 IO 발생 시, 제약없이 빠르게 업로드 후 리사이징 할 수 있는 방법이 있었다. CloudFront와 AWS LAMBDA를 사용하여 `온디멘드 방식의 리사이징`을 하는 것이다.    
Serverless인 람다에서 이미지를 리사이징하는 방법은 저장된 큰 이미지의 용량을 줄이고 좀 더 빠른 업로드를 하는 이점은 있었으나, `하나의 이미지가 원본 S3공간과 리사이징된 S3공간 두 곳으로 저장`되어 관리포인트가 더 늘어났고 그 결과 용량절감의 효과가 떨어졌다.쇼핑몰처럼 원본이미지가 필요한 서비스가 아니기에 이 방법을 선택하지 않았다.  

## #3 해결과정 Marvin 라이브러리 사용
### java.awt.Graphics2D 라이브러리
처음엔 Graphics2D를 이용해서 구현하였으나, 이미지가 점묘화되는 현상으로 다른 방안을 찾아야했다.
<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/java/Graphics2D.png?raw=true" width=800>  

### Marvin 라이브러리
marvin 라이브러리를 사용하기 위해선 build.gradle에 아래의 내용을 추가해야한다.
```java
implementation 'com.github.downgoon:marvin:1.5.5'
implementation 'com.github.downgoon:MarvinPlugins:1.5.5'
```
S3에 업로드하는 과정에서 List<Mutipartfile>의 형태의 데이터를 이미지 리사이징하는 로직에만 포커싱하여 설명할 것이다.  

s3업로드 하는 코드는 추후에 올리겠다.
```java
//S3UploadService
public List<String> uploadAsList(List<MultipartFile> multipartFile) {
        log.info("uploadAsList tx start");
        List<String> imageList = new ArrayList<>(); // 리사이징된 이미지를 저장할 공간

        multipartFile.forEach(image -> {
        if(Objects.requireNonNull(image.getContentType()).contains("image")) {  //이미지가 있다면 실행하고 없다면 패스

            String fileName = createFileName(image.getOriginalFilename());//중복되지않게 이름을  randomUUID()를 사용해서 생성함
            String fileFormat = image.getContentType().substrin(image.getContentType().lastIndexOf("/") + 1); //파일 확장자명 추출

            MultipartFile resizedImage = resizer(fileName, fileFormat, image, 400); //오늘의 핵심 메서드

//========아래부터는 리사이징 된 후 이미지를 S3에다가 업로드하는 방법이다.=========
            ObjectMetadata objectMetadata = new ObjectMetadata();
            objectMetadata.setContentLength(resizedImage.getSize()); //사이즈를 전달한다.
            objectMetadata.setContentType(resizedImage.getContentType()); //이미지 타입을 전달한다.

            try (InputStream inputStream = resizedImage.getInputStream()) {
                s3.putObject(new PutObjectRequest(bucket, fileName, inputStream, objectMetadata)
                        .withCannedAcl(CannedAccessControlList.PublicRead));
            } catch (IOException e) {
                throw new BusinessLogicException(ExceptionCode.FILEUPLOAD_FAILED);
            }

            imageList.add(s3.getUrl(bucket, fileName).toString());
            }
        });
        log.info("uploadAsList tx end");
        return imageList;
    }
```
위처럼 UUID를 사용하여 난수화된 이름, 파일 확장자명, 리스트에서 나온 이미지, 희망하는 너비값을 `resizer 메서드`에게 넘기면서 리사이징이 시작된다.
### resizer 메서드 details
```java

    @Transactional 
    public MultipartFile resizer(String fileName, String fileFormat, MultipartFile originalImage, int width) {

        try {
            BufferedImage image = ImageIO.read(originalImage.getInputStream());// MultipartFile -> BufferedImage Convert 

            int originWidth = image.getWidth();
            int originHeight = image.getHeight();

            // origin 이미지가 400보다 작으면 패스
            if(originWidth < width)
                return originalImage;

            MarvinImage imageMarvin = new MarvinImage(image);

            Scale scale = new Scale();
            scale.load();
            scale.setAttribute("newWidth", width);
            scale.setAttribute("newHeight", width * originHeight / originWidth);//비율유지를 위해 높이 유지
            scale.process(imageMarvin.clone(), imageMarvin, null, null, false);

            BufferedImage imageNoAlpha = imageMarvin.getBufferedImageNoAlpha();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(imageNoAlpha, fileFormat, baos);
            baos.flush();

            return new CustomMultipartFile(fileName,fileFormat,originalImage.getContentType(), baos.toByteArray());

        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "파일을 줄이는데 실패했습니다.");
        }
    }
```
1. marvin은 멀티쓰레드, 병렬처리방식으로 이미지를 리사이징한다. 트랜잭션 선언을 안하면  충돌이 일어나서 Input not set error 혹은 null point exception을 마주하게된다. `@Transactional을 선언`하자!  
2. marvin 라이브러리에서 생성자 요구사항이 BufferedImage 형태이므로 ImageIO.read를 활용하여 BufferedImage로 변경할 필요가 있다.
3. 비율을 유지하기 위해 너비값 * 원래너비/원래높이를 이용해 적용했다.
4. 리사이징 작업이 끝나면 byte[]타입으로 저장되는데 이를 다시 s3에서 요구하는 MultipartFile로 변환하기 위해 MultipartFile interface를 implement 받아 구현했다.  
단순 타입변환이라 생성자만 잘 만들어주면 된다.

```java
public class CustomMultipartFile implements MultipartFile {

    private final String name;

    private String originalFilename;

    private String contentType;

    private final byte[] content;
    boolean isEmpty;


    public CustomMultipartFile(String name, String originalFilename, String contentType, byte[] content) {
        Assert.hasLength(name, "Name must not be null");
        this.name = name;
        this.originalFilename = (originalFilename != null ? originalFilename : "");
        this.contentType = contentType;
        this.content = (content != null ? content : new byte[0]);
        this.isEmpty = false;
    }

    @Override
    public String getName() {
        return this.name;
    }

    @Override
    public String getOriginalFilename() {
        return this.originalFilename;
    }

    @Override
    public String getContentType() {
        return this.contentType;
    }

    @Override
    public boolean isEmpty() {
        return (this.content.length == 0);
    }

    @Override
    public long getSize() {
        return this.content.length;
    }

    @Override
    public byte[] getBytes() throws IOException {
        return this.content;
    }

    @Override
    public InputStream getInputStream() throws IOException {
        return new ByteArrayInputStream(this.content);
    }

    @Override
    public void transferTo(File dest) throws IOException, IllegalStateException {
        FileCopyUtils.copy(this.content, dest);
    }

}
```
## 결과 

<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/java/%EC%9D%B4%EB%AF%B8%EC%A7%80%20%EB%A6%AC%EC%82%AC%EC%9D%B4%EC%A7%95.png?raw=true" width=800>

눈에 띄게 줄어든 용량과 이미지가 꺠지지 않음을 확인 할 수 있었다.
  
또한 원본 이미지들을 다운로드 후, 다시 업로드는 하는 형태로 s3 프리티어 저장공간도 45%정도 확보하는 결과를 도출해 냈다.  
<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/java/123123.png?raw=true">
## 출처
[ImageIo 공식문서](https://docs.oracle.com/javase/7/docs/api/javax/imageio/ImageIO.html)  
[Maven repo](https://marvinproject.sourceforge.net/en/tutorials.html)
[Baeldung](https://www.baeldung.com/java-resize-image)