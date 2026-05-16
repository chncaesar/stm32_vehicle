import SwiftUI

/// 主遥控页面：方向控制 + 速度调节 + 状态栏。
struct ControlView: View {

    @ObservedObject var viewModel: CarControlViewModel

    var body: some View {
        VStack(spacing: 24) {
            // 连接状态栏
            connectionStatusBar

            Spacer(minLength: 0)

            // 方向盘
            DirectionPad(
                onPress: { viewModel.pressDirection($0) },
                onRelease: { viewModel.releaseDirection() },
                onEmergencyStop: { viewModel.sendEmergencyStop() },
                isEnabled: viewModel.connectionState == .ready
            )

            Spacer(minLength: 0)

            // 速度滑块
            SpeedSlider(speed: $viewModel.currentSpeed)
                .padding(.horizontal)

            // 断开按钮
            Button(role: .destructive) {
                viewModel.disconnect()
            } label: {
                Label("断开连接", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Connection Status Bar

    private var connectionStatusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(viewModel.connectionState.indicatorColor)
                .frame(width: 10, height: 10)

            Text(viewModel.connectionState.displayText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            // 显示当前速度
            HStack(spacing: 4) {
                Image(systemName: "speedometer")
                    .font(.caption)
                Text("速度 \(viewModel.currentSpeed)")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    ControlView(viewModel: CarControlViewModel())
}
