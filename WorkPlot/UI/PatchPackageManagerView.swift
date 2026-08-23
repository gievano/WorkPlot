//
//  PatchPackageManagerView.swift
//  WorkPlot
//
//  Lists imported patch packages and drives apply/rollback/delete through
//  PatchPackageStore. Apply and rollback are gated behind the exploit
//  sandbox grant, matching BackupRestoreManagerView.
//

import SwiftUI
import UniformTypeIdentifiers

struct PatchPackageManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var packages: [String] = []
    @State private var isShowingImporter = false
    @State private var passwordPrompt: PasswordPrompt?
    @State private var passwordInput = ""
    @State private var pendingDelete: String?
    @State private var alertTitle: String?
    @State private var alertMessage: String?

    struct PasswordPrompt: Identifiable {
        let id = UUID()
        let name: String
        let action: PackageAction
    }

    enum PackageAction {
        case apply, rollBack

        func perform(name: String, password: String?) throws {
            switch self {
            case .apply: try PatchPackageStore.apply(name: name, password: password)
            case .rollBack: try PatchPackageStore.rollBack(name: name, password: password)
            }
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if packages.isEmpty {
                    List {
                        Section {
                            Label(l10n.tr("pp.empty"), systemImage: "shippingbox")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        formatHelpSection
                        Section {
                            Button {
                                createSample()
                            } label: {
                                Label(l10n.tr("pp.createTemplate"), systemImage: "wand.and.stars")
                                    .font(.system(size: 15))
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(packages, id: \.self) { name in
                            packageSection(name)
                        }
                        formatHelpSection
                    }
                }
            }
            .navigationTitle(l10n.tr("pp.title"))
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label(l10n.tr("pp.import"), systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    importPackage(from: url)
                }
            }
            .confirmationDialog(
                l10n.tr("pp.deletePkg"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(l10n.tr("pp.deletePkg"), role: .destructive) {
                    if let name = pendingDelete { deletePackage(name) }
                    pendingDelete = nil
                }
                Button(l10n.tr("common.cancel"), role: .cancel) { pendingDelete = nil }
            } message: {
                Text(pendingDelete ?? "")
            }
            .alert(
                l10n.tr("pp.passwordPrompt"),
                isPresented: Binding(
                    get: { passwordPrompt != nil },
                    set: { if !$0 { passwordPrompt = nil } }
                ),
                presenting: passwordPrompt
            ) { prompt in
                SecureField(l10n.tr("pp.passwordPrompt"), text: $passwordInput)
                Button(l10n.tr("common.done")) {
                    run(prompt, password: passwordInput)
                }
                Button(l10n.tr("common.cancel"), role: .cancel) {}
            } message: { prompt in
                Text(prompt.name)
            }
            .alert(
                alertTitle ?? l10n.tr("common.error"),
                isPresented: Binding(
                    get: { alertTitle != nil },
                    set: { if !$0 { alertTitle = nil; alertMessage = nil } }
                ),
                presenting: alertMessage
            ) { _ in
                Button(l10n.tr("common.done"), role: .cancel) {}
            } message: { message in
                Text(message)
            }
            .onAppear(perform: refresh)
        }
    }

    @ViewBuilder
    private func packageSection(_ name: String) -> some View {
        Section(header: Text(sectionHeader(name))) {
            if let info = PatchPackageStore.loadInfo(name: name) {
                ForEach(info.rules, id: \.path) { rule in
                    Text(String(format: l10n.tr("pp.ruleFormat"), rule.bundleID, rule.path))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            HStack(spacing: 18) {
                Button {
                    request(.apply, name: name)
                } label: {
                    Label(l10n.tr("pp.apply"), systemImage: "checkmark.circle")
                        .font(.system(size: 15))
                }
                .buttonStyle(.borderless)
                .disabled(!manager.sandboxGranted)

                Button {
                    request(.rollBack, name: name)
                } label: {
                    Label(l10n.tr("pp.rollback"), systemImage: "arrow.uturn.backward")
                        .font(.system(size: 15))
                }
                .buttonStyle(.borderless)
                .disabled(!manager.sandboxGranted || !PatchPackageStore.hasOriginals(name: name))

                Spacer()

                Button(role: .destructive) {
                    pendingDelete = name
                } label: {
                    Label(l10n.tr("pp.deletePkg"), systemImage: "trash")
                        .font(.system(size: 15))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func sectionHeader(_ name: String) -> String {
        let rules = PatchPackageStore.loadInfo(name: name)?.rules.count ?? 0
        return "\(name) — \(String(format: l10n.tr("pp.rulesHeader"), rules))"
    }

    private var formatHelpSection: some View {
        Section(header: Text(l10n.tr("pp.help.header"))) {
            Text(l10n.tr("pp.help.body"))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func createSample() {
        do {
            _ = try PatchPackageStore.createSamplePackage()
            refresh()
            showError(title: l10n.tr("pp.templateOk"), message: nil)
        } catch {
            showError(title: l10n.tr("common.error"), message: error.localizedDescription)
        }
    }

    private func refresh() {
        packages = PatchPackageStore.listPackages()
    }

    private func importPackage(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try PatchPackageStore.importPackage(from: url)
            refresh()
        } catch {
            showError(title: l10n.tr("common.error"), message: error.localizedDescription)
        }
    }

    /// Password-protected packages prompt first; wrong passwords surface a
    /// dedicated alert instead of re-prompting.
    private func request(_ action: PackageAction, name: String) {
        if PatchPackageStore.requiresPassword(name: name) {
            passwordInput = ""
            passwordPrompt = PasswordPrompt(name: name, action: action)
        } else {
            run(PasswordPrompt(name: name, action: action), password: nil)
        }
    }

    private func run(_ prompt: PasswordPrompt, password: String?) {
        do {
            try prompt.action.perform(name: prompt.name, password: password)
            manager.statusText = prompt.action == .apply
                ? l10n.tr("pp.appliedOk")
                : l10n.tr("pp.rolledBackOk")
        } catch PatchPackageError.wrongPassword {
            showError(title: l10n.tr("pp.wrongPassword"), message: nil)
        } catch {
            showError(title: l10n.tr("common.error"), message: error.localizedDescription)
        }
        refresh()
    }

    private func deletePackage(_ name: String) {
        do {
            try PatchPackageStore.deletePackage(name: name)
            manager.statusText = l10n.tr("pp.deletedOk")
        } catch {
            showError(title: l10n.tr("common.error"), message: error.localizedDescription)
        }
        refresh()
    }

    private func showError(title: String, message: String?) {
        alertTitle = title
        alertMessage = message
    }
}
