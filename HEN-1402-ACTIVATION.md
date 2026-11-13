# How the 14.02 HEN path was verified

Subject: `web/hen1402.bin` — 516,416 bytes
`sha256 6321c97294e647d1a1530e7b5762cf6760af4e4289005efad94c052d837fd949`
(file was supplied as `hen.bin`; renamed here so it cannot be confused with the
14.00 build that sits next to it)

Everything below was read out of the binary, not assumed from the file name or
the version string.

## 1. The refusal cannot fire on 14.02

The userland installer begins at `0x743c` (the `e9` at offset 0 jumps there).
The only reference to the capital-F `"Unsupported Firmware"` string is at
`0x74ca`, inside this block:

```
7470  05 85 fa ff ff        add eax, 0xfffffa85      ; eax = fw - 1403
7475  66 3d 5e fc           cmp ax, 0xfc5e
7479  0f 87 97 01 00 00     ja  0x7616               ; in range -> past the error
747f  48 8d 9d 70 f0 ff ff  lea rbx, [rbp - 0xf90]   ; error path
...
74ca  48 8d 15 da 72 00 00  lea rdx, [rip + 0x72da]  ; "Unsupported Firmware"
74d8  48 89 df              mov rdi, rbx
74db  41 ff 14 24           call qword ptr [r12]     ; copy it into the buffer
```

`ja` compares 16-bit `ax` unsigned. Values:

| fw | `fw - 1403` as u16 | `> 0xfc5e` | result |
| --- | --- | --- | --- |
| 473 | 0xfc5e | no | refused |
| 474 | 0xfc5f | yes | accepted |
| 1402 | 0xffff | yes | **accepted** |
| 1403 | 0x0000 | no | refused |

So the gate is the inclusive range **474..1402**. 14.02 (`0x57a`) passes it, and
the string is never copied.

## 2. The kernel side has a real 14.02 branch

Kernel-stage code begins at offset 5 and selects a firmware block by comparing
against a chain of version constants. The 14.02 arm:

```
18d1  3d 7a 05 00 00        cmp eax, 0x57a           ; 1402
18d6  0f 85 19 13 00 00     jne 0x2bf5               ; 0x2bf5 = "Unsupported firmware"
18dc  b9 82 00 00 c0        mov ecx, 0xc0000082      ; LSTAR
18e1  0f 32                 rdmsr
18e3  48 c1 e2 20           shl rdx, 0x20
18e7  48 09 c2              or  rdx, rax             ; rdx = syscall entry
18ea  48 8d b2 e3 db 2b 00  lea rsi, [rdx + 0x2bdbe3]
...
```

Addresses are not read from a table at runtime — they are computed as deltas
from the syscall entry in `MSR_LSTAR`, which is why the block is specific to
14.02 rather than to a load address.

## 3. Those deltas are 14.02 deltas, not 14.00 ones

The same build carries the 14.00 arm at `0x209c`. Comparing the two arms field
by field gives the movement of each block between the firmwares:

| field | 14.00 delta | 14.02 delta | move |
| --- | --- | --- | --- |
| rsi | `0x2bd8e3` | `0x2bdbe3` | +0x300 |
| r9 | `0x2bd7ee` | `0x2bdaee` | +0x300 |
| rdi | `0x2bdd83` | `0x2be083` | +0x300 |
| rax | `0x2bd8d7` | `0x2bdbd7` | +0x300 |
| r8 | `0x2bd7e2` | `0x2bdae2` | +0x300 |
| rbx | `0x2bdd8f` | `0x2be08f` | +0x300 |
| r11 | `0x2bddc0` | `0x2be0c0` | +0x300 |
| r14 | `0x394abc` | `0x394e2c` | +0x370 |
| r15 | `0x69e440` | `0x69e8c0` | +0x480 |
| r12 | `0x64f560` | `0x64f9e0` | +0x480 |
| r13 | `0x64f590` | `0x64fa10` | +0x480 |
| r10 | `0x4ea1ae` | `0x4ea59e` | +0x3f0 |
| rsi (2nd) | `0x4e90e8` | `0x4e94d8` | +0x3f0 |
| rcx | `0x1a47dd0` | `0x1a47dd0` | 0 |

`+0x300` on the memcpy block, `+0x370` on the string / `sceSblACMgrGetPathId`
block and `+0x480` on the SceSblAuthMgr / Keymgr / Pfs block are exactly the
shifts measured independently in a decrypted retail 14.02 kernel image. A build
that had simply reused 14.00 numbers would show zero movement here.

## 4. Its 14.02 offset table matches ours

The installer's data section holds one struct per firmware. The 14.02 struct,
starting at `0x14ed4`, is 35 consecutive little-endian 32-bit values. All 35 are
byte-identical to the 14.02 table this exploit already carries and verified
against the retail image — `memcpy 0x2bdb50`, `sceSblServiceMailbox 0x630970`,
`SceSblKeymgrSmCallfunc 0x62bc10`, `PROC_RWMEM 0x366d80` and the rest.

## 5. It enters the kernel the way this exploit expects

```
19cc0  48 c7 c0 0b 00 00 00   mov rax, 0xb
19cc7  49 89 ca               mov r10, rcx
19cca  0f 05                  syscall
```

Syscall 11, arguments in `rdi / rsi / rdx / rcx`. `[10]` in the run log is that
call being redirected to a gate that runs ring-0 code from this process. The
same stub exists at `0x50f8a` in the payload that already ran on 14.02 hardware,
so the ABI is not a guess.

## 6. Image form

First five bytes are `e9 37 74 00 00` — a relative jump, i.e. the raw-payload
form the loader already handles: `mmap` RWX, copy, verify the copy, start on a
thread. Layout after that: kernel stage, then the installer, then five embedded
PRX modules at `0x18480`, `0x25960`, `0x33160`, `0x45f50`, `0x686b0`.

## 7. Brick surface

Searched for every path that could touch persistent storage: no `flash`,
`nand`, `nor`, `syscon` or raw-device write path exists in the file. The writes
it performs are to kernel RAM and to `/data/hen` and `/user/temp` on the user
partition, which is what an installer is for.

One configuration option does change system state: `block_updates` unmounts the
`/update` partition so an accidental firmware update cannot patch the exploit.
It is off by default in the shipped config (`value="0"`) and is a mount state,
not a flash write — a reboot restores it.

## What is still unproven

This binary enabling HEN on a 14.02 console, from this kit, observed by us. The
checks above rule out the refusal and rule out 14.00 data being fed to a 14.02
kernel; they do not substitute for a run. The lines that settle it are
`[p] 516416 bytes ... thread rc=0 -- running`, the `Welcome to HEN 2.2.0 BETA`
notification, and the Debug Settings menu.
