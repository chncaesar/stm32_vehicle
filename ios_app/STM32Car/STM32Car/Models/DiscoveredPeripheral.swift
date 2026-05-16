import CoreBluetooth

/// BLE 扫描到的外设及其信号强度。
struct DiscoveredPeripheral: Identifiable, Equatable {
    let peripheral: CBPeripheral
    let rssi: NSNumber

    var id: UUID { peripheral.identifier }

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.peripheral.identifier == rhs.peripheral.identifier
    }
}
