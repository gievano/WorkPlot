//
//  DeviceCapability.swift
//  WorkPlot
//
//  Real-hardware detection via hw.machine so device-gated tweaks can hide
//  themselves instead of writing capabilities a device cannot honour.
//  Spoofed CacheExtra ProductTypes are deliberately ignored here.
//

import Foundation

enum DeviceCapability {
    static let machineIdentifier: String = {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0,
              size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }()

    /// Major machine family number, e.g. 14 for iPhone14,5. nil on non-iPhone.
    static var iphoneFamily: Int? {
        guard machineIdentifier.hasPrefix("iPhone") else { return nil }
        let digits = machineIdentifier.dropFirst("iPhone".count).prefix { $0.isNumber }
        return Int(digits)
    }

    static func supports(_ gate: GestaltDeviceGate?) -> Bool {
        switch gate {
        case .iphone13OrLater:
            // Machine families do not map linearly to marketing names:
            // iPhone13,* is iPhone 12, while iPhone 13 starts at iPhone14,*.
            guard let family = iphoneFamily else { return false }
            return family >= 14
        case .iphone13OrBelow:
            guard let family = iphoneFamily else { return false }
            return family <= 14
        case .belowIPhone15:
            guard let family = iphoneFamily else { return false }
            // iPhone16,* and newer are iPhone 15 series and above.
            return family <= 15
        case .iphone11Or12Only:
            // Machine families map one below the marketing series:
            // iPhone12,* is iPhone 11, iPhone13,* is iPhone 12.
            guard let family = iphoneFamily else { return false }
            return family == 12 || family == 13
        case .iphone14ProOrLater:
            // Dynamic Island ships from the iPhone 14 Pro series
            // (iPhone15,*) onward; notch devices (family <= 14) excluded.
            guard let family = iphoneFamily else { return false }
            return family >= 15
        case nil:
            return true
        }
    }
}
