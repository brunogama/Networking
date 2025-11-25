import SwiftUI

@main
struct MacroSampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 900, height: 700)
  }
}
