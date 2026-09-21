	.arch armv8-a
	.file	"bounds.c"
// GNU C11 (GCC) version 10.2.1 20200907 [ revision ce3001ff1d734e0763a1a5e434272bf89df1fe06] (aarch64-linux-gnu)
//	compiled by GNU C version 8.2.1 20180905 (Red Hat 8.2.1-3), GMP version 6.1.2, MPFR version 4.0.2, MPC version 1.1.0, isl version isl-0.22-GMP

// GGC heuristics: --param ggc-min-expand=100 --param ggc-min-heapsize=131072
// options passed:  -nostdinc -I ./arch/arm64/include
// -I ./arch/arm64/include/generated -I ./include -I ./include
// -I ./arch/arm64/include/uapi -I ./arch/arm64/include/generated/uapi
// -I ./include/uapi -I ./include/generated/uapi
// -imultiarch aarch64-linux-gnu
// -iprefix /usr/local/linaro-aarch64-2020.09-gcc10.2-linux5.4/bin/../lib/gcc/aarch64-linux-gnu/10.2.1/
// -isysroot /usr/local/linaro-aarch64-2020.09-gcc10.2-linux5.4/bin/../aarch64-linux-gnu/libc
// -D __KERNEL__ -D KASAN_SHADOW_SCALE_SHIFT=
// -D CONFIG_CC_HAS_K_CONSTRAINT=1 -D ARM64_ASM_ARCH="armv8.5-a"
// -D KASAN_SHADOW_SCALE_SHIFT= -D GCC_PLUGINS -D KBUILD_MODFILE="./bounds"
// -D KBUILD_BASENAME="bounds" -D KBUILD_MODNAME="bounds"
// -D __KBUILD_MODNAME=kmod_bounds
// -include ./include/linux/compiler-version.h
// -include ./include/linux/kconfig.h
// -include ./include/linux/compiler_types.h -MMD kernel/.bounds.s.d
// kernel/bounds.c -mlittle-endian -mgeneral-regs-only -mabi=lp64
// -mbranch-protection=pac-ret -march=armv8-a
// -auxbase-strip kernel/bounds.s -O2 -Wno-psabi -Wall -Wextra -Wundef
// -Werror=implicit-function-declaration -Werror=implicit-int
// -Werror=return-type -Werror=strict-prototypes -Wno-format-security
// -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member
// -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048
// -Wno-main -Wvla-larger-than=1 -Wno-pointer-sign -Wcast-function-type
// -Wno-array-bounds -Wstringop-overflow=0
// -Walloc-size-larger-than=18446744073709551615EiB
// -Wimplicit-fallthrough=5 -Werror=date-time
// -Werror=incompatible-pointer-types -Werror=designated-init
// -Wenum-conversion -Wunused -Wno-unused-but-set-variable
// -Wunused-const-variable=0 -Wno-packed-not-aligned -Wformat-overflow=0
// -Wformat-truncation=0 -Wno-stringop-truncation -Wno-override-init
// -Wno-missing-field-initializers -Wno-type-limits
// -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare
// -Wno-unused-parameter -std=gnu11 -fshort-wchar -funsigned-char
// -fno-common -fno-PIE -fno-strict-aliasing
// -fno-asynchronous-unwind-tables -fno-unwind-tables
// -fno-delete-null-pointer-checks -fno-allow-store-data-races
// -fstack-protector-strong -fno-omit-frame-pointer
// -fno-optimize-sibling-calls -fno-stack-clash-protection
// -falign-functions=4 -fno-strict-overflow -fstack-check=no
// -fconserve-stack -fno-builtin-wcslen -fverbose-asm
// options enabled:  -faggressive-loop-optimizations -falign-functions
// -falign-jumps -falign-labels -falign-loops -fallocation-dce
// -fauto-inc-dec -fbranch-count-reg -fcaller-saves -fcode-hoisting
// -fcombine-stack-adjustments -fcompare-elim -fcprop-registers
// -fcrossjumping -fcse-follow-jumps -fdefer-pop -fdevirtualize
// -fdevirtualize-speculatively -fdwarf2-cfi-asm -fearly-inlining
// -feliminate-unused-debug-symbols -feliminate-unused-debug-types
// -fexpensive-optimizations -fforward-propagate -ffp-int-builtin-inexact
// -ffunction-cse -fgcse -fgcse-lm -fgnu-unique -fguess-branch-probability
// -fhoist-adjacent-loads -fident -fif-conversion -fif-conversion2
// -findirect-inlining -finline -finline-atomics -finline-functions
// -finline-functions-called-once -finline-small-functions -fipa-bit-cp
// -fipa-cp -fipa-icf -fipa-icf-functions -fipa-icf-variables -fipa-profile
// -fipa-pure-const -fipa-ra -fipa-reference -fipa-reference-addressable
// -fipa-sra -fipa-stack-alignment -fipa-vrp -fira-hoist-pressure
// -fira-share-save-slots -fira-share-spill-slots
// -fisolate-erroneous-paths-dereference -fivopts -fkeep-static-consts
// -fleading-underscore -flifetime-dse -flra-remat -fmath-errno
// -fmerge-constants -fmerge-debug-strings -fmove-loop-invariants
// -fomit-frame-pointer -foptimize-strlen -fpartial-inlining -fpeephole
// -fpeephole2 -fplt -fprefetch-loop-arrays -free -freg-struct-return
// -freorder-blocks -freorder-functions -frerun-cse-after-loop
// -fsched-critical-path-heuristic -fsched-dep-count-heuristic
// -fsched-group-heuristic -fsched-interblock -fsched-last-insn-heuristic
// -fsched-pressure -fsched-rank-heuristic -fsched-spec
// -fsched-spec-insn-heuristic -fsched-stalled-insns-dep -fschedule-fusion
// -fschedule-insns -fschedule-insns2 -fsection-anchors
// -fsemantic-interposition -fshow-column -fshrink-wrap
// -fshrink-wrap-separate -fsigned-zeros -fsplit-ivs-in-unroller
// -fsplit-wide-types -fssa-backprop -fssa-phiopt -fstack-protector-strong
// -fstdarg-opt -fstore-merging -fstrict-volatile-bitfields -fsync-libcalls
// -fthread-jumps -ftoplevel-reorder -ftrapping-math -ftree-bit-ccp
// -ftree-builtin-call-dce -ftree-ccp -ftree-ch -ftree-coalesce-vars
// -ftree-copy-prop -ftree-cselim -ftree-dce -ftree-dominator-opts
// -ftree-dse -ftree-forwprop -ftree-fre -ftree-loop-distribute-patterns
// -ftree-loop-if-convert -ftree-loop-im -ftree-loop-ivcanon
// -ftree-loop-optimize -ftree-parallelize-loops= -ftree-phiprop -ftree-pre
// -ftree-pta -ftree-reassoc -ftree-scev-cprop -ftree-sink -ftree-slsr
// -ftree-sra -ftree-switch-conversion -ftree-tail-merge -ftree-ter
// -ftree-vrp -funit-at-a-time -fverbose-asm -fwrapv -fwrapv-pointer
// -fzero-initialized-in-bss -mfix-cortex-a53-835769
// -mfix-cortex-a53-843419 -mgeneral-regs-only -mglibc -mlittle-endian
// -momit-leaf-frame-pointer -moutline-atomics -mpc-relative-literal-loads

	.text
	.section	.text.startup,"ax",@progbits
	.align	2
	.global	main
	.type	main, %function
main:
// kernel/bounds.c:19: 	DEFINE(NR_PAGEFLAGS, __NR_PAGEFLAGS);
#APP
// 19 "kernel/bounds.c" 1
	
.ascii "->NR_PAGEFLAGS 24 __NR_PAGEFLAGS"	//
// 0 "" 2
// kernel/bounds.c:20: 	DEFINE(MAX_NR_ZONES, __MAX_NR_ZONES);
// 20 "kernel/bounds.c" 1
	
.ascii "->MAX_NR_ZONES 4 __MAX_NR_ZONES"	//
// 0 "" 2
// kernel/bounds.c:22: 	DEFINE(NR_CPUS_BITS, order_base_2(CONFIG_NR_CPUS));
// 22 "kernel/bounds.c" 1
	
.ascii "->NR_CPUS_BITS 9 order_base_2(CONFIG_NR_CPUS)"	//
// 0 "" 2
// kernel/bounds.c:24: 	DEFINE(SPINLOCK_SIZE, sizeof(spinlock_t));
// 24 "kernel/bounds.c" 1
	
.ascii "->SPINLOCK_SIZE 4 sizeof(spinlock_t)"	//
// 0 "" 2
// kernel/bounds.c:29: 	DEFINE(LRU_GEN_WIDTH, 0);
// 29 "kernel/bounds.c" 1
	
.ascii "->LRU_GEN_WIDTH 0 0"	//
// 0 "" 2
// kernel/bounds.c:30: 	DEFINE(__LRU_REFS_WIDTH, 0);
// 30 "kernel/bounds.c" 1
	
.ascii "->__LRU_REFS_WIDTH 0 0"	//
// 0 "" 2
// kernel/bounds.c:35: }
#NO_APP
	mov	w0, 0	//,
	ret	
	.size	main, .-main
	.ident	"GCC: (GNU) 10.2.1 20200907 [ revision ce3001ff1d734e0763a1a5e434272bf89df1fe06]"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align	3
	.word	4
	.word	16
	.word	5
	.string	"GNU"
	.word	3221225472
	.word	4
	.word	2
	.align	3
