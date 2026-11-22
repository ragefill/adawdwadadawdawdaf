import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: JailbreakEngine
    @State private var payloadPath: String = ""
    @State private var deviceJSON: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exploit Payload") {
                    LabeledContent("Loaded", value: ExploitBridge.shared().loadedExploitName())
                    LabeledContent("Kernel R/W", value: engine.hasKernelRW ? "Yes" : "No")
                    Text("Drop a compatible exploit.dylib into the app Documents directory or bundle Frameworks/ExploitPayload.framework. Expected symbols: jl_exploit_run, jl_has_krw, jl_kread64, jl_kwrite64.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                Section("Device Info") {
                    Button("Refresh Device JSON") {
                        deviceJSON = ExploitBridge.shared().deviceInfoJSON()
                    }
                    if !deviceJSON.isEmpty {
                        Text(deviceJSON)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("Build") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "unknown")
                    LabeledContent("Mode", value: engine.hasKernelRW ? "Post-exploitation" : "Toolkit/Sandbox")
                }

                Section("About") {
                    Text("JailbreakLite is a jailbreak-style toolkit. It probes the environment, maps sandbox boundaries, and exposes a clean interface for loading compatible exploit payloads that provide kernel read/write primitives.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
