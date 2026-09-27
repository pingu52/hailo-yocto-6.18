#!/usr/bin/env bash
set -e
cd /home/pingu52/work/artifacts/hailo-6.18-boot-probe/fitbuild
/opt/poky/4.0.26/sysroots/x86_64-pokysdk-linux/usr/bin/mkimage -f 618-public.its -r fitImage-6.18-public
echo ---
/opt/poky/4.0.26/sysroots/x86_64-pokysdk-linux/usr/bin/mkimage -l fitImage-6.18-public
