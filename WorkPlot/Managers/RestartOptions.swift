//
//  RestartOptions.swift
//  WorkPlot
//
//  Restart escalation for heavy tweaks (model spoofing, Siri AI mode,
//  Color Palette). Respring runs through the proven NeoSpring WebKit
//  crash method; userspace and full restart CANNOT be executed from this
//  app because the bad_query exploit is file read/write only - it cannot
//  spawn processes, so `launchctl reboot userspace|system` is unreachable.
//  The second button therefore opens an honest combined guide instead of
//  pretending to restart.
//

import SwiftUI

/// Non-dismissible restart prompt shared by every heavy-tweak apply flow.
/// Deliberately an `.alert` instead of a confirmationDialog: iOS alerts are
/// modal and cannot be dismissed by tapping outside. Two honest buttons:
/// Respring executes immediately; Restart Steps opens the manual guide
/// (the sandbox cannot reboot the device itself).
struct HeavyRestartFlow: ViewModifier {
    @ObservedObject var manager = ExploitManager.shared
    @Binding var isPresented: Bool
    @State private var showGuide = false

    func body(content: Content) -> some View {
        content
            .alert(
                L10n.shared.tr("restart.required.title"),
                isPresented: $isPresented
            ) {
                Button(L10n.shared.tr("siriai.restart.respring")) {
                    manager.requestRespring()
                }
                Button(L10n.shared.tr("restart.action.guide")) {
                    showGuide = true
                }
            } message: {
                Text(L10n.shared.tr("restart.options.message"))
            }
            .sheet(isPresented: $showGuide) {
                RestartGuideSheet()
            }
    }
}

extension View {
    func heavyRestartFlow(isPresented: Binding<Bool>) -> some View {
        modifier(HeavyRestartFlow(isPresented: isPresented))
    }
}

struct RestartGuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.shared.tr("restart.limit.title"), systemImage: "exclamationmark.shield")
                        .font(.headline)
                    Text(L10n.shared.tr("restart.limit.message"))
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Divider()
                    Text(L10n.shared.tr("restart.guide.userspace.title"))
                        .font(.headline)
                    ForEach(1...3, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index).")
                                .font(.callout).bold()
                            Text(L10n.shared.tr("restart.guide.userspace.step\(index)"))
                                .font(.callout)
                        }
                    }
                    Divider()
                    Text(L10n.shared.tr("restart.guide.full.title"))
                        .font(.headline)
                    ForEach(1...4, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index).")
                                .font(.callout).bold()
                            Text(L10n.shared.tr("restart.guide.full.step\(index)"))
                                .font(.callout)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .workPlotScrollBackground()
            .navigationTitle(L10n.shared.tr("restart.action.guide"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.shared.tr("common.done")) { dismiss() }
                }
            }
        }
    }
}
