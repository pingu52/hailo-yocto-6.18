# Hailo15 6.18 FIT 생성 및 부팅 확인

동봉된 DTB와 FIT 바이너리는 공개 **Hailo15 EVB**용이다. 다른 보드의 DTB와
대체하면 안 된다. `fitImage-6.18-public`은 미서명 샘플이며, 최신 소스의
수정이나 대상 보드의 부팅 성공을 보증하는 산출물이 아니다.

## 구성

- `fitImage-6.18-public`: SHA-256 해시를 포함한 공개 EVB용 미서명 FIT 샘플
- `hailo15-evb-2-camera-vpu.dtb`: 공개 Hailo15 EVB device tree
- `618-public.its`, `make-fit.sh`: 공개 EVB용 FIT 생성 도구
- `618-truen.its`, `make-fit-truen.sh`: 외부에서 제공한 DTB와 기존 키를 사용하는 서명 도구
- `rootfs-6.18-minimal.squashfs`: gzip SquashFS 형식의 최소 rootfs 샘플

## 공개 EVB용 FIT 생성

`make-fit.sh`는 gzip 커널과 동봉된 EVB DTB를 **미서명** FIT로 묶는다.
SHA-256 해시나 `mkimage -r`만으로 RSA 서명이 생성되지는 않는다.
필수 도구는 Bash, GNU coreutils, gzip, `mkimage`, PATH에 있는 `dtc`이다.

```bash
artifact_dir=$(mktemp -d /home/pingu52/work/artifacts/hailo-6.18-fit-XXXXXXXX)
MKIMAGE=/절대/경로/mkimage ./boot-6.18/make-fit.sh \
    --public-unsigned /절대/경로/Image.gz "$artifact_dir/public"
```

출력 디렉터리는 새 경로여야 한다. 기존 파일은 덮어쓰지 않는다.
결과는 `report.md`, `build.log`, `image-info.log`, `SHA256SUMS`에 기록한다.
종료 코드 0은 생성 성공일 뿐, 서명 검증이나 부팅 성공을 의미하지 않는다.
잘못된 사용법은 2, 생성 실패는 0이 아닌 값을 반환한다.

## 기존 키로 서명 FIT 생성

`make-fit-truen.sh`는 기존 키로 커널과 DTB configuration을 서명하고,
별도로 공급한 기존 U-Boot 제어 DTB의 필수 공개키로 검증한다. 개인키와
보드 전용 DTB는 외부에서 제공하며, 키를 생성하거나 보드의 신뢰 설정을 바꾸지 않는다.

필수 도구는 Bash, GNU coreutils, gzip, `mkimage`, `fit_check_sign`, `fdtget`,
PATH에 있는 `dtc`이다. `MKIMAGE`, `FIT_CHECK_SIGN`, `FDTGET`으로 실행 파일을
지정할 수 있다. `mkimage`는 개인키 파일 직접 지정 옵션 `-G`를 지원해야 한다.

```bash
artifact_dir=$(mktemp -d /home/pingu52/work/artifacts/hailo-6.18-signed-fit-XXXXXXXX)
./boot-6.18/make-fit-truen.sh \
    /절대/경로/Image.gz \
    /절대/경로/대상-보드.dtb \
    /절대/경로/기존-개인키.pem \
    /절대/경로/기존-uboot-control.dtb \
    "$artifact_dir/signed"
```

- 제어 DTB는 대상 보드가 실제 신뢰하는 `key-customer` 공개키와
  `required=conf`, `algo=sha256,rsa3072` 속성을 포함해야 한다.
- 입력 커널은 gzip 압축된 ARM64 Image이다. Linux용 DTB와 U-Boot 제어 DTB를
  구분해야 하며, 도구가 보드별 DTB 호환성까지 판정하지는 않는다.
- 개인키는 원본 경로로만 전달하며 산출물에 복사하지 않는다.
  기존 출력 디렉터리는 거부하고, 필수 서명 검증을 통과한 경우에만
  `fitImage-6.18-truen-signed`를 생성한다. `candidate.itb`는 배포하지 않는다.
- 결과는 `report.md`, `build.log`, `verify.log`, `image-info.log`, `SHA256SUMS`에
  기록한다. 종료 코드 0은 생성·호스트 서명 검증 성공이며, 잘못된 사용법은 2,
  검사·생성 실패는 0이 아닌 값을 반환한다. 플래시나 부팅은 수행하지 않는다.

## 시험 rootfs의 콘솔 암호

`make-console-rootfs.py`는 root 계정이 잠긴 SquashFS를 입력받아 콘솔 암호를
설정한 새 이미지를 만든다. `fakeroot`, `unsquashfs`, `mksquashfs`, `openssl`,
Python 3.9 이상이 필요하다. 암호는 stdin으로만 공급하며 인자·환경변수에 넣지 않는다.
`fakeroot python3 boot-6.18/make-console-rootfs.py <원본.squashfs> <새 artifact 경로>`로
실행한다. 원본은 보존하고 기존 출력 디렉터리는 거부한다. 종료 코드 0은 생성 및
shadow 읽기 검증 성공이다. `--self-test`는 계정 변경 범위와 입력 거부를 확인한다.
결과 디렉터리에는 암호 해시를 포함한 rootfs가 있으므로 공유·커밋하지 않는다.

## 일반 부팅 확인

- 대상 보드의 메모리 배치와 FIT의 load/entry 주소를 먼저 대조한다.
  공개 EVB 샘플의 커널 주소는 `0x80c00000`, FDT 주소는 `0x80800000`이다.
- SquashFS rootfs를 사용할 파티션과 커널 `root=` 인자를 실제 장치에서 확인한다.
  커널에는 `CONFIG_SQUASHFS=y`, `CONFIG_SQUASHFS_ZLIB=y`가 필요하다.
- 대상 U-Boot의 FIT 서명 정책을 충족하는 이미지로 `bootm`을 실행한다.
  필수 서명 검증을 우회하거나 기존 신뢰 키를 변경하지 않는다.
- 부팅 파일과 rootfs를 교체하기 전에 정상 슬롯과 복구 경로를 확보한다.
  보드별 파티션 번호·메뉴 조작·환경 저장 절차는 이 문서에서 지정하지 않는다.
- 로그인 후 다음 명령으로 커널 버전과 실제 rootfs를 확인한다.

```sh
uname -r                 # 예상 버전: 6.18.52-hailo
cat /proc/cmdline
awk '$2 == "/" {print}' /proc/mounts
dmesg | grep -i gem
```

커널 실행, rootfs 마운트, init, 로그인, 이더넷 통신은 각각 확인한다.
이 검증만으로 ISP·DSP·영상 기능까지 정상이라고 판정하지 않는다.
