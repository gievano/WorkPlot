//
//  FileHexViewerSheet.swift
//  WorkPlot
//
//  Read-only hex dump of the first 4 KB of a file, with an ASCII gutter
//  and copy-to-pasteboard support. Data flows through FileBrowser.readData
//  so the bad_query lease is acquired for the duration of the read.
//

import SwiftUI

struct FileHexViewerSheet: View {
    let entry: FileEntry

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    /// ponytail: fixed 4 KB window, no paging; add offset-based reads if someone needs more
    private let byteLimit = 4096

    @State private var rows: [HexRow]?
    @State private var totalSize: Int64?
    @State private var loadError: String?
    @State private var copied = false

    struct HexRow: Identifiable {
        let offset: Int
        let hex: String
        let ascii: String
        var id: Int { offset }
    }

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    ContentUnavailableCompatView(
                        icon: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if let rows, let totalSize {
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            Text(headerText(totalSize: totalSize, rowCount: rows.count))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                            ForEach(rows) { row in
                                HStack(spacing: 10) {
                                    Text(String(format: "%08X", row.offset))
                                        .foregroundStyle(.secondary)
                                    Text(row.hex)
                                    Text(row.ascii)
                                        .foregroundStyle(row.ascii.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                                }
                                .font(.system(size: 11, design: .monospaced))
                            }
                        }
                        .padding()
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(L10n.shared.tr("hex.title"))
            .navigationBarTitleDisplayMode(.inline)
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        copyDump()
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(rows == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.shared.tr("common.done")) { dismiss() }
                }
            }
        }
        .task { load() }
    }

    // English literal: no l10n key exists for this note and none may be added.
    private func headerText(totalSize: Int64, rowCount: Int) -> String {
        let size = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return rowCount == 0
            ? size
            : "\(size) \u{2022} first \(byteLimit / 1024) KB"
    }

    private func dumpText() -> String {
        guard let rows else { return "" }
        return rows.map { row in
            String(format: "%08X  %@  %@", row.offset, row.hex, row.ascii)
        }
        .joined(separator: "\n")
    }

    private func copyDump() {
        UIPasteboard.general.string = dumpText()
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fullData = try FileBrowser.readData(at: path)
                let window = fullData.prefix(byteLimit)
                let bytes = [UInt8](window)

                var built: [HexRow] = []
                var index = 0
                while index < bytes.count {
                    let chunk = bytes[index..<min(index + 16, bytes.count)]
                    let hex = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
                    let ascii = chunk.map { byte -> String in
                        (0x20...0x7E).contains(byte) ? String(UnicodeScalar(byte)) : "."
                    }.joined()
                    built.append(HexRow(offset: index, hex: hex.padding(toLength: 47, withPad: " ", startingAt: 0), ascii: ascii))
                    index += 16
                }

                DispatchQueue.main.async {
                    self.rows = built
                    self.totalSize = Int64(fullData.count)
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadError = error.localizedDescription
                }
            }
        }
    }
}
