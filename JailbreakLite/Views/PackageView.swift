import SwiftUI

struct PackageItem: Identifiable {
    let id = UUID()
    let name: String
    let identifier: String
    let version: String
    let description: String
    let status: String
}

struct PackageView: View {
    @EnvironmentObject var engine: JailbreakEngine
    @State private var packages: [PackageItem] = [
        PackageItem(name: "OpenSSH", identifier: "openssh", version: "9.x", description: "SSH server for remote shell access. Requires root filesystem access.", status: "Available"),
        PackageItem(name: "Filza Bridge", identifier: "filza-bridge", version: "1.0", description: "File manager integration hook for elevated filesystem browsing.", status: "Available"),
        PackageItem(name: "Substrate Loader", identifier: "substrate-loader", version: "0.1", description: "Tweak injection loader stub. Requires kernel/task patch primitives.", status: "Needs KRW"),
        PackageItem(name: "AppSync Stub", identifier: "appsync-stub", version: "0.1", description: "Unsigned package installation hook interface.", status: "Needs KRW"),
    ]
    @State private var selected: PackageItem?

    var body: some View {
        NavigationStack {
            List(packages) { pkg in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(pkg.name).font(.headline).foregroundStyle(.white)
                        Spacer()
                        Text(pkg.status)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(statusColor(pkg.status).opacity(0.2))
                            .foregroundStyle(statusColor(pkg.status))
                            .clipShape(Capsule())
                    }
                    Text(pkg.identifier + " • " + pkg.version)
                        .font(.caption.monospaced()).foregroundStyle(.gray)
                    Text(pkg.description)
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Install") {
                        install(pkg)
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .disabled(pkg.status == "Needs KRW" && !engine.hasKernelRW)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Packages")
        }
    }

    private func install(_ pkg: PackageItem) {
        if pkg.status == "Needs KRW" && !engine.hasKernelRW {
            engine.log("WARN", "Package \(pkg.identifier) requires kernel R/W")
            return
        }
        engine.log("INFO", "Package install requested: \(pkg.identifier)")
        engine.log("INFO", "Package manager: staging \(pkg.name) \(pkg.version)")
        if engine.hasKernelRW {
            engine.log("INFO", "KRW present: would remount and deploy package payload")
        } else {
            engine.log("WARN", "No KRW: package staged in sandbox only; deployment requires elevated privileges")
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Available": return .green
        case "Needs KRW": return .orange
        default: return .gray
        }
    }
}
