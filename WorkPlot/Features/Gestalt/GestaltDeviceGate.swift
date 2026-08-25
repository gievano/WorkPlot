import Foundation

/// Gate yang menentukan apakah sebuah tweak boleh tampil di perangkat ini.
/// Diambil 1:1 dari WorkPlot agar `DeviceCapability.supports(_:)` tetap valid.
enum GestaltDeviceGate: Hashable {
    case iphone13OrLater
    case iphone13OrBelow
    case belowIPhone15
    case iphone11Or12Only
    case iphone14ProOrLater
    case belowIPhone14Pro
}
