import Foundation

struct AIRegionProfile: Equatable {
    let marketingName: String
    let regulatoryModel: String

    private static let regulatoryModels: [String: String] = [
        "iPhone 17e": "A3575",
        "iPhone 17 Pro Max": "A3257",
        "iPhone 17 Pro": "A3256",
        "iPhone 17": "A3258",
        "iPhone Air": "A3260",
        "iPhone 16e": "A3212",
        "iPhone 16 Pro Max": "A3084",
        "iPhone 16 Pro": "A3083",
        "iPhone 16 Plus": "A3082",
        "iPhone 16": "A3081",
        "iPhone 15 Pro Max": "A2849",
        "iPhone 15 Pro": "A2848"
    ]

    private static let productTypes: [String: AIRegionProfile] = [
        "iPhone16,1": .init(marketingName: "iPhone 15 Pro", regulatoryModel: "A2848"),
        "iPhone16,2": .init(marketingName: "iPhone 15 Pro Max", regulatoryModel: "A2849"),
        "iPhone17,1": .init(marketingName: "iPhone 16 Pro", regulatoryModel: "A3083"),
        "iPhone17,2": .init(marketingName: "iPhone 16 Pro Max", regulatoryModel: "A3084"),
        "iPhone17,3": .init(marketingName: "iPhone 16", regulatoryModel: "A3081"),
        "iPhone17,4": .init(marketingName: "iPhone 16 Plus", regulatoryModel: "A3082"),
        "iPhone17,5": .init(marketingName: "iPhone 16e", regulatoryModel: "A3212"),

        // Apple Intelligence iPads. Cellular variants map to their US
        // equivalent, including devices sold originally in mainland China.
        "iPad13,4": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2377"),
        "iPad13,5": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2459"),
        "iPad13,6": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2301"),
        "iPad13,7": .init(marketingName: "iPad Pro 11-inch (M1)", regulatoryModel: "A2301"),
        "iPad13,8": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2378"),
        "iPad13,9": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2461"),
        "iPad13,10": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2379"),
        "iPad13,11": .init(marketingName: "iPad Pro 12.9-inch (M1)", regulatoryModel: "A2379"),
        "iPad13,16": .init(marketingName: "iPad Air (M1)", regulatoryModel: "A2588"),
        "iPad13,17": .init(marketingName: "iPad Air (M1)", regulatoryModel: "A2589"),
        "iPad14,3": .init(marketingName: "iPad Pro 11-inch (M2)", regulatoryModel: "A2759"),
        "iPad14,4": .init(marketingName: "iPad Pro 11-inch (M2)", regulatoryModel: "A2435"),
        "iPad14,5": .init(marketingName: "iPad Pro 12.9-inch (M2)", regulatoryModel: "A2436"),
        "iPad14,6": .init(marketingName: "iPad Pro 12.9-inch (M2)", regulatoryModel: "A2764"),
        "iPad14,8": .init(marketingName: "iPad Air 11-inch (M2)", regulatoryModel: "A2902"),
        "iPad14,9": .init(marketingName: "iPad Air 11-inch (M2)", regulatoryModel: "A2903"),
        "iPad14,10": .init(marketingName: "iPad Air 13-inch (M2)", regulatoryModel: "A2898"),
        "iPad14,11": .init(marketingName: "iPad Air 13-inch (M2)", regulatoryModel: "A2899"),
        "iPad15,3": .init(marketingName: "iPad Air 11-inch (M3)", regulatoryModel: "A3266"),
        "iPad15,4": .init(marketingName: "iPad Air 11-inch (M3)", regulatoryModel: "A3267"),
        "iPad15,5": .init(marketingName: "iPad Air 13-inch (M3)", regulatoryModel: "A3268"),
        "iPad15,6": .init(marketingName: "iPad Air 13-inch (M3)", regulatoryModel: "A3269"),
        "iPad16,1": .init(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2993"),
        "iPad16,2": .init(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2995"),
        "iPad16,3": .init(marketingName: "iPad Pro 11-inch (M4)", regulatoryModel: "A2836"),
        "iPad16,4": .init(marketingName: "iPad Pro 11-inch (M4)", regulatoryModel: "A2837"),
        "iPad16,5": .init(marketingName: "iPad Pro 13-inch (M4)", regulatoryModel: "A2925"),
        "iPad16,6": .init(marketingName: "iPad Pro 13-inch (M4)", regulatoryModel: "A2926"),
        "iPad16,8": .init(marketingName: "iPad Air 11-inch (M4)", regulatoryModel: "A3459"),
        "iPad16,9": .init(marketingName: "iPad Air 11-inch (M4)", regulatoryModel: "A3460"),
        "iPad16,10": .init(marketingName: "iPad Air 13-inch (M4)", regulatoryModel: "A3461"),
        "iPad16,11": .init(marketingName: "iPad Air 13-inch (M4)", regulatoryModel: "A3462"),
        "iPad17,1": .init(marketingName: "iPad Pro 11-inch (M5)", regulatoryModel: "A3357"),
        "iPad17,2": .init(marketingName: "iPad Pro 11-inch (M5)", regulatoryModel: "A3358"),
        "iPad17,3": .init(marketingName: "iPad Pro 13-inch (M5)", regulatoryModel: "A3360"),
        "iPad17,4": .init(marketingName: "iPad Pro 13-inch (M5)", regulatoryModel: "A3361")
    ]

    init?(plist: [String: Any]) {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        let marketingKeys = ["Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"]

        let storedName = marketingKeys
            .compactMap { cacheExtra[$0] as? String }
            .first { Self.regulatoryModels[$0] != nil }

        if let profile = Self.profile(forProductType: Self.detectedProductType(in: plist)) {
            self = profile
            return
        }

        guard let marketingName = storedName,
              let regulatoryModel = Self.regulatoryModels[marketingName] else {
            return nil
        }
        self.marketingName = marketingName
        self.regulatoryModel = regulatoryModel
    }

    init(marketingName: String, regulatoryModel: String) {
        self.marketingName = marketingName
        self.regulatoryModel = regulatoryModel
    }

    private static func profile(forProductType productType: String) -> AIRegionProfile? {
        if let profile = productTypes[productType] {
            return profile
        }

        // MobileGestalt can append a board/configuration suffix (for example,
        // "iPad16,3-A"). The device family identifier before the suffix is the
        // stable value used by the model map.
        guard let separator = productType.firstIndex(of: "-") else { return nil }
        return productTypes[String(productType[..<separator])]
    }

    static func detectedProductType(in plist: [String: Any]) -> String {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        return cacheExtra["0+nc/Udy4WNG8S+Q7a/s1A"] as? String ?? machineIdentifier
    }

    private static var machineIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0,
              size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }
}

struct AIRegionConfiguration: Equatable {
    let profile: AIRegionProfile
    let spoofedProductType: String?
    let spoofedHardwareModel: String?
    let spoofedCPUModel: String?

    var requiresDeviceSpoofing: Bool { spoofedProductType != nil }

    static func resolve(for plist: [String: Any]) -> AIRegionConfiguration {
        if let profile = AIRegionProfile(plist: plist) {
            return AIRegionConfiguration(
                profile: profile,
                spoofedProductType: nil,
                spoofedHardwareModel: nil,
                spoofedCPUModel: nil
            )
        }

        let productType = AIRegionProfile.detectedProductType(in: plist)
        if productType.hasPrefix("iPad") {
            return AIRegionConfiguration(
                profile: AIRegionProfile(marketingName: "iPad mini (A17 Pro)", regulatoryModel: "A2993"),
                spoofedProductType: "iPad16,1",
                spoofedHardwareModel: "J410AP",
                spoofedCPUModel: "t8130"
            )
        }

        return AIRegionConfiguration(
            profile: AIRegionProfile(marketingName: "iPhone 15 Pro", regulatoryModel: "A2848"),
            spoofedProductType: "iPhone16,1",
            spoofedHardwareModel: "D83AP",
            spoofedCPUModel: "t8130"
        )
    }
}

enum AIRegionKeys {
    static let eligibility = "A62OafQ85EJAiiqKn4agtg"
    static let productType = "h9jDsbgj7xIVeIQ8S3/X3Q"
    static let hardwareModel = "oYicEKzVTz4/CxxE05pEgQ"
    static let cpuModel = "5pYKlGnYYBzGvAlIU8RjEQ"
    static let regionCode = "h63QSdBCiT/z0WU6rdQv6Q"
    static let regionSuffix = "yK+xavymRGZ3xWc1tb8XDg"
    static let regulatoryModel = "97JDvERpVwO+GHtthIh7hA"
}

enum AIRegionApplier {
    /// Stages US-region values into the plist so Apple Intelligence becomes
    /// eligible. Returns the configuration used, for post-write verification.
    @discardableResult
    static func apply(to plist: inout [String: Any]) throws -> AIRegionConfiguration {
        guard var cacheExtra = plist["CacheExtra"] as? [String: Any] else {
            throw PlistValueError.invalid("MobileGestalt tidak punya CacheExtra.")
        }

        let configuration = AIRegionConfiguration.resolve(for: plist)
        if let productType = configuration.spoofedProductType,
           let hardwareModel = configuration.spoofedHardwareModel,
           let cpuModel = configuration.spoofedCPUModel {
            cacheExtra[AIRegionKeys.eligibility] = 1
            cacheExtra[AIRegionKeys.productType] = productType
            cacheExtra[AIRegionKeys.hardwareModel] = hardwareModel
            cacheExtra[AIRegionKeys.cpuModel] = cpuModel
        }
        cacheExtra[AIRegionKeys.regionCode] = "LL"
        cacheExtra[AIRegionKeys.regionSuffix] = "LL/A"
        cacheExtra[AIRegionKeys.regulatoryModel] = configuration.profile.regulatoryModel

        plist["CacheExtra"] = cacheExtra
        return configuration
    }
}
