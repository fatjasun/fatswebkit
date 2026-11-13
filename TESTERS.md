# Testing 14.02 support

This branch is upstream `8c62f66` ("Add 14.02 support") plus build switches that
let a 14.02 console run with the userland half of the port turned off. **The
offset values are upstream's, unchanged** — 89 of 89 fields identical. Nothing
here proposes a different table, so a mismatch against upstream is not a
finding.

What has *not* happened: this code has never run on a 14.02 console. That is
what you are for.

---

## 1. What you need

* A PS4 on **14.02**, with the WebKit entry point working (the browser stage is
  14.00's; it is the half that has already been proven on hardware).
* The console and a PC on the same network.
* `python3` on the PC.
* The `web/` folder from the release asset, which contains the runner.

## 2. Run it

On the PC, from inside `web/`:

```sh
python3 serve.py 8001
```

Note the PC's LAN address (`192.168.x.x`). On the console, open:

```
http://<pc-ip>:8001/index.html
```

Pick **Nova** (ps4-hen), press **DEPLOY**. Do not pick GoldHEN on 14.02 — its
step table is a list of 14.00 addresses, and the runner refuses it there.

The countdown is your window to get back to the browser. When it expires the
chain runs and the log fills in.

## 3. What a good run looks like

The log prints numbered steps. The ones that matter:

| line | meaning |
| --- | --- |
| `FW 14.02` | firmware detected, 14.02 stage selected |
| `[2]` … base | kernel base derived from the leak |
| `[8] 15 of 15 kernel patches in place` | **the number to report** |
| `[9] jailbroken, uid 0` | kernel is open |
| `[10] kernel interface is live` | handles held, teardown armed |
| `handles defused` | safe to close the page |
| `done -- jailbroken … enabler running` | payload loaded |

The step that matters for this port is `[8]`. It re-reads every patch site
after writing it. If any write missed, it says which and stops:

```
[8] 13 of 15 kernel patches in place -- first missing: copyinstr
     refusing to go on with a half patched kernel
```

That is a *useful result*, not a crash: it means an address is wrong and the
run stopped before doing anything with a half-patched kernel.

## 4. What to send back

Copy the whole log. It is plain text on the page; the runner also stores it.
Include:

1. Firmware (`14.02`), and whether the console is a retail unit.
2. The `[8]` line verbatim, whatever it says.
3. The last line reached.
4. If it panicked: the error code, and whether the console needed a cold boot.
5. Whether `hen.bin` loaded (any menu/notification appearing).

Photographs are fine but the text matters more — a photo of a 1080p television
loses the digits.

## 5. Failure playbook

| what you see | what it means | what to do |
| --- | --- | --- |
| `RAM: checking...` never changes | module never executed — a file 404 or was served as `text/plain` | the page now prints a diagnostic naming the file. Use `serve.py`, not `python -m http.server` |
| `not a PS4 browser` | opened on the PC, not the console | open it on the console |
| `[8] N of 15` | wrong address in the patch table | stop, send the line |
| `[9] prison0 pointer is … -- not touching credentials` | a data offset is wrong | stop, send the line |
| `the handles are NOT defused` | a teardown stub failed | **do not close the page**; cold boot |
| instant reboot / kernel panic | a patch landed mid-instruction | note the code, report it |

If you land in `NOT defused`, do not reload and do not close the browser — that
exit is what hangs the console. Cold boot.

## 6. Building switches

Both default to on, which is upstream behaviour. Build with `-D…=0` to narrow
the blast radius while testing:

| define | default | effect of `0` |
| --- | --- | --- |
| `HEN1402_USERLAND_OFFSETS_READY` | `1` | skips every 14.02 userland patch; kernel-side jailbreak still runs |
| `HEN1402_LIBKERNEL_DEBUGMENU_READY` | `1` | skips only the two `libkernel_sys` debug-menu writes |
| `HEN1402_INSTALLER_READY` | `1` | refuses 14.02 entirely (`MAX_FW 1400`) |

The most informative first run narrows to the kernel only:

```sh
EXTRA_CFLAGS="-DHEN1402_USERLAND_OFFSETS_READY=0" bash build.sh
```

`EXTRA_CFLAGS` is appended to the compiler flags in both Makefiles. A plain
`CFLAGS=` in the environment would do nothing: the Makefiles assign `CFLAGS`
with `:=`, which wins over the environment. Note that `make` does not see a
changed define until the objects are rebuilt, so `make -C kpayload clean`
first, or use `build.sh` in a fresh checkout.

If the console survives that and `[8]` reads 15 of 15, the kernel half is good
and any later panic is in the userland writes.

A prebuilt binary for that run ships in `payload/` as
`hen-14.02-kernelonly.bin`. To use it instead of building, replace
`web/nova1402.bin` with it and regenerate the manifest so the console does not
serve the cached copy:

```sh
cp payload/hen-14.02-kernelonly.bin web/nova1402.bin
cd web && bash make-manifest.sh
```

Verified difference between the two binaries, at the instruction level: the
narrowed build opens `shellcore_patch` with `cmp WORD PTR [rip+0x61e9], 0x57a`
/ `je` -- i.e. `fw_version == 1402` returns immediately -- while the default
build has no such compare at entry.

## 7. Where the numbers came from

* **Kernel table (15 sites)** — checked against a clean pre-patch 14.02 image and
  a post-patch image from a console. Applying the table to the first reproduces
  the second at all 15 rows; across 13.6 MB of text only 237 bytes differ, all
  accounted for (the 15 sites, 7 bootstrap writes, 3 trampolines, 4 loader
  pointer tables, 13 ASLR fixups).
* **89-field table** — identical to upstream `8c62f66`, independently
  corroborated by a third-party 14.02 build on 86 of 89 fields (the three
  exceptions are contradicted by the kernel image itself).
* **Userland patch offsets** — unchanged from 14.00. A point release does not
  rebuild those modules. Not byte-verified against real 14.02 modules; that is
  the gap this switch exists for.

Report against the branch, not against a memory of what "should" happen.
