# Main executable identity fix

## Device evidence

The user supplied the same-process bootstrap chain (PID 52371, time 1794933277):

```
constructor-enter diagnostic=startup-2
foundation-begin
image0 filetype=6 cpu=16777228 subtype=2147483650
identity bundle=com.tencent.tim
identity version=4.1.0
identity build=4.1.0.81
identity executable=QQ
identity uuid=ECAD96CF-3C8F-3E64-822D-4FEAE8B56FAF
identity-rejected reason=uuid-mismatch
```

This establishes that initialization ran and identity checking rejected the UUID. Image zero was a Mach-O dylib (filetype 6), not the executable (filetype 2). The old `timantirecall_mainUUID()` read `_dyld_get_image_header(0)`, so this run compared a dylib UUID against the expected TIM main UUID. It does not identify which dylib owns that UUID, nor prove all earlier failures had the same cause.

## Narrow correction

Baseline: 0.40, commit `23fc6cd6130d1a1a4772255471dee2f78955aa69`.

Use the public libc `_NSGetMachExecuteHeader()` declared in `crt_externs.h`; the locked iOS SDK exports it from libSystem for arm64/arm64e and declares a `mach_header_64 *` return under LP64. The actual loaded executable header is independent of dyld image-list order.

The UUID reader accepts only a mapped 64-bit ARM64_ALL MH_EXECUTE header, reads commands after the 32-byte header, rejects bad sizes/alignment and missing/duplicate UUIDs, and scans the entire declared command area. It is a parser for a valid runtime-mapped header from the system API; it is not an arbitrary untrusted-buffer parser or proof that any physically truncated memory is safe.

The exact expected UUID remains `3C237FA0-5985-3376-BF98-EF1698563247`. Bundle ID, version, build, executable name, own-method ABI and original forwarding checks remain. No wildcard identity bypass is added. Wire classification, message forwarding, logging writer and arm64 delivery policy are unchanged.

## Regression and device closure

- Native runtime fixtures: true executable UUID accepted; dylib with the correct UUID rejected; arm64e header rejected for this locked arm64 target; duplicate and malformed UUID commands rejected.
- Real macOS constructor smoke runs twice in separate HOME/TMPDIR sandboxes, once normally and once with a test dylib in DYLD_INSERT_LIBRARIES. The inserted case must independently observe image0 MH_DYLIB while its logged identity UUID equals the linker-provided `_mh_execute_header` UUID.
- Source regression rejects returning to `_dyld_get_image_header(0)` for the main UUID. Compiler/header checks, actual iOS build and final-file verification remain separate CI gates.

Device success still requires the real TIM executable UUID to match, followed by `identity-accepted`, `hook-installed-before-kernel`, actual push events and observed private/group recall preservation. This fix removes the demonstrated identity blocker; it does not establish device anti-recall acceptance by itself.
