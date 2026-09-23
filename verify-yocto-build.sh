#!/usr/bin/env bash
# 사용법: ./verify-yocto-build.sh <커널 빌드 로그> <rootfs 빌드 로그>
# ART로 증거 디렉터리를 지정한다. --self-test는 설정 비교의 회귀를 검사한다.
set -uo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUILD=${BUILD:-/home/pingu52/work/yocto-build-6.18/build}
KERNEL_TREE=${KERNEL_TREE:-$ROOT/kernel}
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
  hailo_noc_pmu_driver_init scu_log_probe hailo15_evb_cpld_probe cmsdk_gpio_probe; do
  check "ELF: $symbol" grep -Eq " ${symbol}(\\.|$)" "$ART/nm.txt"
done
check "모듈 아카이브 목록 추출" save_modules
check "rootfs 아카이브 목록 추출" save_rootfs
check "모듈 아카이브의 커널 버전" grep -Fq "/$RELEASE/kernel/drivers/" "$ART/modules-list.txt"
for module in phy-hailo-torrent usb_f_hailo_rfs_load usb_f_hailo_swu_load g_hailo; do
  check "모듈 파일: $module" grep -Eq "/${module}\\.ko$" "$ART/modules-list.txt"
  check "rootfs 모듈: $module" grep -Eq "/${module}\\.ko$" "$ART/rootfs-list.txt"
  check "manifest 모듈: $module" grep -Eq "^kernel-module-${module//_/-}-${RELEASE} " "$MANI"
done

{
  printf '\n- 미실행: 보드 부팅, SCMI 통신, PWM 실패 경로의 실장비 주입, ISP·DSP 동작 검증.\n'
  printf '\n- ISP·DSP 전체 API 이식은 이번 빌드 검증 범위에 포함하지 않는다.\n'
  printf '\n- [HEAD 대비 소스 변경분](source.patch)\n'
} >> "$REPORT"
finish
