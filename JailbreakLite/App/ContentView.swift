import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: JailbreakEngine
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "bolt.shield.fill")
                }
                .tag(0)

            FileSystemView()
                .tabItem {
                    Label("Filesystem", systemImage: "folder.fill")
                }
                .tag(1)

            PackageView()
                .tabItem {
                    Label("Packages", systemImage: "shippingbox.fill")
                }
                .tag(2)

            ConsoleView()
                .tabItem {
                    Label("Console", systemImage: "terminal.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.green)
    }
}
