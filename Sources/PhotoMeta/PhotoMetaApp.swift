import SwiftUI

@main
struct PhotoMetaApp: App {
    @StateObject private var library = PhotoLibrary()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}
