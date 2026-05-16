import CoreBluetooth

/// HM-10 / CC2541 蓝牙模块的 BLE 常量。
enum BLEConstants {
    /// HM-10 固定 Service UUID
    static let serviceUUID = CBUUID(string: "FFE0")
    /// HM-10 固定 Characteristic UUID（可读可写）
    static let characteristicUUID = CBUUID(string: "FFE1")

    // MARK: - 时间参数（秒）

    /// 扫描超时时间
    static let scanTimeout: TimeInterval = 10.0
    /// 重连间隔
    static let reconnectDelay: TimeInterval = 2.0
    /// 最大自动重连次数
    static let maxReconnectAttempts = 3
}
