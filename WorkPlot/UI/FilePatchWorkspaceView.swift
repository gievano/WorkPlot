//
//  FilePatchWorkspaceView.swift
//  WorkPlot
//
//  Filza-style file browser over the bad_query sandbox escape. Directory
//  listing runs through FileBrowser (short-lived leases); every destructive
//  operation requires a confirmation alert naming the target.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Main browser

private enum NewFileItemKind: String, Identifiable, Equatable {
    case file, folder
    var id: String { rawValue }
}

private struct PendingFileTransfer {
    let entry: FileEntry
    let movesSource: Bool
}

private struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

struct FilePatchWorkspaceView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    // nil = shortcut screen, otherwise an absolute directory path.
    @State private var currentPath: String?
    @State private var entries: [FileEntry] = []
    @State private var isLoading = false
    /// Shortcuts that passed the live reachability probe on this device.
    @State private var shortcuts: [FileQuickLocation]?
    /// Shown after a fresh probe writes Documents/ACCESS MAP.txt.
    @State private var showAccessMapNote = false

    @State private var selectedEntry: FileEntry?
    @State private var hexViewerEntry: FileEntry?
    @State private var pendingDelete: FileEntry?
    @State private var renameEntry: FileEntry?
    @State private var renameText = ""
    @State private var newItemKind: NewFileItemKind?
    @State private var newItemName = ""
    @State private var pendingTransfer: PendingFileTransfer?
    @State private var showingImporter = false
    @State private var exportedFile: ExportedFile?
    @State private var exportDirectory: URL?
    @State private var searchText = ""

    @State private var errorText: String?
    @State private var successText: String?
    @State private var osSupported = true
    @State private var osBuild = ""

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    lockedState
                } else if let path = currentPath {
                    directoryList(path)
                } else {
                    shortcutList
                }
            }
            .workPlotScrollBackground()
            .navigationTitle(l10n.tr("tab.files"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if currentPath != nil {
                    ToolbarItem(placement: .navigationBarLeading) { upButton }
                    ToolbarItem(placement: .navigationBarTrailing) { fileActionsMenu }
                }
            }
        }
        .onAppear(perform: refreshOSCheck)
        .sheet(item: $selectedEntry) { entry in
            viewer(for: entry)
        }
        .sheet(item: $hexViewerEntry) { entry in
            FileHexViewerSheet(entry: entry)
        }
        .sheet(item: $exportedFile, onDismiss: removeExportedFile) { file in
            ActivityShareSheet(items: [file.url])
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.patch3105],
            allowsMultipleSelection: false,
            onCompletion: performImport
        )
        .alert(
            Text(l10n.tr("fp.delete.title")),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { _ in
            Button(l10n.tr("fp.action.delete"), role: .destructive, action: performDelete)
            Button(l10n.tr("common.cancel"), role: .cancel) { pendingDelete = nil }
        } message: { entry in
            Text(String(format: l10n.tr("fp.delete.message"), entry.name))
        }
        .alert(
            l10n.tr("fp.rename.title"),
            isPresented: Binding(
                get: { renameEntry != nil },
                set: { if !$0 { renameEntry = nil } }
            ),
            presenting: renameEntry
        ) { _ in
            TextField(l10n.tr("fp.rename.placeholder"), text: $renameText)
            Button(l10n.tr("fp.action.save"), action: performRename)
            Button(l10n.tr("common.cancel"), role: .cancel) { renameEntry = nil }
        } message: { entry in
            Text(String(format: l10n.tr("fp.rename.message"), entry.name))
        }
        .alert(
            newItemKind == .folder ? l10n.tr("fp.create.folder.title") : l10n.tr("fp.create.file.title"),
            isPresented: Binding(
                get: { newItemKind != nil },
                set: { if !$0 { newItemKind = nil } }
            )
        ) {
            TextField(l10n.tr("fp.create.placeholder"), text: $newItemName)
            Button(l10n.tr("fp.action.create"), action: performCreate)
            Button(l10n.tr("common.cancel"), role: .cancel) { newItemKind = nil }
        }
        .alert(
            l10n.tr("common.error"),
            isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )
        ) {
            Button(l10n.tr("common.done"), role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .alert(
            l10n.tr("fp.success.title"),
            isPresented: Binding(
                get: { successText != nil },
                set: { if !$0 { successText = nil } }
            )
        ) {
            Button(l10n.tr("common.done"), role: .cancel) {}
        } message: {
            Text(successText ?? "")
        }
    }

    // MARK: Subviews

    private var lockedState: some View {
        List {
            dangerSection
            Section {
                Label(l10n.tr("filepatch.needaccess"), systemImage: "lock")
                    .font(.system(size: 15))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var shortcutList: some View {
        List {
            dangerSection
            statusSection
            if !osSupported {
                osWarningSection
            }

            Section(header: Text(l10n.tr("fp.shortcut.header"))) {
                if let shortcuts {
                    if shortcuts.isEmpty {
                        Label(l10n.tr("ac.empty"), systemImage: "folder.badge.questionmark")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(shortcuts) { shortcut in
                        Button {
                            navigate(to: shortcut.path)
                        } label: {
                            HStack {
                                Label(l10n.tr(shortcut.labelKey), systemImage: "folder.badge.gearshape")
                                    .font(.system(size: 15))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(l10n.tr("fp.scanning")).font(.system(size: 15))
                    }
                }
                NavigationLink { AppContainersView() } label: {
                    Label(l10n.tr("ac.title"), systemImage: "shippingbox")
                        .font(.system(size: 15))
                }
                if showAccessMapNote {
                    Label(l10n.tr("fp.accessmap.note"), systemImage: "map")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func directoryList(_ path: String) -> some View {
        let visibleEntries = searchText.isEmpty
            ? entries
            : entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return List {
            dangerSection

            Section {
                breadcrumbBar(path)
            }

            if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(l10n.tr("fp.loading")).font(.system(size: 15))
                    }
                }
            } else if visibleEntries.isEmpty {
                Section {
                    Label(l10n.tr("fp.empty"), systemImage: "folder")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(visibleEntries) { entry in
                        row(for: entry)
                    }
                }
            }
        }
        .refreshable { reload() }
        .searchable(text: $searchText, prompt: l10n.tr("fp.search.prompt"))
    }

    private var dangerSection: some View {
        Section(header: Text(l10n.tr("danger.header"))) {
            Label(l10n.tr("danger.filepatch.message"), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 15, weight: .medium))
        }
    }

    private var statusSection: some View {
        Section {
            Label(
                manager.sandboxGranted ? l10n.tr("filepatch.ready") : l10n.tr("filepatch.needaccess"),
                systemImage: manager.sandboxGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
            )
            .font(.system(size: 15))
            .foregroundStyle(manager.sandboxGranted ? Color.green : Color.orange)
        }
    }

    private var osWarningSection: some View {
        Section {
            Label(
                String(format: l10n.tr("fp.oswarning"), osBuild.isEmpty ? "?" : osBuild),
                systemImage: "exclamationmark.octagon.fill"
            )
            .foregroundStyle(.orange)
            .font(.system(size: 15, weight: .medium))
        }
    }

    private func breadcrumbBar(_ path: String) -> some View {
        let crumbs = crumbs(for: path)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(crumbs.enumerated()), id: \.offset) { _, crumb in
                    Button(crumb.label) {
                        navigate(to: crumb.path)
                    }
                    .font(.system(size: 13, weight: crumb.path == path ? .semibold : .regular))
                    .buttonStyle(.plain)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var upButton: some View {
        Button {
            guard let currentPath else { return }
            if currentPath == "/" {
                self.currentPath = nil
                entries = []
            } else {
                navigate(to: FileBrowser.parentPath(of: currentPath))
            }
        } label: {
            Image(systemName: "chevron.up")
        }
        .disabled(isLoading)
    }

    private var fileActionsMenu: some View {
        Menu {
            Button {
                newItemName = ""
                newItemKind = .file
            } label: {
                Label(l10n.tr("fp.action.newFile"), systemImage: "doc.badge.plus")
            }
            Button {
                newItemName = ""
                newItemKind = .folder
            } label: {
                Label(l10n.tr("fp.action.newFolder"), systemImage: "folder.badge.plus")
            }
            Button {
                showingImporter = true
            } label: {
                Label(l10n.tr("fp.action.import"), systemImage: "square.and.arrow.down")
            }
            if let pendingTransfer {
                Button {
                    performPaste(pendingTransfer)
                } label: {
                    Label(
                        String(format: l10n.tr("fp.action.paste"), pendingTransfer.entry.name),
                        systemImage: "doc.on.clipboard"
                    )
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .disabled(isLoading || !osSupported)
    }

    private func row(for entry: FileEntry) -> some View {
        Button {
            if entry.isDirectory {
                navigate(to: entry.path)
            } else {
                selectedEntry = entry
            }
        } label: {
            FileBrowserRowView(entry: entry)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !entry.isDirectory && (entry.kind == .text || entry.kind == .plist) {
                Button {
                    selectedEntry = entry
                } label: {
                    Label(l10n.tr("fp.action.view"), systemImage: "eye")
                }
            }
            if !entry.isDirectory {
                Button {
                    hexViewerEntry = entry
                } label: {
                    Label(l10n.tr("fp.action.hexView"), systemImage: "number.square")
                }
            }
            Button {
                renameText = entry.name
                renameEntry = entry
            } label: {
                Label(l10n.tr("fp.action.rename"), systemImage: "pencil")
            }
            Button {
                pendingTransfer = PendingFileTransfer(entry: entry, movesSource: false)
            } label: {
                Label(l10n.tr("fp.action.copy"), systemImage: "doc.on.doc")
            }
            Button {
                pendingTransfer = PendingFileTransfer(entry: entry, movesSource: true)
            } label: {
                Label(l10n.tr("fp.action.move"), systemImage: "folder")
            }
            Button {
                performExport(entry)
            } label: {
                Label(l10n.tr("fp.action.share"), systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                pendingDelete = entry
            } label: {
                Label(l10n.tr("fp.action.delete"), systemImage: "trash")
            }
        }
    }

    // MARK: Sheets

    @ViewBuilder
    private func viewer(for entry: FileEntry) -> some View {
        switch entry.kind {
        case .text:
            FileTextEditSheet(entry: entry, onSaved: handleSaveSuccess)
        case .plist:
            FilePlistViewerSheet(entry: entry)
        case .image:
            FileImagePreviewSheet(entry: entry)
        case .binary:
            if Self.sqliteExtensions.contains(where: { entry.name.lowercased().hasSuffix($0) }) {
                FileSqliteViewerSheet(entry: entry)
            } else {
                FileHexViewerSheet(entry: entry)
            }
        case .directory:
            FileBinaryInfoSheet(entry: entry)
        }
    }

    private static let sqliteExtensions = [".db", ".sqlite", ".sqlite3", ".sqlitedb"]

    // MARK: State helpers

    private func refreshOSCheck() {
        #if !targetEnvironment(simulator)
        osBuild = GestaltAccess.currentOSBuild()
        osSupported = GestaltAccess.isRunningSupportedOS()
        #else
        osSupported = false
        osBuild = "simulator"
        #endif

        guard shortcuts == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let probed = FileBrowser.reachableShortcuts()
            let wroteMap = FileBrowser.lastProbeWroteAccessMap
            DispatchQueue.main.async {
                shortcuts = probed
                showAccessMapNote = wroteMap
            }
        }
    }

    private func crumbs(for path: String) -> [(label: String, path: String)] {
        var result = [(label: "/", path: "/")]
        var accumulated = ""
        for component in path.split(separator: "/") {
            accumulated += "/" + component
            result.append((label: String(component), path: accumulated))
        }
        return result
    }

    private func navigate(to rawPath: String) {
        let target = FileBrowser.normalize(rawPath)
        // Root has no meaningful listing (bad_query_list would scan every
        // inode on the data partition), so it doubles as "back to shortcuts".
        if target == "/" {
            currentPath = nil
            entries = []
            isLoading = false
            return
        }
        isLoading = true
        searchText = ""

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try FileBrowser.listDirectory(target)
                DispatchQueue.main.async {
                    self.currentPath = target
                    self.entries = result
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    /// Reloads the visible directory in place after a mutation.
    private func reload() {
        guard let currentPath else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = try? FileBrowser.listDirectory(currentPath)
            DispatchQueue.main.async {
                if let result {
                    self.entries = result
                }
                self.isLoading = false
            }
        }
    }

    private func performDelete() {
        guard let entry = pendingDelete else { return }
        pendingDelete = nil
        let isDirectory = entry.isDirectory
        let path = entry.path

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileBrowser.deleteItem(at: path, isDirectory: isDirectory)
                DispatchQueue.main.async {
                    self.successText = String(format: L10n.shared.tr("fp.delete.success"), entry.name)
                    self.reload()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func performRename() {
        guard let entry = renameEntry else { return }
        let newName = renameText
        renameEntry = nil
        let path = entry.path

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileBrowser.renameItem(at: path, to: newName)
                DispatchQueue.main.async {
                    self.successText = String(format: L10n.shared.tr("fp.rename.success"), newName)
                    self.reload()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorText = error.localizedDescription
                }
            }
        }
    }

    private func performCreate() {
        guard let kind = newItemKind, let currentPath else { return }
        let name = newItemName
        newItemKind = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if kind == .folder {
                    try FileBrowser.createDirectory(named: name, in: currentPath)
                } else {
                    try FileBrowser.createFile(named: name, in: currentPath)
                }
                DispatchQueue.main.async {
                    self.successText = String(format: L10n.shared.tr("fp.create.success"), name)
                    self.reload()
                }
            } catch {
                DispatchQueue.main.async { self.errorText = error.localizedDescription }
            }
        }
    }

    private func performPaste(_ transfer: PendingFileTransfer) {
        guard let currentPath else { return }
        pendingTransfer = nil
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if transfer.movesSource {
                    try FileBrowser.moveItem(at: transfer.entry.path, to: currentPath)
                } else {
                    try FileBrowser.copyItem(at: transfer.entry.path, to: currentPath)
                }
                DispatchQueue.main.async {
                    self.successText = String(
                        format: L10n.shared.tr("fp.transfer.success"),
                        transfer.entry.name
                    )
                    self.reload()
                }
            } catch {
                DispatchQueue.main.async { self.errorText = error.localizedDescription }
            }
        }
    }

    private func performImport(_ result: Result<[URL], Error>) {
        guard let currentPath else { return }
        do {
            guard let sourceURL = try result.get().first else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                let scoped = sourceURL.startAccessingSecurityScopedResource()
                defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }
                do {
                    try FileBrowser.importItem(from: sourceURL, to: currentPath)
                    DispatchQueue.main.async {
                        self.successText = String(
                            format: L10n.shared.tr("fp.import.success"),
                            sourceURL.lastPathComponent
                        )
                        self.reload()
                    }
                } catch {
                    DispatchQueue.main.async { self.errorText = error.localizedDescription }
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func performExport(_ entry: FileEntry) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try FileBrowser.exportItem(at: entry.path)
                DispatchQueue.main.async {
                    self.exportDirectory = url.deletingLastPathComponent()
                    self.exportedFile = ExportedFile(url: url)
                }
            } catch {
                DispatchQueue.main.async { self.errorText = error.localizedDescription }
            }
        }
    }

    private func removeExportedFile() {
        guard let exportDirectory else { return }
        try? FileManager.default.removeItem(at: exportDirectory)
        self.exportDirectory = nil
        exportedFile = nil
    }

    private func handleSaveSuccess(fileName: String) {
        successText = String(format: l10n.tr("fp.save.success"), fileName)
        reload()
    }
}

// MARK: - Row

struct FileBrowserRowView: View {
    let entry: FileEntry

    private var iconName: String {
        switch entry.kind {
        case .directory: "folder.fill"
        case .plist: "doc.badge.gearshape"
        case .text: "doc.plaintext"
        case .image: "photo"
        case .binary: "shippingbox"
        }
    }

    private var iconColor: Color {
        switch entry.kind {
        case .directory: .blue
        case .plist: .purple
        case .text: .primary
        case .image: .green
        case .binary: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .frame(width: 26)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if entry.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        if entry.isDirectory { return "" }
        var parts: [String] = []
        if entry.size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
        }
        if let date = entry.modificationDate {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Text editor sheet

struct FileTextEditSheet: View {
    let entry: FileEntry
    var onSaved: (String) -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var originalText = ""
    @State private var editedText = ""
    @State private var isLoaded = false
    @State private var loadError: String?
    @State private var showSaveConfirm = false
    @State private var isSaving = false
    @State private var saveError: String?

    private var hasChanges: Bool { editedText != originalText }

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    ContentUnavailableCompatView(
                        icon: "exclamationmark.triangle",
                        message: loadError
                    )
                } else if !isLoaded {
                    ProgressView()
                } else {
                    TextEditor(text: $editedText)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.tr("common.cancel")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(l10n.tr("fp.action.save")) {
                            showSaveConfirm = true
                        }
                        .disabled(!isLoaded || !hasChanges)
                    }
                }
            }
            .alert(
                l10n.tr("fp.save.confirm.title"),
                isPresented: $showSaveConfirm
            ) {
                Button(l10n.tr("fp.action.save"), action: save)
                Button(l10n.tr("common.cancel"), role: .cancel) {}
            } message: {
                Text(String(format: l10n.tr("fp.save.confirm.message"), entry.name))
            }
            .alert(
                l10n.tr("common.error"),
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button(l10n.tr("common.done"), role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .task { load() }
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let text = try FileBrowser.readText(at: path)
                DispatchQueue.main.async {
                    self.originalText = text
                    self.editedText = text
                    self.isLoaded = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.loadError = error.localizedDescription
                }
            }
        }
    }

    /// Staged-apply: temp write + verify + inode-preserving rewrite happen
    /// inside FileBrowser.saveText; this only drives the UI state machine.
    private func save() {
        isSaving = true
        let newText = editedText
        let path = entry.path

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileBrowser.saveText(newText, to: path)
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.dismiss()
                    self.onSaved(entry.name)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Plist viewer sheet

struct FilePlistViewerSheet: View {
    let entry: FileEntry

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var prettyXML: String?
    @State private var loadError: String?

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    ContentUnavailableCompatView(icon: "exclamationmark.triangle", message: loadError)
                } else if let prettyXML {
                    ScrollView {
                        Text(prettyXML)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.tr("common.done")) { dismiss() }
                }
            }
        }
        .task { load() }
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let plist = try FileBrowser.readPlist(at: path)
                let data = try PropertyListSerialization.data(
                    fromPropertyList: plist,
                    format: .xml,
                    options: 0
                )
                let xml = String(data: data, encoding: .utf8) ?? "<data>"
                DispatchQueue.main.async { self.prettyXML = xml }
            } catch {
                DispatchQueue.main.async { self.loadError = error.localizedDescription }
            }
        }
    }
}

// MARK: - Image preview sheet

struct FileImagePreviewSheet: View {
    let entry: FileEntry

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var loadError: String?

    var body: some View {
        NavigationView {
            Group {
                if let loadError {
                    ContentUnavailableCompatView(icon: "photo.badge.exclamationmark", message: loadError)
                } else if let image {
                    GeometryReader { proxy in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.tr("common.done")) { dismiss() }
                }
            }
        }
        .task { load() }
    }

    private func load() {
        let path = entry.path
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data = try FileBrowser.readData(at: path)
                let loaded = UIImage(data: data)
                DispatchQueue.main.async {
                    if let loaded {
                        self.image = loaded
                    } else {
                        self.loadError = L10n.shared.tr("fp.error.imagedecode")
                    }
                }
            } catch {
                DispatchQueue.main.async { self.loadError = error.localizedDescription }
            }
        }
    }
}

// MARK: - Binary info sheet

struct FileBinaryInfoSheet: View {
    let entry: FileEntry

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    LabeledRow(label: l10n.tr("fp.info.name"), value: entry.name)
                    LabeledRow(
                        label: l10n.tr("fp.info.size"),
                        value: ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
                    )
                    LabeledRow(label: l10n.tr("fp.info.path"), value: entry.path)
                }
                Section {
                    Label(l10n.tr("fp.binary.nopreview"), systemImage: "shippingbox")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.tr("common.done")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Small shared pieces

/// Minimal stand-in for ContentUnavailableView so the browser keeps a single
/// visual language across iOS versions used during development betas.
struct ContentUnavailableCompatView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
