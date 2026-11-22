import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var engine: JailbreakEngine

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(engine.logs) { entry in
                            Text(entry.formatted)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundStyle(color(for: entry.level))
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .padding()
                }
                .background(Color.black)
                .onChange(of: engine.logs.count) { _ in
                    if let last = engine.logs.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            .navigationTitle("Console")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { engine.logs.removeAll() }
                }
            }
        }
    }

    private func color(for level: String) -> Color {
        switch level {
        case "ERROR": return .red
        case "WARN": return .yellow
        case "INFO": return .green
        default: return .gray
        }
    }
}
