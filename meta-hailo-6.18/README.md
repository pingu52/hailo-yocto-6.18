# meta-hailo-6.18

Hailo-15 기반 ipfw 커널 6.18을 wrynose 6.0 Yocto 체계에서 빌드하는 레이어.

## 목적

- 5.15 → 6.18 LTS 승격(보안인증 EOL 대응)의 검증 빌드를 Yocto 체계로 재현한다.
- 빌드 대상은 이 저장소 루트의 `kernel/` 디렉터리(개인 6.18 포팅 트리)이며,
  회사 `meta-hailo-soc`(1.12.1, 커널 5.15)과 무관하다.

## 구성

```
meta-hailo-6.18/
├── conf/
│   ├── layer.conf                       # BBPATH += ${LAYERDIR} (conf/distro·conf/machine 로드)
│   ├── distro/hailo.conf                # DISTRO="hailo" (wrynose에 nodistro/meta-poky가 없어 레이어 공급)
│   └── machine/hailo15-evb-2-camera-vpu.conf
│       # arch-arm64.inc 체인 (plain aarch64, -mcpu 없음) -> ARCH=arm64
└── recipes-kernel/linux/
    ├── linux-yocto-hailo_6.18.bb        # inherit kernel externalsrc (외부 트리 in-트리 빌드)
    └── linux-yocto-hailo/
        └── hailo15.config               # 검증된 39개 Hailo 옵션 (1.12.1 defconfig 기준)
```

## 설계

- `inherit kernel externalsrc`:
  - `S == B == /home/pingu52/work/hailo-yocto-6.18/kernel` (인-트리 빌드 고정).
  - `do_compile`의 `oe_runmake Image`가 트리 cwd에서 실행되어
    `make ARCH=arm64` 159MB vmlinux와 동일한 조건.
  - `externalsrc`가 `do_clean`/`do_unpack`의 cleandirs가 트리를 지우는 것을 차단.
- `SRC_URI = "file://hailo15.config"`: 검증된 config를 self-contained로 공급,
  `do_configure:prepend`에서 `${B}/.config`로 복사해 결정적으로 빌드.
- `KERNEL_IMAGETYPE = "Image"` (arm64, uImage 아님),
  `KERNEL_DEVICETREE = "hailo/hailo15-evb-2-camera-vpu.dtb"`.
- `do_deploy`는 base kernel의 `EXPORT_FUNCTIONS do_deploy` + `kernel-devicetree`
  inherit가 Image/DTB/module tarball까지 제공 → 별도 태스크 본문 불필요.
- wrynose 6.0에 `nodistro.conf`/`meta-poky`가 없어 `DISTRO="hailo"`를 이 레이어의
  `conf/distro/hailo.conf`가 공급 (TCMODE/TCLIBC 고정, defaultsetup.conf 자동 include).

## 빌드

```sh
cd ~/work/yocto-build-6.18/build
OEROOT=~/work/yocto-build-6.18/poky
export BBPATH=$PWD BUILDDIR=$PWD PYTHONPATH=$OEROOT/bitbake/lib LC_ALL=C.UTF-8
$OEROOT/bitbake/bin/bitbake linux-yocto-hailo -j $(nproc)
```

또는 `build.sh` (이 레이어와 같은 저장소 루트).

### 산출물

- `build/tmp/deploy/images/hailo15-evb-2-camera-vpu/`
  - `Image-6.18.52-r0-hailo15-evb-2-camera-vpu-<ts>` (+ `hailo15-evb-2-camera-vpu` 심볼릭 링크)
  - `hailo/hailo15-evb-2-camera-vpu.dtb`
  - `modules-*.tgz`
- vmlinux/`.o`/`.config`는 인-트리라 소스 트리(`kernel/`) 안에 남는다.

## 검증 기준

- `bitbake linux-yocto-hailo` 성공 (984 task).
- deploy 디렉터리에 Image + DTB + modules-*.tgz 실재.
- 트리 `vmlinux`에 Hailo 핵심 심볼(`scmi_hailo`, `pwm_hailo`, `pinctrl_hailo`,
  `hailo_soc`, `hailo_noc_pmu`, `scu_log`) 실재 (nm 확인).
- VPU/ISP 실동작 검증은 실장비(보드) 필요 — 자동 검증은 vmlinux/DTB 생성까지만.
