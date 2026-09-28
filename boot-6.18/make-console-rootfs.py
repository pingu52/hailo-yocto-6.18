#!/usr/bin/env python3
"""잠긴 root 계정에 stdin 암호를 설정한 시험용 SquashFS와 검증 결과를 만든다."""
import argparse
import hashlib
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


def update_shadow(text, password_hash):
    if not re.fullmatch(r"\$6\$[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}", password_hash):
        raise ValueError("SHA-512 crypt 형식이 아니다")
    lines = text.splitlines(keepends=True)
    roots = [i for i, line in enumerate(lines) if line.startswith("root:")]
    if len(roots) != 1:
        raise ValueError("root 항목이 하나가 아니다")
    index = roots[0]
    fields = lines[index].rstrip("\n").split(":")
    if len(fields) != 9 or not fields[1].startswith(("!", "*")):
        raise ValueError("잠긴 root 계정에만 적용할 수 있다")
    fields[1] = password_hash
    lines[index] = ":".join(fields) + "\n"
    return "".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        sample_hash = "$6$test$" + "a" * 86
        original = "root:!:20000:0:99999:7:::\ndaemon:*:20000:0:99999:7:::\n"
        assert update_shadow(original, sample_hash) == original.replace("root:!:", f"root:{sample_hash}:")
        for invalid in (original.replace("root:!:", "root::"),
                        original.replace("root:!:", f"root:{sample_hash}:"), original + original, ""):
            try:
                update_shadow(invalid, sample_hash)
            except ValueError:
                continue
            raise AssertionError("잘못된 계정 입력을 허용했다")
        try:
            update_shadow(original, "$6$invalid")
        except ValueError:
            pass
        else:
            raise AssertionError("잘못된 해시 입력을 허용했다")
        print("PASS: root만 변경·빈 암호 계정 및 중복 항목 거부")
        return
    if args.source is None or args.output is None:
        parser.error("원본 SquashFS와 새 출력 디렉터리를 지정해야 한다")
    if not os.environ.get("FAKEROOTKEY") or os.geteuid() != 0:
        parser.error("소유권 보존을 위해 fakeroot 아래에서 실행해야 한다")
    password = sys.stdin.buffer.read(4096).removesuffix(b"\n")
    if not password or b"\n" in password or b"\0" in password or len(password) >= 4095:
        parser.error("stdin 암호가 비었거나 형식이 잘못되었다")
    hashed = subprocess.run(["openssl", "passwd", "-6", "-stdin"], input=password + b"\n",
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout.decode().strip()
    del password
    source = args.source.resolve(strict=True)
    args.output.mkdir(mode=0o700)
    output = args.output.resolve()
    tree = output / "rootfs"
    image = output / "rootfs-console.squashfs"
    passed = False
    try:
        with (output / "build.log").open("w") as log:
            subprocess.run(["unsquashfs", "-no-progress", "-d", str(tree), str(source)],
                           stdout=log, stderr=subprocess.STDOUT, check=True)
            shadow = tree / "etc/shadow"
            if shadow.is_symlink():
                raise ValueError("shadow 심볼릭 링크는 허용하지 않는다")
            updated = update_shadow(shadow.read_text(), hashed)
            shadow_mode = stat.S_IMODE(shadow.stat().st_mode)
            try:
                shadow.chmod(shadow_mode | stat.S_IWUSR)
                shadow.write_text(updated)
            finally:
                shadow.chmod(shadow_mode)
            subprocess.run(["mksquashfs", str(tree), str(image), "-noappend", "-comp", "gzip",
                            "-no-progress", "-processors", "4"], stdout=log, stderr=subprocess.STDOUT, check=True)
            readback = subprocess.run(["unsquashfs", "-cat", str(image), "etc/shadow"],
                                      stdout=subprocess.PIPE, stderr=log, check=True).stdout.decode()
            if readback != updated:
                raise ValueError("생성 이미지의 shadow 읽기 검증 실패")
        image.chmod(0o600)
        (output / "SHA256SUMS").write_text(
            f"{hashlib.sha256(image.read_bytes()).hexdigest()}  {image.name}\n")
        passed = True
    finally:
        (output / "report.md").write_text(
            "# 시험용 콘솔 rootfs 생성\n\n"
            f"- 잠긴 root 계정 암호 설정·이미지 읽기 검증: {'PASS' if passed else 'FAIL'}\n"
            "- 암호는 stdin으로만 받고 SHA-512 crypt 형태로 이미지에 기록한다.\n"
            "- 무암호 로그인·autologin·SSH 서비스는 활성화하지 않는다.\n"
            "- 보드 기록·로그인 인증: 이 도구에서는 미실행\n"
            "- [생성 로그](build.log) · [이미지 해시](SHA256SUMS)\n", encoding="utf-8")
    print(f"콘솔 rootfs 생성·검증 완료: {image}")


if __name__ == "__main__":
    main()
