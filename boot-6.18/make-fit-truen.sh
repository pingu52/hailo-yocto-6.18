#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 5 ]]; then
    echo "사용법: $0 <Image.gz> <TRUEN DTB> <기존 개인키> <신뢰 U-Boot 제어 DTB> <새 artifact 디렉터리>" >&2
    exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KERNEL=$(realpath -e -- "$1")
BOARD_DTB=$(realpath -e -- "$2")
SIGNING_KEY=$(realpath -e -- "$3")
CONTROL_DTB=$(realpath -e -- "$4")
MKIMAGE=$(realpath -e -- "$(command -v "${MKIMAGE:-mkimage}")")
FIT_CHECK_SIGN=$(realpath -e -- "$(command -v "${FIT_CHECK_SIGN:-fit_check_sign}")")
FDTGET=$(realpath -e -- "$(command -v "${FDTGET:-fdtget}")")
gzip -t -- "$KERNEL"
"$FDTGET" -p "$BOARD_DTB" / >/dev/null

# 검증용 DTB의 키를 생성·교체하지 않고, 기존 필수 공개키로만 판정한다.
[[ $("$FDTGET" -t s "$CONTROL_DTB" /signature/key-customer required) == conf ]]
[[ $("$FDTGET" -t s "$CONTROL_DTB" /signature/key-customer algo) == sha256,rsa3072 ]]
mkdir -- "$5"
ARTIFACT_DIR=$(realpath -e -- "$5")
cd -- "$ARTIFACT_DIR"
printf '# TRUEN FIT 서명 검증 결과\n\n- 시작: %s\n' "$(date -Iseconds)" > report.md
finish() {
    local result=$?
    if [[ $result == 0 ]]; then
        printf '\n- 생성·필수 서명 검증: PASS\n' >> report.md
    else
        printf '\n- 생성·필수 서명 검증: FAIL (종료 코드 %s)\n' "$result" >> report.md
    fi
    printf '\n- 보드 전송·플래시·부팅: 미실행\n- [생성 로그](build.log) · [서명 검증](verify.log) · [해시](SHA256SUMS)\n' >> report.md
}
trap finish EXIT

cp -- "$KERNEL" kernel.gz
cp -- "$BOARD_DTB" board.dtb
cp -- "$CONTROL_DTB" trusted-control.dtb
cp -- "$SCRIPT_DIR/618-truen.its" image.its
# -G로 원본 키 경로만 전달한다. 개인키를 산출물에 복사하거나 -K로 신뢰 키를 덮어쓰지 않는다.
"$MKIMAGE" -f image.its -G "$SIGNING_KEY" candidate.itb </dev/null > build.log 2>&1
"$FIT_CHECK_SIGN" -f candidate.itb -k trusted-control.dtb \
    -c conf-truen_truen_board.dtb > verify.log 2>&1
mv -- candidate.itb fitImage-6.18-truen-signed
"$MKIMAGE" -l fitImage-6.18-truen-signed > image-info.log
sha256sum kernel.gz board.dtb trusted-control.dtb fitImage-6.18-truen-signed > SHA256SUMS
echo "서명 검증 완료: $ARTIFACT_DIR/fitImage-6.18-truen-signed"
