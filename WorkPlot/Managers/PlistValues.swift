import Foundation

enum PlistValueKind: String, CaseIterable, Identifiable {
    case string, integer, float, boolean, data, array, dictionary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .string: "String"
        case .integer: "Integer"
        case .float: "Float"
        case .boolean: "Boolean"
        case .data: "Data (Base64)"
        case .array: "Array (JSON)"
        case .dictionary: "Dictionary (JSON)"
        }
    }

    static func kind(of value: Any?) -> PlistValueKind {
        switch value {
        case is String:
            .string
        case let number as NSNumber:
            CFGetTypeID(number) == CFBooleanGetTypeID()
                ? .boolean
                : (CFNumberIsFloatType(number) ? .float : .integer)
        case is Data:
            .data
        case is NSArray:
            .array
        case is NSDictionary:
            .dictionary
        default:
            .string
        }
    }
}

struct PlistValueInfo {
    let kind: PlistValueKind
    let summary: String
    let searchText: String

    static func info(for value: Any?) -> PlistValueInfo {
        let kind = PlistValueKind.kind(of: value)
        let text = encode(value, as: kind)
        let summary: String

        switch kind {
        case .string:
            summary = text.isEmpty ? "(string kosong)" : text
        case .integer, .float, .boolean:
            summary = text
        case .data:
            summary = "Data (\((value as? Data)?.count ?? 0) bytes)"
        case .array:
            summary = "Array (\((value as? NSArray)?.count ?? 0) item)"
        case .dictionary:
            summary = "Dictionary (\((value as? NSDictionary)?.count ?? 0) item)"
        }

        return PlistValueInfo(kind: kind, summary: summary, searchText: text)
    }

    static func encode(_ value: Any?, as kind: PlistValueKind) -> String {
        switch kind {
        case .string:
            value as? String ?? ""
        case .integer, .float:
            (value as? NSNumber)?.stringValue ?? ""
        case .boolean:
            (value as? NSNumber)?.boolValue == true ? "true" : "false"
        case .data:
            (value as? Data)?.base64EncodedString() ?? ""
        case .array, .dictionary:
            jsonText(for: value)
        }
    }

    static func parse(_ text: String, as kind: PlistValueKind) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch kind {
        case .string:
            return text
        case .integer:
            guard let value = Int64(trimmed) else {
                throw PlistValueError.invalid("Bukan integer yang valid.")
            }
            return NSNumber(value: value)
        case .float:
            guard let value = Double(trimmed) else {
                throw PlistValueError.invalid("Bukan angka desimal yang valid.")
            }
            return NSNumber(value: value)
        case .boolean:
            switch trimmed.lowercased() {
            case "true", "1", "yes":
                return NSNumber(value: true)
            case "false", "0", "no":
                return NSNumber(value: false)
            default:
                throw PlistValueError.invalid("Isi true atau false.")
            }
        case .data:
            guard let data = Data(base64Encoded: trimmed) else {
                throw PlistValueError.invalid("Bukan Base64 yang valid.")
            }
            return data
        case .array:
            return try jsonObject(from: trimmed, expected: NSArray.self)
        case .dictionary:
            return try jsonObject(from: trimmed, expected: NSDictionary.self)
        }
    }

    private static func jsonText(for value: Any?) -> String {
        guard let value,
              JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys]) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func jsonObject<T>(from text: String, expected: T.Type) throws -> Any {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is T else {
            throw PlistValueError.invalid("JSON tidak valid untuk tipe \(String(describing: T.self)).")
        }
        return object
    }
}

enum PlistValueError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}
