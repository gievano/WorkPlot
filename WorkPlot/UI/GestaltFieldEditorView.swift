import SwiftUI

struct GestaltFieldEditorView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var plist: [String: Any]?
    @State private var searchText = ""
    @State private var isShowingAddSheet = false

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text("Akses sistem belum aktif.\nBuka tab Status dan tekan \"Periksa Akses Sistem\".")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else if let plist {
                    keyList(plist)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
                        Text("Gagal membaca MobileGestalt.")
                        Button("Coba Lagi") { load() }
                    }
                }
            }
            .navigationTitle("Fields")
            .scrollContentBackground(.hidden)
            .searchable(text: $searchText, prompt: "Cari key atau value")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!manager.sandboxGranted)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Respring") { manager.respringRequested = true }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddCacheExtraFieldView { key, kind, text in
                    addCacheExtraField(key: key, kind: kind, valueText: text)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func keyList(_ plist: [String: Any]) -> some View {
        List {
            cacheSection(plist)

            let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
            let cacheKeys = filtered(cacheExtra.keys.sorted())
            if !cacheKeys.isEmpty {
                Section(header: Text("CacheExtra")) {
                    ForEach(cacheKeys, id: \.self) { key in
                        NavigationLink {
                            ValueEditor(
                                title: key,
                                kind: PlistValueKind.kind(of: cacheExtra[key]),
                                initialText: PlistValueInfo.info(for: cacheExtra[key]).searchText
                            ) { newText in
                                updateCacheExtra(key: key, valueText: newText)
                            }
                        } label: {
                            KeyRow(key: key, info: info(for: cacheExtra[key]))
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets where index < cacheKeys.count {
                            deleteCacheExtraField(cacheKeys[index])
                        }
                    }
                }
            }

            let topLevelKeys = filtered(plist.keys.sorted())
            if !topLevelKeys.isEmpty {
                Section(header: Text("Top Level")) {
                    ForEach(topLevelKeys, id: \.self) { key in
                        NavigationLink {
                            ValueEditor(
                                title: key,
                                kind: PlistValueKind.kind(of: plist[key]),
                                initialText: PlistValueInfo.info(for: plist[key]).searchText
                            ) { newText in
                                updateTopLevel(key: key, valueText: newText)
                            }
                        } label: {
                            KeyRow(key: key, info: info(for: plist[key]))
                        }
                    }
                }
            }

            if cacheKeys.isEmpty && topLevelKeys.isEmpty {
                Section {
                    Text("Tidak ada key yang cocok dengan \"\(searchText)\".")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func cacheSection(_ plist: [String: Any]) -> some View {
        Section(header: Text("Cache")) {
            HStack {
                Text("CacheUUID").font(.callout)
                Spacer()
                Text(plist["CacheUUID"] as? String ?? "—")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            HStack {
                Text("CacheVersion").font(.callout)
                Spacer()
                Text(valueSummary(plist["CacheVersion"]))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            NavigationLink {
                CacheDataView(plist: plist)
            } label: {
                HStack {
                    Text("CacheData").font(.callout)
                    Spacer()
                    if let data = plist["CacheData"] as? Data {
                        Text("\(data.count) bytes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("—").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func valueSummary(_ value: Any?) -> String {
        PlistValueInfo.info(for: value).summary
    }

    private func filtered(_ keys: [String]) -> [String] {
        guard !searchText.isEmpty else { return keys }
        return keys.filter { key in
            key.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func info(for value: Any?) -> PlistValueInfo {
        PlistValueInfo.info(for: value)
    }

    private func load() {
        guard plist == nil else { return }
        plist = manager.readGestalt()
    }

    private func persist() -> Bool {
        guard let plist else { return false }
        return manager.saveGestalt(plist)
    }

    private func updateCacheExtra(key: String, valueText: String) {
        guard var plist else { return }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        let kind = PlistValueKind.kind(of: cacheExtra[key])
        do {
            cacheExtra[key] = try PlistValueInfo.parse(valueText, as: kind)
            plist["CacheExtra"] = cacheExtra
            self.plist = plist
            manager.statusText = persist()
                ? "\(key) diperbarui."
                : "Gagal menyimpan \(key)."
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
        }
    }

    private func updateTopLevel(key: String, valueText: String) {
        guard var plist else { return }
        let kind = PlistValueKind.kind(of: plist[key])
        do {
            plist[key] = try PlistValueInfo.parse(valueText, as: kind)
            self.plist = plist
            manager.statusText = persist()
                ? "\(key) diperbarui."
                : "Gagal menyimpan \(key)."
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
        }
    }

    private func addCacheExtraField(key: String, kind: PlistValueKind, valueText: String) {
        guard var plist else { return }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        do {
            cacheExtra[key] = try PlistValueInfo.parse(valueText, as: kind)
            plist["CacheExtra"] = cacheExtra
            self.plist = plist
            manager.statusText = persist()
                ? "Field \(key) ditambahkan."
                : "Gagal menyimpan \(key)."
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
        }
    }

    private func deleteCacheExtraField(_ key: String) {
        guard var plist else { return }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        cacheExtra.removeValue(forKey: key)
        plist["CacheExtra"] = cacheExtra
        self.plist = plist
        manager.statusText = persist() ? "\(key) dihapus." : "Gagal menghapus \(key)."
    }
}

private struct CacheDataView: View {
    let plist: [String: Any]

    private var cacheData: Data? { plist["CacheData"] as? Data }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if let data = cacheData {
                    Text("Hex (512 byte pertama)")
                        .font(.headline)
                    Text(Self.hexDump(data, limit: 512))
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)

                    Text("Base64 (lengkap)")
                        .font(.headline)
                    Text(data.base64EncodedString())
                        .font(.system(size: 9, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("CacheData tidak ada di plist ini.")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("CacheData")
        .navigationBarTitleDisplayMode(.inline)
    }

    private static func hexDump(_ data: Data, limit: Int) -> String {
        let bytes = data.prefix(limit)
        var lines: [String] = []
        for offset in stride(from: 0, to: bytes.count, by: 16) {
            let chunk = bytes.dropFirst(offset).prefix(16)
            let hex = chunk.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = chunk.map { (32...126).contains($0) ? String(UnicodeScalar($0)) : "." }.joined()
            let paddedHex = hex.padding(toLength: 47, withPad: " ", startingAt: 0)
            lines.append(String(format: "%08x", offset) + "  " + paddedHex + "  " + ascii)
        }
        if data.count > limit {
            lines.append("... (+\(data.count - limit) byte lagi, lihat Base64)")
        }
        return lines.joined(separator: "\n")
    }
}

private struct KeyRow: View {
    let key: String
    let info: PlistValueInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.callout)
            HStack(spacing: 4) {
                Text(info.kind.label)
                    .font(.caption2).bold()
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(4)
                Text(info.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ValueEditor: View {
    let title: String
    let kind: PlistValueKind
    let initialText: String
    let onCommit: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(title: String, kind: PlistValueKind, initialText: String, onCommit: @escaping (String) -> Void) {
        self.title = title
        self.kind = kind
        self.initialText = initialText
        self.onCommit = onCommit
        _text = State(initialValue: initialText)
    }

    var body: some View {
        Form {
            Section(header: Text("Tipe")) {
                Text(kind.label).foregroundColor(.blue)
            }
            Section(header: Text("Nilai")) {
                if kind == .array || kind == .dictionary || kind == .data {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 160)
                } else {
                    TextField("Nilai", text: $text)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            Button("Simpan") {
                onCommit(text)
                dismiss()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AddCacheExtraFieldView: View {
    let onSave: (String, PlistValueKind, String) -> Void

    @State private var key = ""
    @State private var kind: PlistValueKind = .string
    @State private var valueText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Key Baru (CacheExtra)")) {
                    TextField("Key", text: $key)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section(header: Text("Tipe")) {
                    Picker("Tipe", selection: $kind) {
                        ForEach(PlistValueKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                }
                Section(header: Text("Nilai")) {
                    TextField("Nilai", text: $valueText)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Tambah Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tambah") {
                        onSave(key, kind, valueText)
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
