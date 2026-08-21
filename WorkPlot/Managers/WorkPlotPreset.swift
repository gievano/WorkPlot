//
//  WorkPlotPreset.swift
//  WorkPlot
//
//  Preset format v1: a named set of CacheExtra key/value pairs applied to
//  MobileGestalt through the existing ExploitManager write path (which backs
//  up the original plist before every save).
//

import Foundation

enum PresetValue: Hashable {
    case string(String)
    case integer(Int)
    case floating(Double)
    case boolean(Bool)
    case data(String)

    /// Tagged encoding so Base64 Data never collides with a plain String.
    private enum Kind: String, Codable {
        case string, integer, floating, boolean, data
    }

    var plistValue: Any {
        switch self {
        case .string(let value): value
        case .integer(let value): NSNumber(value: value)
        case .floating(let value): NSNumber(value: value)
        case .boolean(let value): NSNumber(value: value)
        case .data(let base64): Data(base64Encoded: base64) ?? Data()
        }
    }
}

extension PresetValue: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .integer: self = .integer(try container.decode(Int.self, forKey: .value))
        case .floating: self = .floating(try container.decode(Double.self, forKey: .value))
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .data: self = .data(try container.decode(String.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let value):
            try container.encode(Kind.string, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .integer(let value):
            try container.encode(Kind.integer, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .floating(let value):
            try container.encode(Kind.floating, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .boolean(let value):
            try container.encode(Kind.boolean, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .data(let base64):
            try container.encode(Kind.data, forKey: .kind)
            try container.encode(base64, forKey: .value)
        }
    }
}

enum PresetError: LocalizedError {
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let detail): detail
        }
    }
}

struct WorkPlotPreset: Codable, Hashable, Identifiable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var name: String
    var author: String
    var risky: Bool
    var values: [String: PresetValue]

    var id: String { name }

    init(name: String,
         author: String,
         risky: Bool = false,
         values: [String: PresetValue],
         formatVersion: Int = WorkPlotPreset.currentFormatVersion) {
        self.formatVersion = formatVersion
        self.name = name
        self.author = author
        self.risky = risky
        self.values = values
    }

    func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> WorkPlotPreset {
        let preset = try JSONDecoder().decode(WorkPlotPreset.self, from: data)
        guard preset.formatVersion == currentFormatVersion else {
            throw PresetError.invalidFormat("Unsupported preset format version \(preset.formatVersion).")
        }
        guard !preset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresetError.invalidFormat("Preset name must not be empty.")
        }
        guard !preset.values.isEmpty else {
            throw PresetError.invalidFormat("Preset contains no Gestalt values.")
        }
        return preset
    }

    /// Decodes a URL-safe Base64 payload from a workplot://preset link.
    static func decodeURLPayload(_ payload: String) throws -> WorkPlotPreset {
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else {
            throw PresetError.invalidFormat("Preset payload is not valid Base64.")
        }
        return try decode(from: data)
    }
}

enum BuiltinPresets {
    static let all: [WorkPlotPreset] = [
        // ProductType/boardConfig only: device-name keys are intentionally not
        // invented, matching DeviceSpoofingManager's never-invent-keys rule.
        WorkPlotPreset(
            name: "iPhone 17 Pro Max Spoof",
            author: "WorkPlot",
            risky: true,
            values: Dictionary(uniqueKeysWithValues:
                DeviceSpoofingManager.productTypeKeys.map { ($0, .string("iPhone18,2")) }
                + DeviceSpoofingManager.boardConfigKeys.map { ($0, .string("D97AP")) }
            )
        ),
        WorkPlotPreset(
            name: "Dynamic Island Max",
            author: "WorkPlot",
            risky: true,
            values: [
                GestaltArtwork.dynamicIslandCapabilityKey: .integer(1),
                "ykpu7qyhqFweVMKtxNylWA": .integer(1),
                "2OOJf1VhaM7NxfRok3HbWQ": .integer(1),
                "j8/Omm6s1lsmTDFsXjsBfA": .integer(1)
            ]
        ),
        WorkPlotPreset(
            name: "Reset Wajar",
            author: "WorkPlot",
            values: [
                "EqrsVvjcYDdxHBiQ": .integer(0),
                "LBJfwOEzExRxzlAnSuI7eg": .integer(0),
                "XYlJKKkj2hztRP1NWWnhlw": .integer(0),
                "SAGvsp6O6kAQ4fEfDJpC4Q": .integer(0)
            ]
        )
    ]
}

final class PresetStore: ObservableObject {
    static let shared = PresetStore()

    @Published private(set) var userPresets: [WorkPlotPreset] = []

    let builtinPresets: [WorkPlotPreset] = BuiltinPresets.all

    private static var directory: URL? {
        guard let documents = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let directory = documents.appendingPathComponent("Preset", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private init() {
        reload()
    }

    func reload() {
        guard let directory = Self.directory else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])) ?? []
        userPresets = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? WorkPlotPreset.decode(from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func add(_ preset: WorkPlotPreset) throws {
        guard let directory = Self.directory else {
            throw PresetError.invalidFormat("Preset storage is unavailable.")
        }
        let data = try preset.encodedJSON()
        try data.write(to: directory.appendingPathComponent(fileName(for: preset)), options: .atomic)
        reload()
    }

    func remove(_ preset: WorkPlotPreset) {
        guard let directory = Self.directory else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName(for: preset)))
        reload()
    }

    func importData(_ data: Data) throws -> WorkPlotPreset {
        let preset = try WorkPlotPreset.decode(from: data)
        try add(preset)
        return preset
    }

    func importURLPayload(_ payload: String) throws -> WorkPlotPreset {
        let preset = try WorkPlotPreset.decodeURLPayload(payload)
        try add(preset)
        return preset
    }

    /// Writes a shareable JSON copy to a temporary file and returns its URL.
    func exportURL(for preset: WorkPlotPreset) throws -> URL {
        let data = try preset.encodedJSON()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(preset.name.replacingOccurrences(of: "/", with: "-"))
            .appendingPathExtension("workplotpreset.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Applies every preset value into CacheExtra through the standard
    /// read-modify-write path; ExploitManager.saveGestalt creates a backup
    /// from the pre-write plist automatically.
    @discardableResult
    func apply(_ preset: WorkPlotPreset, manager: ExploitManager = .shared) -> Bool {
        guard var plist = manager.readGestalt() else { return false }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        for (key, value) in preset.values {
            cacheExtra[key] = value.plistValue
        }
        plist["CacheExtra"] = cacheExtra
        return manager.saveGestalt(plist)
    }

    private func fileName(for preset: WorkPlotPreset) -> String {
        let safeName = preset.name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        return "\(safeName).json"
    }
}
