# 14.02 support — tester build

Upstream `8c62f66` ("Add 14.02 support") plus build switches around the halves
that are not yet proven on hardware.

**The offsets are upstream's.** 89 of 89 fields match `8c62f66` exactly, so this
is not a competing table. What it adds is the ability to run a 14.02 console
with the unverified half disabled.

## Verified

| check | result |
| --- | --- |
| 89-field table vs upstream `8c62f66` | **89 / 89 identical** |
| Kernel patch sites vs clean + post-patch 14.02 images | **15 / 15 rows reproduced byte for byte** |
| Whole text image diff (13.6 MB) | 237 bytes in 42 runs, all accounted for |
| Third-party 14.02 build's embedded table | 86 / 89 agree; the 3 exceptions are contradicted by the kernel image |
| Kernel symbols across two independent 14.02 dumps | 35 / 35 agree |

The 15 sites are confirmed from both ends of one build: a clean pre-patch image
and a post-patch image off a console. Applying the table to the first reproduces
the second at every row. Nothing else in the text segment moved except the
bootstrap's own writes, three trampolines, four loader pointer tables and
thirteen ASLR fixups.

## Not verified

* **Nothing has run on a 14.02 console.** Every claim above is static.
* **Userland patch offsets are not byte-verified** against real 14.02 modules —
  none were available. They are unchanged from 14.00 on the reasoning that a
  point release does not rebuild those modules, which upstream and a third-party
  build both assume. Hence `HEN1402_USERLAND_OFFSETS_READY`.
* **Two `libkernel_sys` debug-menu offsets** (`0x1D100`, `0x1D460`) do not land
  on function entries in the real module. They are dead code — `apply_patches()`
  calls `shellui_patch()` behind `if (0)` — so they cannot panic, but do not
  trust them.
* **One patch row is arithmetic-awkward**: `0x2bd85d` becomes `eb 41`, jumping to
  `0x2bd8a0`, which is the last byte of a `lea` under the most likely function
  alignment. The counter-evidence is that the console carrying these exact bytes
  survived and produced the dump. Evidence, not proof.

## Assets

| file | what it is |
| --- | --- |
| `hen.bin` | ps4-hen payload, built from this branch |
| `kpayload.bin` | the kernel payload embedded in `hen.bin` |
| `afterglow-web.zip` | the WebKit-side runner that loads `hen.bin` on 14.02 |
| `SHA256SUMS.txt` | hashes for the above |

Hashes are in `SHA256SUMS.txt`. `hen.bin` was built with
`Scene-Collective/ps4-payload-sdk` (`libPS4` compiled from source, gcc). A CI
build may differ byte-wise while being functionally the same — compare
behaviour, not hashes, if you rebuild.

## Install

1. Serve `afterglow-web/` (`python3 serve.py 8001`) and open `index.html` on the
   console.
2. Choose **Nova**, press **DEPLOY**.
3. Report the `[8]` line — see `TESTERS.md`.

GoldHEN is not available on 14.02: its image is 14.00's and its step table is a
list of 14.00 addresses.

## Changes over upstream `8c62f66`

Five files, +241/−32, no offset values changed:

* `kpayload/source/patch.c` — `HEN1402_USERLAND_OFFSETS_READY` and
  `HEN1402_LIBKERNEL_DEBUGMENU_READY` switches (default on), plus a function-entry
  read-back check before the two `libkernel_sys` writes.
* `kpayload/source/offsets/1402.c` — same values, with per-field provenance and
  the derivation notes.
* `installer/include/version.h` — `MAX_FW` behind `HEN1402_INSTALLER_READY`.
* `installer/include/offsets.h` — `K1402_XFAST_SYSCALL` fallback for an older
  pinned SDK (the current SDK defines it).
* `installer/source/kpayloads.c` — `build_kpayload_fw()` shim for older SDKs.

`kpayload/include/offsets/1402.h`, `kpayload/source/offsets/1400.c` and
`kpayload/source/offsets_file.c` are byte-identical to upstream.
