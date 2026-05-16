import SwiftUI

@main
struct STM32CarApp: App {

    @StateObject private var viewModel = CarControlViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
