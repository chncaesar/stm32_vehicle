import SwiftUI

/// 根视图：根据 `connectionState` 切换连接页面和控制页面。
struct ContentView: View {

    @EnvironmentObject var viewModel: CarControlViewModel

    var body: some View {
        Group {
            switch viewModel.connectionState {
            case .idle, .scanning, .connecting, .discoveringServices, .disconnected, .error:
                ConnectionView(
                    state: viewModel.connectionState,
                    peripherals: viewModel.discoveredPeripherals,
                    onStartScan: { viewModel.startScan() },
                    onStopScan: { viewModel.stopScan() },
                    onConnect: { viewModel.connect(to: $0) }
                )
                .transition(.opacity)

            case .ready:
                ControlView(viewModel: viewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.connectionState)
    }
}

// MARK: - Preview

#Preview("Disconnected") {
    ContentView()
        .environmentObject(CarControlViewModel())
}
