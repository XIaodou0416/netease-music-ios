import SwiftUI

@main
struct BeansApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var player = PlayerManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(player)
        }
    }
}