import SwiftUI
import CoreBluetooth

/// 设备扫描与连接页面。
struct ConnectionView: View {

    let state: ConnectionState
    let peripherals: [DiscoveredPeripheral]
    let onStartScan: () -> Void
    let onStopScan: () -> Void
    let onConnect: (CBPeripheral) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部提示
            VStack(spacing: 8) {
                Image(systemName: stateIcon)
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text(state.displayText)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 32)

            // 扫描按钮
            Button(action: {
                if state == .scanning { onStopScan() } else { onStartScan() }
            }) {
                Label(
                    state == .scanning ? "停止扫描" : "扫描设备",
                    systemImage: state == .scanning ? "stop.circle" : "antenna.radiowaves.left.and.right"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .disabled(state.isError)

            // 设备列表
            if peripherals.isEmpty && state != .scanning {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("未发现设备")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("确认 HM-10 已上电且在小车扩展板上")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(peripherals) { device in
                        Button {
                            onConnect(device.peripheral)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.peripheral.name ?? "未知设备")
                                        .font(.body.weight(.medium))
                                        .tint(.primary)
                                    HStack(spacing: 4) {
                                        Image(systemName: RSSIBars(rssi: device.rssi.intValue))
                                            .font(.caption2)
                                            .foregroundStyle(rssiColor(device.rssi.intValue))
                                        Text("\(device.rssi.intValue) dBm")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                if state == .connecting(peripheral: device.peripheral.name ?? "未知设备") {
                                    ProgressView()
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }

            // 错误提示
            if case .error(let msg) = state {
                VStack(spacing: 8) {
                    Label(msg, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if msg.contains("权限") {
                        Button("前往设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption)
                    }
                }
                .padding()
            }
        }
    }

    private var stateIcon: String {
        switch state {
        case .idle:                 return "antenna.radiowaves.left.and.right.slash"
        case .scanning:             return "antenna.radiowaves.left.and.right"
        case .connecting:           return "link.icloud"
        case .discoveringServices:  return "gearshape.2"
        case .ready:                return "checkmark.circle"
        case .disconnected:         return "wifi.slash"
        case .error:                return "exclamationmark.triangle"
        }
    }

    // MARK: - RSSI Helpers

    private func RSSIBars(rssi: Int) -> String {
        switch rssi {
        case ..<(-80): return "wifi.slash"
        case ..<(-60): return "wifi.1"
        case ..<(-40): return "wifi.2"
        default:       return "wifi.3"
        }
    }

    private func rssiColor(_ rssi: Int) -> Color {
        switch rssi {
        case ..<(-80): return .red
        case ..<(-60): return .orange
        case ..<(-40): return .yellow
        default:       return .green
        }
    }
}

// MARK: - Preview

#Preview("Idle") {
    ConnectionView(
        state: .idle,
        peripherals: [],
        onStartScan: {},
        onStopScan: {},
        onConnect: { _ in }
    )
}

#Preview("Scanning") {
    ConnectionView(
        state: .scanning,
        peripherals: [],
        onStartScan: {},
        onStopScan: {},
        onConnect: { _ in }
    )
}
