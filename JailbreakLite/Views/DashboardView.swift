import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var engine: JailbreakEngine

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    deviceCard
                    actionCard
                    indicatorsCard
                }
                .padding()
            }
            .navigationTitle("JailbreakLite")
            .background(Color.black.ignoresSafeArea())
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(engine.state.rawValue)
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(Int(engine.progress * 100))%")
                    .monospacedDigit()
                    .foregroundStyle(.gray)
            }
            ProgressView(value: engine.progress)
                .tint(.green)
            if engine.hasKernelRW {
                Label("Kernel R/W active", systemImage: "checkmark.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .cardStyle()
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device")
                .font(.headline)
                .foregroundStyle(.white)
            if let d = engine.device {
                infoRow("Model", d.model)
                infoRow("iOS", d.systemVersion)
                infoRow("Kernel", d.kernelVersion)
                infoRow("PID", "\(d.pid)")
                infoRow("UID", "\(d.uid)")
                infoRow("Simulator", d.isSimulator ? "Yes" : "No")
            } else {
                Text("No device profile").foregroundStyle(.gray)
            }
        }
        .cardStyle()
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            Text("Actions")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await engine.runProbe() }
            } label: {
                actionLabel("Probe Environment", icon: "magnifyingglass", color: .blue)
            }
            .disabled(engine.state == .probing || engine.state == .exploiting)

            Button {
                Task { await engine.runExploit() }
            } label: {
                actionLabel("Run Exploit", icon: "bolt.fill", color: .orange)
            }
            .disabled(engine.state == .probing || engine.state == .exploiting)

            Button {
                Task { await engine.runPostExploitation() }
            } label: {
                actionLabel("Post-Exploitation", icon: "wrench.and.screwdriver.fill", color: .green)
            }
            .disabled(!engine.hasKernelRW || engine.state == .exploiting)

            Button {
                engine.reset()
            } label: {
                actionLabel("Reset", icon: "arrow.counterclockwise", color: .gray)
            }
        }
        .cardStyle()
    }

    private var indicatorsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Findings")
                .font(.headline)
                .foregroundStyle(.white)
            if engine.jailbreakIndicators.isEmpty && engine.writablePaths.isEmpty && engine.readableSensitivePaths.isEmpty {
                Text("Run a probe to map the environment.")
                    .foregroundStyle(.gray)
                    .font(.caption)
            } else {
                if !engine.jailbreakIndicators.isEmpty {
                    Text("Jailbreak indicators")
                        .font(.caption).foregroundStyle(.orange)
                    ForEach(engine.jailbreakIndicators, id: \.self) { item in
                        Text("• \(item)").font(.caption.monospaced()).foregroundStyle(.orange)
                    }
                }
                if !engine.writablePaths.isEmpty {
                    Text("Writable paths")
                        .font(.caption).foregroundStyle(.green)
                    ForEach(engine.writablePaths, id: \.self) { item in
                        Text("• \(item)").font(.caption.monospaced()).foregroundStyle(.green)
                    }
                }
                if !engine.readableSensitivePaths.isEmpty {
                    Text("Readable sensitive paths")
                        .font(.caption).foregroundStyle(.yellow)
                    ForEach(engine.readableSensitivePaths, id: \.self) { item in
                        Text("• \(item)").font(.caption.monospaced()).foregroundStyle(.yellow)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var statusColor: Color {
        switch engine.state {
        case .idle: return .gray
        case .probing, .exploiting, .postExploitation: return .orange
        case .jailed: return .red
        case .partial: return .yellow
        case .failed: return .red
        }
    }

    private func infoRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.gray)
            Spacer()
            Text(value).foregroundStyle(.white).monospaced()
        }
        .font(.caption)
    }

    private func actionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title).fontWeight(.semibold)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
