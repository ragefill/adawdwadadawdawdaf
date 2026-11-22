# JailbreakLite

A jailbreak-style iOS toolkit app (Swift/ObjC) that probes the environment, maps sandbox boundaries, and exposes a clean plugin interface for loading compatible exploit payloads that provide kernel read/write primitives.

> This is a **toolkit/scaffold with a real runtime interface**. It does environment probing, filesystem mapping, logging, and payload loading. Actual privilege escalation on modern iOS requires dropping in a compatible exploit payload (e.g. a dylib/framework implementing the expected ABI). Without a payload, it runs in toolkit mode and reports exactly what it can and can't do.

## What it does

- **Device/profile probe**: model, iOS version, kernel version, PID/UID, simulator detection.
- **Jailbreak indicator scan**: checks common paths/artifacts (`/Applications/Cydia.app`, MobileSubstrate, apt, sshd, etc.).
- **Sandbox boundary mapping**: tests readable sensitive paths and writable probe paths.
- **Exploit payload interface**: dynamically loads `exploit.dylib` (Documents or bundle) or `ExploitPayload.framework` and calls:
  - `int jl_exploit_run(void)`
  - `int jl_has_krw(void)`
  - `uint64_t jl_kread64(uint64_t addr)`
  - `int jl_kwrite64(uint64_t addr, uint64_t val)`
- **Post-exploitation hooks**: when kernel R/W is reported, enables post-exploitation flow and package deployment stubs.
- **Filesystem browser**: navigate readable directories from the app.
- **Console/logs**: timestamped runtime log.
- **Package view**: staged install interface for common post-jailbreak components (requires KRW for real deployment).

## Project layout

```
JailbreakLite/
  JailbreakLite.xcodeproj/
  JailbreakLite/
    App/
      JailbreakLiteApp.swift
      ContentView.swift
    Views/
      DashboardView.swift
      FileSystemView.swift
      PackageView.swift
      ConsoleView.swift
      SettingsView.swift
    Core/
      JailbreakEngine.swift
      ExploitBridge.h
      ExploitBridge.m
    Resources/
      Assets.xcassets/
    Info.plist
    JailbreakLite.entitlements
    JailbreakLite-Bridging-Header.h
  ExportOptions.plist
  build.sh
  README.md
```

## Building (macOS + Xcode required)

You need macOS with Xcode 15+ and an iOS SDK. Building an IPA cannot be done natively on Windows.

```bash
cd JailbreakLite
chmod +x build.sh
./build.sh
```

The script archives with `CODE_SIGNING_ALLOWED=NO` and packages an unsigned IPA at:

```
build/JailbreakLite-unsigned.ipa
```

### Signing / installing

An unsigned IPA must be signed before installation on device. Common options:

- **Xcode**: open the project, set your Development Team, build/run directly on device.
- **AltStore / Sideloadly**: sign with your Apple ID and sideload.
- **TrollStore** (on compatible iOS versions/devices): install the IPA persistently with the appropriate entitlement set.
- **ldid / codesign**: manual signing for advanced workflows.

For Xcode-managed signing, remove the `CODE_SIGNING_ALLOWED=NO` overrides in `build.sh` or archive from Xcode GUI.

## Exploit payload ABI

To wire in a real exploit, provide a dylib/framework exposing these C symbols:

```c
int jl_exploit_run(void);            // return 0 on success
int jl_has_krw(void);                // return nonzero if kernel r/w active
uint64_t jl_kread64(uint64_t addr);  // optional, used when krw active
int jl_kwrite64(uint64_t addr, uint64_t value); // optional
```

Place `exploit.dylib` in the app's Documents directory, or bundle as `Frameworks/ExploitPayload.framework/ExploitPayload`. The bridge probes on startup and the Dashboard "Run Exploit" button invokes `jl_exploit_run`.

## Notes

- Target: iOS 16.0+ (arm64). UI built with SwiftUI.
- The entitlements file includes JIT/unsigned-memory/library-validation flags for development flexibility; adjust for your signing method and target.
- `platform-application` and other private entitlements are not enabled by default; enable only with appropriate signing/provisioning.
- The package manager is an interface/staging layer. Real package deployment requires elevated filesystem access and a compatible environment.
- This project is structured so you can extend `ExploitBridge` with device/version-specific exploit chains or swap in your own payload.
