SUMMARY = "Hailo15 DSP 펌웨어"
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://LICENSE;md5=263ee034adc02556d59ab1ebdaea2cda"

# 공식 meta-hailo-soc 1.12.1의 Hailo15 펌웨어와 체크섬을 사용한다.
SRC_URI = " \
    https://hailo-hailort.s3.eu-west-2.amazonaws.com/Hailo15/${PV}/dsp-fw/dsp-fw.elf;name=fw \
    https://hailo-hailort.s3.eu-west-2.amazonaws.com/Hailo15/${PV}/dsp-fw/LICENSE;name=license \
"
SRC_URI[fw.sha256sum] = "084b539378128d925d91a98139d2be93cc29ad704e78b0856728bb0f845fe1ed"
SRC_URI[license.sha256sum] = "ca96445e6e33ae0a82170ea847b0925c864492f0cbb6342d42c54fd647133608"
S = "${UNPACKDIR}"

COMPATIBLE_MACHINE = "^hailo15-evb-2-camera-vpu$"
PACKAGE_ARCH = "${MACHINE_ARCH}"

do_install() {
    install -d ${D}${nonarch_base_libdir}/firmware
    install -m 0644 ${S}/dsp-fw.elf ${D}${nonarch_base_libdir}/firmware/
}

FILES:${PN} = "${nonarch_base_libdir}/firmware/dsp-fw.elf"
# AArch64 실행 파일이 아닌 Xtensa DSP 펌웨어이므로 ELF 변환을 하지 않는다.
INSANE_SKIP:${PN} += "arch"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"
