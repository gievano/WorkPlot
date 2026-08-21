//
//  SiriAIModifier.swift
//  WorkPlot
//
//  Automates Step 1 of Toto's manual method (FilzaSlop + text editor):
//  serialize MobileGestalt to XML, replace the exact base64 line inside the
//  <data> blob of CacheData, then parse the XML back into a dictionary.
//

import Foundation

enum SiriAIModifier {
    static let originalBase64 = "AAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    static let patchedBase64 = "AAAAAAAAAAAAAAAAAAEAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

    enum State {
        case off, on, unknown
    }

    static func state(of plist: [String: Any]) -> State {
        guard let xml = xmlString(of: plist) else { return .unknown }
        if xml.contains(patchedBase64) { return .on }
        if xml.contains(originalBase64) { return .off }
        return .unknown
    }

    /// Replaces exactly one occurrence of the marker inside CacheData.
    /// - Throws: when the expected source marker is absent (already patched
    ///   with different values, or the device layout differs).
    static func setEnabled(_ enabled: Bool, in plist: inout [String: Any]) throws {
        guard var xml = xmlString(of: plist) else {
            throw PlistValueError.invalid("Gagal serialisasi MobileGestalt ke XML.")
        }

        let source = enabled ? originalBase64 : patchedBase64
        let target = enabled ? patchedBase64 : originalBase64

        guard let range = xml.range(of: source) else {
            if xml.contains(target) {
                return // Already in the requested state; nothing to do.
            }
            throw PlistValueError.invalid(
                "Marker CacheData tidak ditemukan. Perangkat mungkin sudah dimodifikasi dengan nilai lain."
            )
        }
        xml.replaceSubrange(range, with: target)

        guard let data = xml.data(using: .utf8),
              let parsed = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any] else {
            throw PlistValueError.invalid("XML hasil patch tidak dapat diparse kembali.")
        }
        plist = parsed
    }

    /// Newlines are stripped so Apple's 76-character base64 wrapping cannot
    /// split the marker across lines before matching.
    private static func xmlString(of plist: [String: Any]) -> String? {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0) else { return nil }
        return String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: "")
    }
}
