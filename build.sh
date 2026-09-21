#!/usr/bin/env bash
#
# Hailo-15 6.18 커널 wrynose 6.0 빌드 스크립트
#
# 사용법:
#   ./build.sh              # 전체 빌드 (bitbake linux-yocto-hailo, -j nproc)
#   ./build.sh -n           # 건드린 task만 (빌드 후 재실행)
#   ./build.sh -g           # task 그래프만 (dry-run -g)
#   ./build.sh -p           # -e 변수 덤프
#
set -euo pipefail

OEROOT="/home/pingu52/work/yocto-build-6.18/poky"
BUILD="/home/pingu52/work/yocto-build-6.18/build"
TARGET="linux-yocto-hailo"

# wrynose bitbake 실행 환경 (oe-buildenv-internal 비대화형 복원)
cd "$BUILD"
export BBPATH="$BUILD"
export BUILDDIR="$BUILD"
export PYTHONPATH="$OEROOT/bitbake/lib:${PYTHONPATH:-}"
export LC_ALL=C.UTF-8
export PATH="$OEROOT/scripts:$OEROOT/bitbake/bin:$PATH"

case "${1:-}" in
  -n) bitbake -n "$TARGET" "$@" ;;
  -g) bitbake -g "$TARGET" "$@" ;;
  -p) bitbake -e "$TARGET" > /tmp/hailo-e.txt 2>&1 && echo "변수 덤프: /tmp/hailo-e.txt" ;;
  *)  bitbake "$TARGET" ;;
esac
