# boot-6.18 — Hailo-15 6.18 부팅 검증 키트 (public)

6.18 커널 포팅 산출물 + Hailo 표준 EVB dtb + Yocto 6.0 rootfs로 구성.

## 구성
- fitImage-6.18-public: u-boot FIT (6.18.52 커널 + Hailo EVB dtb, sha256 검증 포함)
- hailo15-evb-2-camera-vpu.dtb: Hailo 표준 EVB device tree (GEM MAC 노드 포함)
- 618-public.its / make-fit.sh: FIT 재생성용 ITS와 스크립트
- rootfs-6.18-minimal.squashfs: Yocto 6.0 core-image-minimal (gzip squashfs)

## 부팅 절차 (보드가 5.15 u-boot 정상 상태일 때)

1. u-Boot 콘솔에서 eMMC p2(ubifs) 파티션 마운트 확인 (5.15 기본 동작)
2. FIT 파일을 ubifs의 u-boot 디렉토리에 fatload 가능한 형태로 전달
   - 기존 슬롯B가 fitImage_2를 FAT에서 fatload 하므로, FIT를 FAT 볼륨
     (p1, uboot FAT32)의 u-boot/ 하위로 복사:
       mkdir -p /boot/uboot (5.15 컨솔에서, FAT 볼륨 마운트 경로 확인 후)
       copy fitImage-6.18-public /boot/uboot/fitImage_2  (이름은 env와 일치)
3. rootfs 준비 (p6 = rootfs2 파티션에 squashfs 40.7MB 기록)
4. env:
       setenv boot_option2
       setenv root p6
       saveenv
5. 재부팅:
       reset
   슬롯B: FIT 로드(sha256 auto-check) -> 6.18 커널 + EVB dtb ->
   root=/dev/mmcblk1p6 squashfs 마운트 -> login
6. 6.18 확인:
       uname -r   -> 6.18.52
       dmesg | grep -i gem   (MACB GEM 등록 확인)

## 실패 시
- FIT 해시 오류 / 부팅 실패 -> 재부팅하면 슬롯A(5.15) 자동 복구
- 6.18 부팅 실패 시 5.15 슬롯A는 그대로 유지됨 (안전 폴백)

## GEM 이더넷
public EVB dtb의 GEM 노드(compatible=hailo,hailo15-gem, reg=0x1b5000,
rgmii-id=1)와 6.18 MACB 포팅이 동작 여부를 검증 대상.
