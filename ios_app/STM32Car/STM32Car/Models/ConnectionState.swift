import SwiftUI

/// BLE 连接状态机，覆盖从初始到就绪再到断开的完整生命周期。
enum ConnectionState: Equatable {
    /// 初始状态，尚未开始扫描
    case idle
    /// CBCentralManager 正在扫描外设
    case scanning
    /// 正在连接某个外设，携带设备名称用于 UI 展示
    case connecting(peripheral: String)
    /// 已连接，正在发现服务和特征
    case discoveringServices
    /// 特征已找到，可以收发指令
    case ready
    /// 连接已断开，携带原因描述
    case disconnected(reason: String)
    /// 不可恢复错误（蓝牙权限拒绝、硬件不支持等）
    case error(String)
}

// MARK: - UI 辅助属性

extension ConnectionState {
    /// 状态指示灯颜色
    var indicatorColor: Color {
        switch self {
        case .ready:
            return .green
        case .scanning, .connecting, .discoveringServices:
            return .yellow
        default:
            return .red
        }
    }

    /// 状态描述文本
    var displayText: String {
        switch self {
        case .idle:
            return "未连接"
        case .scanning:
            return "扫描中…"
        case .connecting(let name):
            return "连接 \(name)…"
        case .discoveringServices:
            return "初始化…"
        case .ready:
            return "已连接"
        case .disconnected(let reason):
            return "断开：\(reason)"
        case .error(let msg):
            return "错误：\(msg)"
        }
    }
}
