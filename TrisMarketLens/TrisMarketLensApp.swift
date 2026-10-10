import SwiftUI
import WakTrainerDesignSystem

@main
struct TrisMarketLensApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(WakColor.primary)
        }
    }
}
