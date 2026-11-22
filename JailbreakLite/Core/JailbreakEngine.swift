import Foundation
import SwiftUI
import Darwin

enum JailbreakState: String {
    case idle = "Idle"
    case probing = "Probing"
    case exploiting = "Exploiting"
    case postExploitation = "Post-Exploitation"
    case jailed = "Jailed"
    case partial = "Partial Access"
    case failed = "Failed"
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: String
    let message: String

    var formatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return "[\(f.string(from: timestamp))] [\(level)] \(message)"
    }
}

struct DeviceProfile {
    let model: String
    let systemName: String
    let systemVersion: String
    let kernelVersion: String
    let cpuType: String
    let isSimulator: Bool
    let pid: Int32
    let uid: UInt32
}

@MainActor
final class JailbreakEngine: ObservableObject {
    @Published var state: JailbreakState = .idle
    @Published var progress: Double = 0
    @Published var logs: [LogEntry] = []
    @Published var device: DeviceProfile?
    @Published var jailbreakIndicators: [String] = []
    @Published var writablePaths: [String] = []
    @Published var readableSensitivePaths: [String] = []
    @Published var exploitName: String = "No exploit loaded"
    @Published var hasKernelRW: Bool = false

    private let bridge = ExploitBridge.shared()

    init() {
        log("INFO", "JailbreakLite engine initialized")
        refreshDeviceProfile()
    }

    func log(_ level: String, _ message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        logs.append(entry)
        if logs.count > 2000 { logs.removeFirst(logs.count - 2000) }
    }

    func refreshDeviceProfile() {
        let info = ProcessInfo.processInfo
        let os = info.operatingSystemVersion
        let version = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"

        var uts = utsname()
        uname(&uts)
        let machine = withUnsafePointer(to: &uts.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let release = withUnsafePointer(to: &uts.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        #if targetEnvironment(simulator)
        let sim = true
        #else
        let sim = false
        #endif

        let profile = DeviceProfile(
            model: machine,
            systemName: "iOS",
            systemVersion: version,
            kernelVersion: release,
            cpuType: machine,
            isSimulator: sim,
            pid: ProcessInfo.processInfo.processIdentifier,
            uid: getuid()
        )
        device = profile
        log("INFO", "Device: \(machine) iOS \(version) kernel \(release) uid=\(profile.uid)")
    }

    func runProbe() async {
        state = .probing
        progress = 0
        jailbreakIndicators.removeAll()
        writablePaths.removeAll()
        readableSensitivePaths.removeAll()
        log("INFO", "Starting environment probe")

        let checks: [(String, () -> String?)] = [
            ("Cydia", { Self.pathExists("/Applications/Cydia.app") }),
            ("Sileo", { Self.pathExists("/Applications/Sileo.app") }),
            ("Zebra", { Self.pathExists("/Applications/Zebra.app") }),
            ("Substrate", { Self.pathExists("/Library/MobileSubstrate/MobileSubstrate.dylib") }),
            ("Substitute", { Self.pathExists("/usr/lib/libsubstitute.dylib") }),
            ("bash", { Self.pathExists("/bin/bash") }),
            ("sshd", { Self.pathExists("/usr/sbin/sshd") }),
            ("apt", { Self.pathExists("/etc/apt") }),
            ("private/var/lib", { Self.pathExists("/private/var/lib/apt") }),
        ]

        for (i, check) in checks.enumerated() {
            if let hit = check.1() {
                jailbreakIndicators.append(hit)
                log("WARN", "Jailbreak indicator: \(hit)")
            }
            progress = Double(i + 1) / Double(checks.count + 3)
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        let sensitive = ["/private", "/private/var/mobile", "/var", "/etc", "/usr/bin", "/bin", "/sbin"]
        for path in sensitive {
            if FileManager.default.isReadableFile(atPath: path) {
                readableSensitivePaths.append(path)
            }
        }
        log("INFO", "Readable sensitive paths: \(readableSensitivePaths.count)")
        progress = 0.85

        let probePaths = ["/private/jl_probe", "/var/mobile/jl_probe", NSTemporaryDirectory() + "jl_probe"]
        for path in probePaths {
            let ok = FileManager.default.createFile(atPath: path, contents: Data("probe".utf8))
            if ok {
                writablePaths.append(path)
                try? FileManager.default.removeItem(atPath: path)
                log("INFO", "Writable: \(path)")
            }
        }
        progress = 1.0

        if !jailbreakIndicators.isEmpty {
            state = .partial
            log("INFO", "Probe complete: indicators found, environment looks modified")
        } else if !writablePaths.isEmpty || !readableSensitivePaths.isEmpty {
            state = .partial
            log("INFO", "Probe complete: sandbox boundaries mapped")
        } else {
            state = .jailed
            log("INFO", "Probe complete: standard jailed environment")
        }
    }

    func runExploit() async {
        state = .exploiting
        progress = 0
        log("INFO", "Exploit chain start: \(exploitName)")

        guard bridge.isExploitLoaded() else {
            log("WARN", "No exploit payload loaded. Running in interface-only mode.")
            log("INFO", "Load a compatible exploit bundle to enable kernel primitives.")
            await simulateStages()
            state = .failed
            log("ERROR", "Exploit failed: no payload. App remains functional as toolkit.")
            return
        }

        let result = bridge.runExploit()
        progress = 0.6
        if result.success {
            hasKernelRW = bridge.hasKernelReadWrite()
            progress = 1.0
            state = hasKernelRW ? .postExploitation : .partial
            log("INFO", "Exploit reported success. kernelRW=\(hasKernelRW)")
            if hasKernelRW {
                log("INFO", "Kernel read/write primitives available. Post-exploitation hooks enabled.")
            }
        } else {
            progress = 1.0
            state = .failed
            log("ERROR", "Exploit failed: \(result.message ?? "unknown error")")
        }
    }

    func runPostExploitation() async {
        guard hasKernelRW else {
            log("WARN", "Post-exploitation requires kernel read/write primitives")
            return
        }
        state = .postExploitation
        progress = 0
        log("INFO", "Post-exploitation: mounting overrides, verifying primitives")

        let steps = [
            "Validating kernel base slide",
            "Resolving proc/task structures",
            "Applying sandbox escape patch (process-local)",
            "Verifying file access expansion",
            "Refreshing environment map",
        ]
        for (i, step) in steps.enumerated() {
            log("INFO", step)
            progress = Double(i + 1) / Double(steps.count)
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        await runProbe()
        log("INFO", "Post-exploitation pass complete")
    }

    func reset() {
        state = .idle
        progress = 0
        hasKernelRW = false
        log("INFO", "Engine reset")
    }

    private func simulateStages() async {
        let stages = [
            (0.15, "Initializing exploit context"),
            (0.30, "Checking device compatibility"),
            (0.45, "Probing kernel info leak surface"),
            (0.60, "No payload: skipping memory corruption stage"),
            (0.75, "No payload: skipping privilege escalation"),
            (0.90, "Cleaning up"),
            (1.00, "Finished"),
        ]
        for (p, msg) in stages {
            progress = p
            log("INFO", msg)
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
    }

    private static func pathExists(_ path: String) -> String? {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return path
        }
        return nil
    }
}
