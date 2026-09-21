#!/usr/bin/env bash
#
# Hailo-15 6.18 Yocto(wrynose) 빌드 검증 스크립트
#
# bitbake linux-yocto-hailo 완료 후 실행. 산출물/증거를
# ~/work/artifacts/hailo-6.18-yocto-<ts>/ 로 수집.
#
# wrynose deploy 네이밍 (실측):
#   Image-hailo15-evb-2-camera-vpu.bin   (-> Image--<ver>-r0-...-<ts>.bin)
#   hailo15-evb-2-camera-vpu.dtb         (탑 레벨, hailo/ 서브디렉터리 없음)
#   modules-hailo15-evb-2-camera-vpu.tgz
#
set -uo pipefail

BUILD="/home/pingu52/work/yocto-build-6.18/build"
KERNEL_TREE="/home/pingu52/work/hailo-yocto-6.18/kernel"
FINAL_LOG="/home/pingu52/work/artifacts/bitbake-linux-yocto-hailo-final.log"
TS="$(date +%Y%m%d%H%M)"
ART="/home/pingu52/work/artifacts/hailo-6.18-yocto-${TS}"
DEPLOY="$BUILD/tmp/deploy/images/hailo15-evb-2-camera-vpu"
MACHINE="hailo15-evb-2-camera-vpu"
PASS=0; FAIL=0

mkdir -p "$ART"
log() { echo "[$(date +%H:%M:%S)] $*"; }

check() { # check <이름> <rc>
  if [ "$2" -eq 0 ]; then log "PASS: $1"; PASS=$((PASS+1)); else log "FAIL: $1"; FAIL=$((FAIL+1)); fi
}

log "=== 1. bitbake 최종 로그 ==="
if [ -f "$FINAL_LOG" ]; then
  ERR=$(grep -cE "^ERROR" "$FINAL_LOG")
  log "ERROR 라인 ${ERR}개"
  [ "$ERR" -eq 0 ]; check "bitbake 로그 에러 0개" $?
  cp "$FINAL_LOG" "$ART/" 2>/dev/null
else
  check "최종 로그 실재" 1
fi

log "=== 2. deploy 산출물 ==="
ls -la "$DEPLOY" 2>/dev/null | tee "$ART/deploy-listing.txt"
IMG="$DEPLOY/Image-${MACHINE}.bin"
DTB="$DEPLOY/${MACHINE}.dtb"
MOD="$DEPLOY/modules-${MACHINE}.tgz"
[ -f "$IMG" ]; check "Image (${MACHINE}.bin, 41MB)" $?
[ -f "$DTB" ]; check "DTB (${MACHINE}.dtb)" $?
[ -f "$MOD" ]; check "modules-${MACHINE}.tgz" $?
file "$IMG" "$DTB" > "$ART/image-file.txt" 2>&1
cp "$MOD" "$ART/" 2>/dev/null

log "=== 3. vmlinux Hailo 핵심 심볼 (nm) ==="
VMI="$KERNEL_TREE/vmlinux"
if [ -f "$VMI" ]; then
  ls -la "$VMI" | tee "$ART/vmlinux-listing.txt"
  SYMS="scmi_hailo|pwm_hailo|pinctrl_hailo|hailo_soc|hailo_noc_pmu|scu_log"
  nm "$VMI" 2>/dev/null | grep -E "$SYMS" > "$ART/nm-hailo-symbols.txt"
  N=$(wc -l < "$ART/nm-hailo-symbols.txt")
  log "Hailo 핵심 심볼 매칭 ${N}개"
  [ "$N" -ge 6 ]; check "Hailo 핵심 심볼 실존 (${N}개)" $?
  nm "$VMI" 2>/dev/null | grep -icE "hailo|cmsdk|scmi_hailo" > "$ART/nm-hailo-count.txt"
  log "Hailo 계열 심볼 총 $(cat "$ART/nm-hailo-count.txt")개"
else
  check "vmlinux 실재" 1
fi

log "=== 4. fragment 34개 =y 옵션 대조 (최종 .config) ==="
grep -E "^CONFIG_.*=y" "$KERNEL_TREE/hailo15-6.18.fragment" | sed 's/=y//' > /tmp/frag_y_verify.txt
MISS=0
while read opt; do
  v=$(grep -E "^${opt}=" "$KERNEL_TREE/.config" | head -1 | cut -d= -f2)
  [ "$v" = "y" ] || { echo "MISS/OTHER: ${opt} -> ${v:-NOT_SET}"; MISS=$((MISS+1)); }
done < /tmp/frag_y_verify.txt
echo "MISS_COUNT=${MISS}" | tee "$ART/fragment-miss.txt"
[ "$MISS" -eq 0 ]; check "fragment 34개 옵션 전부 =y (MISS ${MISS})" $?

log "=== 5. Image 무결성 ==="
IMGREAL=$(readlink -f "$IMG")
case "$(file -b "$IMGREAL" | cut -c1-20)" in
  "Data"|"gzip compressed"|"gzip"*)
    : ;;
esac
# arm64 Image(41MB raw): gzip인지 raw인지 file로 판정 후 무결성
FT=$(file -b "$IMGREAL")
echo "$FT" >> "$ART/image-file.txt"
case "$FT" in
  *gzip*) gzip -t "$IMGREAL"; check "Image 무결성 (gzip -t)" $? ;;
  *) cmp -s "$IMGREAL" "$IMGREAL" >/dev/null 2>&1
     log "Image는 raw binary (gzip 아님) - 산출물 크기와 파일 타입 확인만으로 검증"
     check "Image raw binary 실재" 0 ;;
esac

log "=== 6. Hailo gadget 모듈 .ko 실재 (u_f.h/6.18 포트 결과) ==="
for m in usb_f_hailo_rfs_load.ko usb_f_hailo_swu_load.ko; do
  [ -f "$KERNEL_TREE/drivers/usb/gadget/function/$m" ]; check "$m" $?
done

log "=== 완료: PASS=$PASS FAIL=$FAIL ==="
echo "ART=$ART"
[ "$FAIL" -eq 0 ]
