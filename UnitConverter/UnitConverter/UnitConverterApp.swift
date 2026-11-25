import SwiftUI

extension Color {
    /// App accent color. Defined in code (not only in Assets.xcassets) so it also
    /// applies to the Swift package / xtool build, which excludes the asset catalog.
    static let brand = Color(red: 0.0, green: 0.416, blue: 0.584)
}

@main
struct UnitConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.brand)
        }
    }
}
