#!/usr/bin/env bash
# 사용법: ./verify-yocto-build.sh <커널 빌드 로그> <rootfs 빌드 로그>
# ART로 증거 디렉터리를 지정한다. --self-test는 설정 비교의 회귀를 검사한다.
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUILD=${BUILD:-/home/pingu52/work/yocto-build-6.18/build}
KERNEL_TREE=${KERNEL_TREE:-$ROOT/kernel}
DTC=${DTC:-$KERNEL_TREE/scripts/dtc/dtc}
FDTGET=${FDTGET:-fdtget}
FDTOVERLAY=${FDTOVERLAY:-$KERNEL_TREE/scripts/dtc/fdtoverlay}
MACHINE=hailo15-evb-2-camera-vpu
DEPLOY="$BUILD/tmp/deploy/images/$MACHINE"

compare_config() {
  awk '
    FNR == NR {
      if ($0 ~ /^CONFIG_[A-Za-z0-9_]+=/) {
        key = substr($0, 1, index($0, "=") - 1)
        expected[key] = substr($0, index($0, "=") + 1)
      } else if ($0 ~ /^# CONFIG_[A-Za-z0-9_]+ is not set$/) {
        expected[$2] = "n"
      }
      next
    }
    /^CONFIG_[A-Za-z0-9_]+=/ {
      key = substr($0, 1, index($0, "=") - 1)
      actual[key] = substr($0, index($0, "=") + 1)
    }
    /^# CONFIG_[A-Za-z0-9_]+ is not set$/ { actual[$2] = "n" }
    END {
      for (key in expected) {
        count++
        value = key in actual ? actual[key] : "MISSING"
        if (value != expected[key]) {
          printf "%s expected=%s actual=%s\n", key, expected[key], value
          misses++
        }
      }
      printf "CONFIG_COUNT=%d MISMATCH_COUNT=%d\n", count, misses
      exit (count == 0 || misses != 0)
    }
  ' "$1" "$2"
}

if [[ ${1:-} != --self-test && $# != 2 ]]; then
  echo "사용법: $0 <커널 빌드 로그> <rootfs 빌드 로그> 또는 --self-test" >&2
  exit 2
fi

ART=${ART:-$(mktemp -d /home/pingu52/work/artifacts/hailo-6.18-verify-XXXXXXXX)}
mkdir -p "$ART" || exit 1
REPORT="$ART/report.md"
PASS=0
FAIL=0
printf '# Hailo 6.18 검증 결과\n\n- 실행 시각: %s\n- 소스 HEAD: %s\n\n| 검사 | 결과 |\n| --- | --- |\n' \
  "$(date -Iseconds)" "$(git -C "$ROOT" rev-parse HEAD)" > "$REPORT" || exit 1

check() {
  local label=$1 result
  shift
  {
    printf '\n검사: %s\n명령: ' "$label"
    printf '%q ' "$@"
    printf '\n'
  } >> "$ART/checks.log"
  if "$@" >> "$ART/checks.log" 2>&1; then
    result=PASS
    PASS=$((PASS + 1))
  else
    result=FAIL
    FAIL=$((FAIL + 1))
  fi
  printf '%s: %s\n' "$result" "$label"
  printf '| %s | %s |\n' "$label" "$result" >> "$REPORT"
}

finish() {
  printf '\n- 합계: PASS=%d, FAIL=%d\n- [상세 실행 로그](checks.log)\n' "$PASS" "$FAIL" >> "$REPORT"
  printf 'PASS=%d FAIL=%d\n보고서: %s\n' "$PASS" "$FAIL" "$REPORT"
  [[ $FAIL == 0 ]]
}

expect_mismatch() {
  compare_config "$1" "$2"
  [[ $? == 1 ]]
}

dt_property_equals() {
  local value
  value=$("$FDTGET" -t "${5:-s}" "$1" "$2" "$3") || return 1
  printf '%s:%s expected=%s actual=%s\n' "$2" "$3" "$4" "$value"
  [[ $value == "$4" ]]
}

expect_dt_mismatch() {
  dt_property_equals "$@"
  [[ $? == 1 ]]
}

if [[ ${1:-} == --self-test ]]; then
  printf 'CONFIG_BUILTIN=y\nCONFIG_MODULE=m\n# CONFIG_DISABLED is not set\nCONFIG_SIZE=32\n' > "$ART/expected.config"
  cp "$ART/expected.config" "$ART/actual.config"
  check "동일한 y/m/n/숫자 설정 통과" compare_config "$ART/expected.config" "$ART/actual.config"
  for pair in 'BUILTIN=n' 'MODULE=y' 'DISABLED=y' 'SIZE=64'; do
    key=${pair%%=*}
    sed "/^CONFIG_${key}=/d; /^# CONFIG_${key} is not set$/d" "$ART/expected.config" > "$ART/actual.config"
    printf 'CONFIG_%s\n' "$pair" >> "$ART/actual.config"
    check "$key 변경 감지" expect_mismatch "$ART/expected.config" "$ART/actual.config"
  done
  sed '/CONFIG_DISABLED/d' "$ART/expected.config" > "$ART/actual.config"
  check "비활성 옵션 누락 감지" expect_mismatch "$ART/expected.config" "$ART/actual.config"
  printf '# 빈 fragment\n' > "$ART/empty.config"
  check "빈 fragment 거부" expect_mismatch "$ART/empty.config" "$ART/actual.config"
  printf '/dts-v1/; / { compatible = "test,boot"; cells = <6 1 0 1>; };\n' > "$ART/test.dts"
  check "DT 검사 도구 존재" command -v "$FDTGET"
  check "DT 회귀 fixture 컴파일" "$DTC" -I dts -O dtb -o "$ART/test.dtb" "$ART/test.dts"
  check "DT 문자열 비교" dt_property_equals "$ART/test.dtb" / compatible test,boot
  check "DT 셀 배열 비교" dt_property_equals "$ART/test.dtb" / cells '6 1 0 1' u
  check "DT 값 불일치 감지" expect_dt_mismatch "$ART/test.dtb" / cells '6 1 0 0' u
  check "DT 속성 누락 감지" expect_dt_mismatch "$ART/test.dtb" / missing test
  finish
  exit $?
fi

build_log_ok() {
  [[ -s $1 ]] && ! grep -q '^ERROR:' "$1" &&
    grep -Eq 'Tasks Summary:.*all succeeded\.' "$1"
}

save_source_diff() { git -C "$ROOT" diff HEAD > "$ART/source.patch"; }
check "검증 시점 소스 변경분 보관" save_source_diff
check "커널 빌드 성공 기록" build_log_ok "$1"
check "rootfs 빌드 성공 기록" build_log_ok "$2"
check "커널 로그 보관" cp "$1" "$ART/kernel-build.log"
check "rootfs 로그 보관" cp "$2" "$ART/rootfs-build.log"
check "최종 설정 보관" cp "$KERNEL_TREE/.config" "$ART/kernel.config"
check "fragment 전체 설정(y/m/n/값) 일치" compare_config "$KERNEL_TREE/hailo15-6.18.fragment" "$KERNEL_TREE/.config"

IMG="$DEPLOY/Image-$MACHINE.bin"
DTB="$DEPLOY/$MACHINE.dtb"
MOD="$DEPLOY/modules-$MACHINE.tgz"
EXT4="$DEPLOY/core-image-minimal-$MACHINE.rootfs.ext4"
TARZ="$DEPLOY/core-image-minimal-$MACHINE.rootfs.tar.zst"
MANI="$DEPLOY/core-image-minimal-$MACHINE.rootfs.manifest"
RELEASE=$(< "$KERNEL_TREE/include/config/kernel.release")
check "커널 release 확인" test -n "$RELEASE"

image_type_ok() {
  file -Lb "$1" | grep -q 'Linux kernel ARM64 boot executable Image'
}

check "ARM64 Image 형식" image_type_ok "$IMG"
check "배포 Image와 빌드 Image 일치" cmp "$IMG" "$KERNEL_TREE/arch/arm64/boot/Image"
check "배포 DTB와 빌드 DTB 일치" cmp "$DTB" "$KERNEL_TREE/arch/arm64/boot/dts/hailo/$MACHINE.dtb"
check "모듈 아카이브 무결성" gzip -t "$MOD"
check "ext4 읽기 전용 파일시스템 검사" e2fsck -fn "$EXT4"
check "rootfs 압축 무결성" zstd -t -- "$(readlink -f "$TARZ")"
check "패키지 manifest 보관" cp "$MANI" "$ART/rootfs.manifest"
check "산출물 SHA-256" sha256sum "$IMG" "$DTB" "$MOD" "$EXT4" "$TARZ" "$MANI"

save_symbols() { nm --defined-only "$KERNEL_TREE/vmlinux" > "$ART/nm.txt"; }
save_modules() { tar -tzf "$MOD" > "$ART/modules-list.txt"; }
save_rootfs() { tar --zstd -tf "$TARZ" > "$ART/rootfs-list.txt"; }
check "ELF 심볼 추출" save_symbols
for symbol in scmi_hailo_register hailo_soc_probe hailo15_pwm_probe hailo15_pinctrl_probe \
  hailo_noc_pmu_driver_init scu_log_probe hailo15_evb_cpld_probe cmsdk_gpio_probe \
  pl320_mbox_probe dwcmshc_hailo_init dwcmshc_hailo_set_clock dwcmshc_hailo_phy_init \
  scmi_clocks_probe scmi_reset_probe; do
  check "ELF: $symbol" grep -Eq " ${symbol}(\\.|$)" "$ART/nm.txt"
done
save_builtin_aliases() { strings "$KERNEL_TREE/modules.builtin.modinfo" > "$ART/builtin-modinfo.txt"; }
check "builtin 드라이버 매칭 정보 추출" save_builtin_aliases
for compatible in arm,pl320-mailbox arm,scmi hailo,dwcmshc-sdhci-0 hailo,dwcmshc-sdhci-1 \
  hailo,hailo15-evb-cpld snps,designware-i2c snps,dw-apb-uart; do
  check "builtin DT 매칭: $compatible" grep -Fq ".alias=of:N*T*C${compatible}" "$ART/builtin-modinfo.txt"
done

check "DT 검사 도구 존재" command -v "$FDTGET"
check "DT 보드 모델" dt_property_equals "$DTB" / model 'Hailo - Hailo15 EVB 2-Camera VPU Development Board'
check "DT UART 콘솔" dt_property_equals "$DTB" /chosen stdout-path /uart1@109000
check "DT ttyS1 alias" dt_property_equals "$DTB" /aliases serial1 /uart1@109000
check "DT PL320 식별자" dt_property_equals "$DTB" /mailbox compatible arm,pl320-mailbox
check "DT PL320 인자 수" dt_property_equals "$DTB" /mailbox '#mbox-cells' 4 u
check "DT SCMI mailbox 전송" dt_property_equals "$DTB" /firmware/scmi compatible arm,scmi
check "DT SCU SCMI 버전 0.50.1" dt_property_equals "$DTB" /firmware/scmi fw-ver 320001 x
scmi_mailboxes_ok() {
  local phandle
  phandle=$("$FDTGET" -t u "$DTB" /mailbox phandle) || return 1
  dt_property_equals "$DTB" /firmware/scmi mboxes "$phandle 6 1 0 1 $phandle 6 9 8 1" u
}
check "DT SCMI 송수신 PL320 채널" scmi_mailboxes_ok
check "DT SD DMA pool 활성화" dt_property_equals "$DTB" /reserved-memory/buffer@0 status okay
check "DT SD DMA pool 종류" dt_property_equals "$DTB" /reserved-memory/buffer@0 compatible restricted-dma-pool
for pair in '0:/main-bus/sdio0@78000000' '1:/sdio1@78001000'; do
  index=${pair%%:*}
  node=${pair#*:}
  check "DT SDIO$index 식별자" dt_property_equals "$DTB" "$node" compatible "hailo,dwcmshc-sdhci-$index"
  check "DT SDIO$index 클럭 입력" dt_property_equals "$DTB" "$node" clock-names 'core bus clk_div_bypass card_clk'
  check "DT SDIO$index PHY 모드" dt_property_equals "$DTB" "$node/phy-config" card-is-emmc "$index" u
done

# 실제 커널에 내장된 CPLD overlay를 적용해 SD/eMMC 활성화를 확인한다.
for variant in rev1 rev2 sdio8bit; do
  overlaid="$ART/evb-$variant.dtb"
  check "CPLD $variant overlay 적용" "$FDTOVERLAY" -i "$DTB" -o "$overlaid" \
    "$KERNEL_TREE/drivers/misc/hailo15_evb_cpld_of_evb_$variant.dtb"
  width=4
  sd_status=okay
  if [[ $variant == sdio8bit ]]; then
    width=8
    sd_status=disabled
  fi
  check "CPLD $variant SD 상태" dt_property_equals "$overlaid" /main-bus/sdio0@78000000 status "$sd_status"
  check "CPLD $variant eMMC 활성화" dt_property_equals "$overlaid" /sdio1@78001000 status okay
  check "CPLD $variant eMMC bus-width" dt_property_equals "$overlaid" /sdio1@78001000 bus-width "$width" u
done
check "모듈 아카이브 목록 추출" save_modules
check "rootfs 아카이브 목록 추출" save_rootfs
check "rootfs init 실행 파일" grep -Fxq './usr/lib/systemd/systemd' "$ART/rootfs-list.txt"
check "rootfs UART 로그인 서비스" grep -Fxq \
  './etc/systemd/system/getty.target.wants/serial-getty@ttyS1.service' "$ART/rootfs-list.txt"
check "모듈 아카이브의 커널 버전" grep -Fq "/$RELEASE/kernel/drivers/" "$ART/modules-list.txt"
for module in phy-hailo-torrent usb_f_hailo_rfs_load usb_f_hailo_swu_load g_hailo; do
  check "모듈 파일: $module" grep -Eq "/${module}\\.ko$" "$ART/modules-list.txt"
  check "rootfs 모듈: $module" grep -Eq "/${module}\\.ko$" "$ART/rootfs-list.txt"
  check "manifest 모듈: $module" grep -Eq "^kernel-module-${module//_/-}-${RELEASE} " "$MANI"
done

{
  printf '\n- 미실행: 새 커널의 보드 부팅, SCMI 통신, SD/eMMC 실매체 I/O, PWM 실패 경로의 실장비 주입, ISP·DSP 동작 검증.\n'
  printf '\n- U-Boot/FIT/서명 형식과 실제 보드의 SCU 펌웨어 버전은 별도 확인이 필요하다.\n'
  printf '\n- ISP·DSP 전체 API 이식은 이번 빌드 검증 범위에 포함하지 않는다.\n'
  printf '\n- [HEAD 대비 소스 변경분](source.patch)\n'
} >> "$REPORT"
finish
