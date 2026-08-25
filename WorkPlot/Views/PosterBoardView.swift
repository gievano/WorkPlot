import SwiftUI
import Foundation
import UIKit
import ObjectiveC
import UniformTypeIdentifiers

extension UIDocumentPickerViewController {
    @objc func workplot_init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) -> UIDocumentPickerViewController {
        workplot_init(forOpeningContentTypes: contentTypes, asCopy: true)
    }
}

struct PosterBoardView: View {
    @ObservedObject private var pbManager = PosterBoardManager.shared
    @AppStorage("pbHash") private var pbHash = ""
    @State private var showTendiesImporter = false
    @State private var showWallpaperGallery = false
    @State private var isBusy = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private let tendieType = UTType("com.leminlimez.tendies")
        ?? UTType(filenameExtension: "tendies", conformingTo: .data)!

    init() { Self.swizzleOnce }

    private static let swizzleOnce: Void = {
        let replacement = class_getInstanceMethod(
            UIDocumentPickerViewController.self,
            #selector(UIDocumentPickerViewController.workplot_init(forOpeningContentTypes:asCopy:))
        )!
        let original = class_getInstanceMethod(
            UIDocumentPickerViewController.self,
            #selector(UIDocumentPickerViewController.init(forOpeningContentTypes:asCopy:))
        )!
        method_exchangeImplementations(original, replacement)
    }()

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if BadQuery.isAvailable {
                        library
                    } else {
                        locked
                    }
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("Library")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if BadQuery.isAvailable {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showTendiesImporter = true } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            if isBusy { ProgressOverlay(message: "Installing collection") }
        }
        .fileImporter(isPresented: $showTendiesImporter, allowedContentTypes: [tendieType], allowsMultipleSelection: true, onCompletion: importTendies)
        .sheet(isPresented: $showWallpaperGallery) {
            NuggetWallpaperGalleryView()
        }
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if pbManager.selectedTendies.isEmpty {
                    emptyLibrary
                } else {
                    queue
                }
                libraryFooter
            }
            .padding(Theme.pagePadding)
            .padding(.bottom, pbManager.selectedTendies.isEmpty ? 24 : 108)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            if !pbManager.selectedTendies.isEmpty { installBar }
        }
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 42)
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text("Your wallpaper shelf is empty")
                    .font(.title2.weight(.semibold))
                Text("Add .tendies packs from Pocket Poster to create a custom PosterBoard library on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button { showTendiesImporter = true } label: {
                Label("Add tendies packs", systemImage: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .glassAction(prominent: true)
            .tint(Theme.accent)
        }
    }

    private var queue: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Install queue").font(.title2.weight(.semibold))
                    Text("\(pbManager.selectedTendies.count) pack\(pbManager.selectedTendies.count == 1 ? "" : "s") ready to install")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showTendiesImporter = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 0) {
                ForEach(Array(pbManager.selectedTendies.enumerated()), id: \.element) { index, tendie in
                    HStack(spacing: 14) {
                        Text(String(format: "%02d", index + 1))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tendie.deletingPathExtension().lastPathComponent)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text("TENDIES PACK")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .tracking(0.6)
                        }
                        Spacer()
                        Button(role: .destructive) { remove(tendie) } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 15)
                    if index < pbManager.selectedTendies.count - 1 { Divider().padding(.leading, 38) }
                }
            }
        }
    }

    private var libraryFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Button("Download Wallpapers", systemImage: "square.and.arrow.down") {
                showWallpaperGallery = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .padding(.top, 8)
    }

    private var installBar: some View {
        HStack(spacing: 12) {
            Button("Install \(pbManager.selectedTendies.count) pack\(pbManager.selectedTendies.count == 1 ? "" : "s")", systemImage: "arrow.down.to.line") {
                applyTendies()
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .glassAction(prominent: true)
            .tint(Theme.accent)
            .disabled(isBusy)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
    }

    private var locked: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "lock")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.secondary)
            Text("Library access unavailable")
                .font(.title2.weight(.semibold))
            Text("This iOS version cannot open PosterBoard's container through bad_query, so collections cannot be imported here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Theme.pagePadding)
    }

    private func importTendies(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard pbManager.selectedTendies.count < PosterBoardManager.MaxTendies else {
                    errorMessage = "You can only install \(PosterBoardManager.MaxTendies) tendies packs at once."
                    showErrorAlert = true
                    break
                }
                do {
                    pbManager.selectedTendies.append(try pbManager.importTendies(from: url))
                } catch {
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func remove(_ tendie: URL) {
        pbManager.selectedTendies.removeAll { $0 == tendie }
        try? FileManager.default.removeItem(at: tendie)
    }

    private func applyTendies() {
        guard !pbManager.selectedTendies.isEmpty, !isBusy else { return }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var hash = pbHash
                if hash.isEmpty {
                    hash = try BadQuery.findPosterBoardHash()
                    DispatchQueue.main.async { pbHash = hash }
                }
                try pbManager.applyTendies(appHash: hash)
                DispatchQueue.main.async {
                    pbManager.selectedTendies.removeAll()
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    RespringHelper.shared.trigger()
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}
