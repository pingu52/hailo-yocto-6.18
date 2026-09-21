#
# Hailo15 EVB (2-camera, VPU) - Linux 6.18 LTS kernel
#
# wrynose 6.0 기반, Hailo-15 ipfw 커널을 Yocto 체계로 빌드하는 레시피.
# 빌드 대상 소스 트리는 회사 meta-hailo-soc(1.12.1, 커널 5.15)이 아니라
# 이 레이어와 같은 저장소의 개인 포팅 트리(~/work/hailo-yocto-6.18/kernel)를
# externalsrc로 직접 가리킨다.
#
# 설계 근거 (wrynose 6.0 클래스 실측 기반):
# - base `kernel` 클래스는 S/B/KBUILD_OUTPUT 분리(out-of-tree)를 전제로 하지만,
#   이 레시피는 S == B == EXTERNALSRC 트리(인-트리 빌드)로 고정한다.
#   인-트리로 고정한 이유: do_compile/do_configure/DTB의 모든 oe_runmake 호출이
#   -C ${S} O=${B}를 붙이지 않고 cwd에서 make를 돌리는데, S==B이면 cwd(=트리)
#   에서 `make <target>`이 그대로 인-트리 빌드가 되어 검증된 159MB 빌드와 동일.
# - externalsrc.bbclass는 S를 외부 트리로 옮기면서 cleandirs가 트리를 지우는 것을
#   차단(is_path_parent). do_clean/do_unpack의 ${S} cleandirs에서 트리 제외.
# - do_deploy 본문은 base kernel의 kernel_do_deploy(EXPORT_FUNCTIONS do_deploy)이며,
#   DTB 데플리는 kernel.bbclass가 인계하는 kernel-devicetree의 do_deploy:append가 담당.
# - wrynose에는 nodistro.conf/meta-poky가 없어 distro conf(하일 conf/distro/hailo.conf)
#   와 minimal TCMODE/TCLIBC를 레이어에서 공급.
#
SUMMARY = "Hailo15 kernel 6.18 LTS (external tree, wrynose 6.0)"
DESCRIPTION = "Hailo-15 based ipfw kernel 6.18 built from the local hailo-yocto-6.18 tree"
LICENSE = "GPL-2.0-only"
# 트리 루트의 COPYING을 절대경로 file://로 참조 (외부 트리는 SRC_URI unpack 대상 아님)
LIC_FILES_CHKSUM = "file:///home/pingu52/work/hailo-yocto-6.18/kernel/COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

LINUX_VERSION = "6.18"
LINUX_VERSION_EXTENSION = ""
# base kernel은 do_kernel_version_sanity_check를 addtask 하지 않으나,
# 혹시 모를 버전 정합성 체크에 대비해 PV와 명시적으로 일치.
PV = "6.18.52"
KERNEL_VERSION_SANITY_SKIP = "1"

# base kernel 클래스 + 외부 트리 빌드 클래스
inherit kernel
inherit externalsrc

# Hailo15 외부 트리 (인-트리 빌드: S == B == 아래 경로)
HAILO_TREE = "/home/pingu52/work/hailo-yocto-6.18/kernel"
EXTERNALSRC = "${HAILO_TREE}"
EXTERNALSRC_BUILD = "${HAILO_TREE}"

# uImage/u-boot 계열 부가 클래스 비활성 (Image만 빌드, u-boot-tools-native 의존 제거)
KERNEL_CLASSES = ""

# arm64 부팅 이미지 (uImage 아님). 1.12.1 machine conf는 fitImage+u-boot-tfa.itb를
# 쓰지만, 커널 단독 검증 목적에서는 부팅 가능한 Image + DTB만 필요.
KERNEL_IMAGETYPE = "Image"
# Hailo EVB 2-camera VPU 디바이스트리 (make target = hailo/hailo15-evb-2-camera-vpu.dtb)
KERNEL_DEVICETREE = "hailo/hailo15-evb-2-camera-vpu.dtb"

# 검증된 39개 Hailo 옵션 config를 레이어에 self-contained로 공급.
# do_configure:prepend에서 ${B}(=S=트리)의 .config로 복사해 빌드.
# file:// 로 unpack를 보존(externalsrc가 do_fetch/do_unpack 유지).
SRC_URI = "file://hailo15.config"

# 인-트리 빌드: S==B 이므로 .config는 트리 내부. 검증된 config로 덮어써
# 빌드 결과를 개발 트리의 .config 상태에 의존하지 않도록 결정적으로 고정.
do_configure:prepend() {
	cfg="${THISDIR}/linux-yocto-hailo/hailo15.config"
	[ -f "${cfg}" ] || die "hailo15.config not found at ${cfg}"
	cp -f "${cfg}" "${B}/.config"
	bbnote "hailo15: verified config staged to ${B}/.config"
}

# arm64: CROSS_COMPILE = aarch64-linux-gnu- (wrynose gcc-cross가 TARGET_PREFIX로 공급)
# kernel.bbclass는 export CROSS_COMPILE = "${TARGET_PREFIX}" 로 자동 공급.

# KERNEL_LOCALVERSION: 6.3+에서 로컬 버전을 .scmversion이 아닌 이 변수로 부여
KERNEL_LOCALVERSION = "-hailo"

# 모듈 타깃/패키징은 기본 유지 (CONFIG_MODULES=y)
