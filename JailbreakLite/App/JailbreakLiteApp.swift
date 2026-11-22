import SwiftUI

@main
struct JailbreakLiteApp: App {
    @StateObject private var engine = JailbreakEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .preferredColorScheme(.dark)
        }
    }
}
