# boot-6.18 — Hailo-15 6.18 부팅 검증 키트 (public)

6.18 커널 포팅 산출물 + Hailo 표준 EVB dtb + Yocto 6.0 rootfs로 구성.

## 구성
- fitImage-6.18-public: u-boot FIT (6.18.52 커널 + Hailo EVB dtb, sha256 검증 포함)
- hailo15-evb-2-camera-vpu.dtb: Hailo 표준 EVB device tree (GEM MAC 노드 포함)
- 618-public.its / make-fit.sh: FIT 재생성용 ITS와 스크립트
- rootfs-6.18-minimal.squashfs: Yocto 6.0 core-image-minimal (gzip squashfs)

## 사용
- FIT: U-Boot `bootm`으로 로드 (kernel load/entry 0x80c00000, fdt 0x80800000,
  이미지별 sha256 해시 포함)
- rootfs: squashfs를 rootfs 파티션에 기록하고 커널 인자 `root=`로 지정
  (커널 SQUASHFS=y, SQUASHFS_ZLIB=y)
- 6.18 확인:
       uname -r   -> 6.18.52-hailo
       dmesg | grep -i gem   (MACB GEM 등록 확인)

## GEM 이더넷
public EVB dtb의 GEM 노드(compatible=hailo,hailo15-gem, reg=0x1b5000,
rgmii-id=1)와 6.18 MACB 포팅이 동작 여부를 검증 대상.
