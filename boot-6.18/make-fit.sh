#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 || $1 != --public-unsigned ]]; then
    echo "사용법: $0 --public-unsigned <Image.gz> <새 artifact 디렉터리>" >&2
    echo "EVB용 미서명 FIT만 생성한다. TRUEN 보드 부팅용이 아니다." >&2
    exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KERNEL=$(realpath -e -- "$2")
MKIMAGE=$(command -v "${MKIMAGE:-mkimage}")
MKIMAGE=$(realpath -e -- "$MKIMAGE")
gzip -t -- "$KERNEL"
# 기존 산출물을 덮어쓰지 않고, 지정된 증거 디렉터리에서만 생성한다.
mkdir -- "$3"
ARTIFACT_DIR=$(realpath -e -- "$3")
cp -- "$KERNEL" "$ARTIFACT_DIR/kernel.gz"
cp -- "$SCRIPT_DIR/hailo15-evb-2-camera-vpu.dtb" "$ARTIFACT_DIR/board.dtb"
cp -- "$SCRIPT_DIR/618-public.its" "$ARTIFACT_DIR/618-public.its"
cd -- "$ARTIFACT_DIR"
printf '# EVB FIT 생성 결과\n\n- 대상: 공개 Hailo15 EVB, TRUEN 보드 아님\n- 시작: %s\n' "$(date -Iseconds)" > report.md
if "$MKIMAGE" -f 618-public.its fitImage-6.18-public-unsigned > build.log 2>&1 &&
   "$MKIMAGE" -l fitImage-6.18-public-unsigned > image-info.log 2>&1; then
    sha256sum kernel.gz board.dtb fitImage-6.18-public-unsigned > SHA256SUMS
    printf '\n- FIT 생성: PASS\n- 필수 서명: 없음(UNSIGNED)\n- 보드 부팅: 미실행\n- [생성 로그](build.log) · [FIT 정보](image-info.log) · [해시](SHA256SUMS)\n' >> report.md
    echo "EVB 미서명 FIT 생성: $ARTIFACT_DIR/fitImage-6.18-public-unsigned"
    echo "주의: SHA-256은 서명이 아니다. key-customer 필수 보드에서는 부팅이 거부된다." >&2
else
    printf '\n- FIT 생성: FAIL\n- [생성 로그](build.log)\n' >> report.md
    echo "FIT 생성 실패: $ARTIFACT_DIR/build.log" >&2
    exit 1
fi
