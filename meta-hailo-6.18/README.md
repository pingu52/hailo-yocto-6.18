# Hailo 6.18 빌드 및 검증

Hailo15 EVB의 Linux 6.18.52 커널과 최소 rootfs를 Yocto Wrynose에서 빌드한다.
레시피는 같은 저장소의 `kernel/`을 `externalsrc`로 사용하며, 저장된
`hailo15.config`를 적용한다. ISP·DSP 전체 API 이식과 실장비 동작 검증은 포함하지 않는다.

## 사용법

- 빌드 환경: `/home/pingu52/work/yocto-build-6.18/build`
- 소스: `/home/pingu52/work/hailo-yocto-6.18/kernel`
- `MACHINE`: `hailo15-evb-2-camera-vpu`, `DISTRO`: `hailo`
- `BBLAYERS`에 Wrynose의 `meta`와 이 레이어를 등록한다.
- 호스트 검증 도구: Bash, awk, GNU binutils, file, tar, gzip, zstd, e2fsprogs.

빌드 환경에서 다음 명령으로 커널과 rootfs의 로그를 각각 보관한다.
병렬도는 `conf/local.conf`의 `BB_NUMBER_THREADS`, `PARALLEL_MAKE`로 지정한다.

```bash
artifact_dir=$(mktemp -d /home/pingu52/work/artifacts/hailo-6.18-build-XXXXXXXX)
cd /home/pingu52/work/yocto-build-6.18/build
export BBPATH="$PWD" BUILDDIR="$PWD" LC_ALL=C.UTF-8
export PATH="/home/pingu52/work/yocto-build-6.18/poky/scripts:/home/pingu52/work/yocto-build-6.18/poky/bitbake/bin:$PATH"
bitbake linux-yocto-hailo > "$artifact_dir/kernel-build.log" 2>&1 &&
bitbake core-image-minimal > "$artifact_dir/rootfs-build.log" 2>&1
```

빌드 성공 후 검증을 실행한다. `ART`를 생략하면 공유 artifact 경로 아래에
고유한 디렉터리를 생성한다. `BUILD`, `KERNEL_TREE`로 검사 경로를 지정할 수 있다.

```bash
cd /home/pingu52/work/hailo-yocto-6.18
ART="$artifact_dir/verification" ./verify-yocto-build.sh \
    "$artifact_dir/kernel-build.log" "$artifact_dir/rootfs-build.log"
ART="$artifact_dir/self-test" ./verify-yocto-build.sh --self-test
```

실행 결과는 `ART/report.md`, 상세 명령과 출력은 `ART/checks.log`에 기록된다.
모든 검사에 통과하면 종료 코드 0, 검사 실패는 1, 잘못된 사용법은 2를 반환한다.

## 검사 항목

- 두 빌드 로그의 성공 요약과 `ERROR` 유무.
- `hailo15-6.18.fragment`의 `y`, `m`, `n`, 숫자·문자열 값과 최종 `.config`의 일치.
- ARM64 `Image` 형식, 소스 트리의 Image·DTB와 배포 파일의 일치.
- `vmlinux`의 SCMI·SoC·PWM·pinctrl·PMU·SCU log·CPLD·GPIO 핵심 심볼 각각의 존재.
- 모듈 아카이브와 rootfs 압축 무결성, ext4의 읽기 전용 `e2fsck -fn` 검사.
- Hailo PHY·USB 모듈 4개의 모듈 아카이브·rootfs·manifest 포함 여부.
- 배포 산출물의 SHA-256 기록.
- `--self-test`: 정상 설정과 `y/m/n/숫자` 변경, 비활성 옵션 누락, 빈 fragment의 회귀 검사.

배포 디렉터리는 `build/tmp/deploy/images/hailo15-evb-2-camera-vpu/`이며,
`Image`, DTB, `modules-*.tgz`, rootfs의 ext4·tar.zst·manifest를 제공한다.
모듈은 rootfs에 설치하지만 USB gadget의 자동 실행 정책은 추가하지 않는다.
이 검사의 통과는 보드 부팅이나 SCMI·PWM·ISP·DSP 실동작의 성공을 뜻하지 않는다.
