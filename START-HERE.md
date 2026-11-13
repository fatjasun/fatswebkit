# 14.02 test build — start here

This build runs **HEN 2.2.0 BETA** on 14.02. The payload is the one you supplied,
not a rebuild of it.

## What changed since the last zip

On 14.02 the page now loads **`web/hen1402.bin`** — your `hen.bin`, 516,416
bytes, `sha256 6321c97294e647d1a1530e7b5762cf6760af4e4289005efad94c052d837fd949`.
The previous zip loaded a payload rebuilt here; this one loads yours.

The swap happens in one place, `afterglow.js`, at the only point that knows
which firmware the leak confirmed:

```js
const want =
  FW_KEY === "14.02" && (asked === "nova.bin" || asked === "hen.bin")
    ? "hen1402.bin"
    : asked;
```

So **Nova** on the landing page means "ps4-hen", and on 14.02 that resolves to
your binary. Naming `hen.bin` or `nova.bin` explicitly on 14.02 also lands on
`hen1402.bin` — the 14.00 builds in this folder must never run on a 14.02
kernel, because their patch lists name 14.00 functions.

## Why it will not refuse on 14.02

The refusal comes from the payload's own firmware gate. In your binary that gate
is at file offset `0x7470` and it is a range check, not a whitelist:

```
7470  add eax, 0xfffffa85      ; eax = fw - 1403
7475  cmp ax, 0xfc5e
7479  ja  0x7616               ; inside 474..1402 -> skip the error path
747f  ...                      ; otherwise: "Unsupported Firmware"
74ca  lea rdx, [rip + 0x72da]  ; the string, referenced exactly once
```

`0x57a` is 1402. For fw = 1402 the subtraction wraps to `0xffff`, which is above
`0xfc5e`, so the branch is taken and the notification is never reached. The
accepted range is **474 through 1402 inclusive**. There is no second gate: the
kernel side is a `cmp eax, 0x57a` dispatch at `0x18d1` with a full 14.02 block
behind it.

## What is verified about your payload (static)

| check | result |
| --- | --- |
| firmware gate accepts 14.02 | yes — range 474..1402, `0x57a` handled |
| 14.02 offset values | 35 of 35 byte-identical to our independently derived 14.02 table |
| 14.02 kernel block | present at `0x18d1`, offsets computed from the LSTAR MSR |
| block moves vs 14.00 | `+0x300` memcpy, `+0x370` string/ACMgr, `+0x480` sbl/keymgr — the exact shifts measured in a real 14.02 image |
| how it enters the kernel | `mov rax, 0xb; syscall` — the gate this exploit opens at `[10]` |
| image form | first byte `e9`, i.e. the raw-payload path the loader already handles |
| flash / NAND / EMC writes | none — every write is to RAM |

Not verified: nobody has watched **this** binary enable HEN on a 14.02 console
from this kit. The kernel stage of this kit has been seen on 14.02 hardware
(`[8] 15 of 15`, `[9] jailbroken, uid 0`, `[p] ... thread rc=0`), but that run
used the previous payload.

## 1. Extract it

Right-click the zip → **Extract All**. Do not run anything from inside the zip
viewer; Windows extracts to a temp folder and the server will refuse to start
with a confusing message.

## 2. Start the server

Double-click **`START-WINDOWS.bat`**. It prints the address to open on the
console:

```
  On the PS4 browser, open:

      http://192.168.1.42:8001/index.html
```

If it lists two addresses, pick the `192.168.x.x` or `10.x.x.x` one on the same
network as the console. macOS / Linux: `./START-MAC-LINUX.sh`.

## 3. Run it on the console

Open that address in the PS4 browser, pick **Nova**, press **DEPLOY**, and stay
on the page.

**Run it once per boot.** HEN writes `/user/temp/hen.installed` when it installs
and skips the install if that file exists, printing
`HEN is already installed. Skipping...`. On a second run in the same session
that message is expected and is not a failure — it means HEN is already up.

## 4. What to send back

The log, whole. The four lines that decide everything:

```
[8] 15 of 15 kernel patches in place
[9] jailbroken, uid 0
[10] kernel interface is live
[p] 516416 bytes at 0x..., thread rc=0 -- running
```

`516416` is the length of your binary. If that number is different, the console
fetched a different file.

Also say:

* did the **`Welcome to HEN 2.2.0 BETA`** notification appear?
* does **Settings → Debug Settings** now show the HEN menu?
* did SceShellUI restart on its own (screen blink, then the home screen)?
* retail console, and the exact firmware string shown in Settings

## If something goes wrong

| what you see | what it means | what to do |
| --- | --- | --- |
| `[p] ... does not start with a jmp` | the payload file is corrupt or cached wrong | reload with `?log=1`; the log names the file |
| `[p] ... did NOT start` | pthread_create failed | send the line, do not run it again |
| `[8] N of 15` | a kernel address is wrong | send the line; nothing further is attempted |
| `handles are NOT defused` | a teardown stub failed | **do not close or reload the page — cold boot** |
| instant reboot / panic | a patch landed mid-instruction | note the code, cold boot, report |
| `HEN is already installed` | second run in the same session | cold boot, run once |

The one instruction worth repeating: if it says **`NOT defused`**, cold boot the
console. Reloading or closing the browser at that point is what hangs it.

## What is in here

| path | what |
| --- | --- |
| `START-WINDOWS.bat` | the only thing you need to double-click |
| `web/` | the pages the console loads, and the payload it installs |
| `web/hen1402.bin` | HEN 2.2.0 BETA, the 14.02 payload |
| `HEN-1402-ACTIVATION.md` | how the 14.02 path was verified, line by line |
| `TESTERS.md` | the full protocol: every log line, every failure |
| `RELEASE-NOTES-1402.md` | what is verified, what is not, and the evidence |
| `patches/`, `source/` | the exploit's source, for anyone who wants to read it |
| `SHA256SUMS.txt` | hashes, to confirm nothing was mangled in transit |
