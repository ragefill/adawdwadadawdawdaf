import SwiftUI

struct FileNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
}

struct FileSystemView: View {
    @EnvironmentObject var engine: JailbreakEngine
    @State private var currentPath: String = NSHomeDirectory()
    @State private var nodes: [FileNode] = []
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(currentPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.gray)
                            .lineLimit(2)
                        Spacer()
                        Button("Up") { goUp() }
                            .disabled(currentPath == "/")
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }

                Section("Entries") {
                    ForEach(nodes) { node in
                        Button {
                            if node.isDirectory { open(node.path) }
                        } label: {
                            HStack {
                                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(node.isDirectory ? .yellow : .cyan)
                                VStack(alignment: .leading) {
                                    Text(node.name).foregroundStyle(.white)
                                    if let size = node.size, !node.isDirectory {
                                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                            .font(.caption2).foregroundStyle(.gray)
                                    }
                                }
                                Spacer()
                                if node.isDirectory {
                                    Image(systemName: "chevron.right").foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filesystem")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Jump") {
                        Button("/var/mobile") { open("/var/mobile") }
                        Button("/private") { open("/private") }
                        Button("/etc") { open("/etc") }
                        Button("/usr") { open("/usr") }
                        Button("App Home") { open(NSHomeDirectory()) }
                        Button("Tmp") { open(NSTemporaryDirectory()) }
                    }
                }
            }
            .onAppear { open(currentPath) }
        }
    }

    private func open(_ path: String) {
        error = nil
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            error = "Not a directory or inaccessible: \(path)"
            return
        }
        do {
            let names = try fm.contentsOfDirectory(atPath: path).sorted()
            nodes = names.map { name in
                let full = (path as NSString).appendingPathComponent(name)
                var childDir: ObjCBool = false
                fm.fileExists(atPath: full, isDirectory: &childDir)
                let attrs = try? fm.attributesOfItem(atPath: full)
                let size = attrs?[.size] as? NSNumber
                return FileNode(name: name, path: full, isDirectory: childDir.boolValue, size: size?.int64Value)
            }
            currentPath = path
            engine.log("INFO", "FS: listed \(path) (\(nodes.count) entries)")
        } catch {
            self.error = error.localizedDescription
            engine.log("ERROR", "FS: \(path): \(error.localizedDescription)")
        }
    }

    private func goUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        open(parent.isEmpty ? "/" : parent)
    }
}
