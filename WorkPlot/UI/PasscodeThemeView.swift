//
//  PasscodeThemeView.swift
//  WorkPlot
//
//  UI for PasscodeThemeManager (ported from Nouvborne/Ketamine, GPL-3.0).
//  Applies .zip / .passthm dialer + passcode keypad themes to the Phone
//  app's TelephonyUI cache, with one-time backup and restore.
//

import SwiftUI
import UniformTypeIdentifiers

struct PasscodeThemeView: View {
    @State private var isImporterPresented = false
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var isSharePresented = false

    var body: some View {
        List {
            Section {
                Label {
                    Text("Dialer & passcode keypad themes")
                } icon: {
                    Image(systemName: "keypad")
                }
                Text("Applies a .zip / .passthm package of PNGs to the Phone app's dialer cache. The original files are backed up once before the first apply, so you can always restore.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Theme") {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Apply Theme…", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)

                Button {
                    run { try restore() }
                } label: {
                    Label("Restore Original", systemImage: "arrow.uturn.backward")
                }
                .disabled(isWorking || !PasscodeThemeManager.shared.hasBackup)

                Button {
                    run { try extract() }
                } label: {
                    Label("Extract Current Theme", systemImage: "square.and.arrow.up")
                }
                .disabled(isWorking)
            }

            if isWorking {
                Section {
                    HStack {
                        ProgressView()
                        Text("Working…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Passcode Themes")
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                run { try apply(packageURL: url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $isSharePresented) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
    }

    private func run(_ work: @escaping () throws -> String?) {
        isWorking = true
        statusMessage = nil
        errorMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result: Result<String?, Error>
            do {
                result = .success(try work())
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                isWorking = false
                switch result {
                case .success(let message):
                    statusMessage = message ?? "Done."
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func phoneHash() throws -> String {
        try PasscodeThemeManager.resolvePhoneAppHash()
    }

    private func apply(packageURL: URL) throws -> String? {
        let hash = try phoneHash()
        let replaced = try PasscodeThemeManager.shared.applyTheme(from: packageURL, appHash: hash)
        return "Applied — \(replaced) images replaced. Respring to see it."
    }

    private func restore() throws -> String? {
        let hash = try phoneHash()
        try PasscodeThemeManager.shared.restoreOriginal(appHash: hash)
        return "Original theme restored. Respring to see it."
    }

    private func extract() throws -> String? {
        let hash = try phoneHash()
        let url = try PasscodeThemeManager.shared.extractImages(appHash: hash)
        DispatchQueue.main.async {
            exportURL = url
            isSharePresented = true
        }
        return "Theme exported — share sheet opened."
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
