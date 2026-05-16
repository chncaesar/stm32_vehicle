import Foundation

/// STM32 小车蓝牙指令。
///
/// 每条指令编码为 3 字节 ASCII + `\r\n` 帧尾，
/// 与固件 `USART_RX_STA & 0x8000` 帧结束标志匹配。
enum BLECommand {
    /// 方向 — 按下指令
    case directionPress(Direction)
    /// 方向 — 松开指令（统一发 `ONF`）
    case directionRelease
    /// 速度 — 按下（`ON1`–`ON9`）
    case speedPress(Int)
    /// 速度 — 松开（`ONa`–`ONi`）
    case speedRelease(Int)
    /// 紧急停车（`ONE`）
    case emergencyStop

    enum Direction {
        case forward
        case backward
        case left
        case right
    }
}

// MARK: - 编码

extension BLECommand {
    /// 编码后的二进制数据，可直接通过 BLE 写入。
    var data: Data {
        let str: String
        switch self {
        case .directionPress(let d):
            switch d {
            case .forward:  str = "ONA"
            case .backward: str = "ONB"
            case .left:     str = "ONC"
            case .right:    str = "OND"
            }
        case .directionRelease:
            str = "ONF"
        case .emergencyStop:
            str = "ONE"
        case .speedPress(let n):
            str = "ON\(clampSpeed(n))"
        case .speedRelease(let n):
            // 1 → a, 2 → b, …, 9 → i
            let ascii = 96 + clampSpeed(n)
            str = "ON\(UnicodeScalar(ascii)!)"
        }
        return Data((str + "\r\n").utf8)
    }

    /// 人类可读的描述，用于日志
    var description: String {
        switch self {
        case .directionPress(let d):
            switch d {
            case .forward:  return "前进"
            case .backward: return "后退"
            case .left:     return "左转"
            case .right:    return "右转"
            }
        case .directionRelease:
            return "停止"
        case .emergencyStop:
            return "紧急停车"
        case .speedPress(let n):
            return "速度 \(n) (按下)"
        case .speedRelease(let n):
            return "速度 \(n) (松开)"
        }
    }
}

// MARK: - Helpers

private func clampSpeed(_ n: Int) -> Int {
    max(1, min(9, n))
}
