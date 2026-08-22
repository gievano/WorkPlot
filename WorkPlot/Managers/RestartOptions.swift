//
//  RestartOptions.swift
//  WorkPlot
//
//  Restart escalation for heavy tweaks (model spoofing, Siri AI mode,
//  Color Palette). Respring runs through the proven NeoSpring WebKit
//  crash method; userspace and full restart CANNOT be executed from this
//  app because the bad_query exploit is file read/write only - it cannot
//  spawn processes, so `launchctl reboot userspace|system` is unreachable.
//  The guide below says so honestly and walks the user through the manual
//  force-restart gesture instead.
//

import SwiftUI

enum RestartAction: CaseIterable, Hashable {
    case respring
    case userspace
    case full

    var labelKey: String {
        switch self {
        case .respring: "siriai.restart.respring"
        case .userspace: "restart.action.userspace"
        case .full: "restart.action.full"
        }
    }

    var icon: String {
        switch self {
        case .respring: "arrow.counterclockwise"
        case .userspace: "arrow.triangle.2.circlepath"
        case .full: "power"
        }
    }
}

/// Non-dismissible restart prompt shared by every heavy-tweak apply flow.
/// Deliberately an `.alert` instead of a confirmationDialog: iOS alerts are
/// modal and cannot be dismissed by tapping outside, so the user MUST pick
/// one of the three escalation paths before moving on.
struct HeavyRestartFlow: ViewModifier {
    @ObservedObject var manager = ExploitManager.shared
    @Binding var isPresented: Bool
    @State private var guideAction: RestartAction?

    func body(content: Content) -> some View {
        content
            .alert(
                L10n.shared.tr("restart.required.title"),
                isPresented: $isPresented
            ) {
                ForEach(RestartAction.allCases, id: \.self) { action in
                    Button(L10n.shared.tr(action.labelKey)) { handle(action) }
                }
            } message: {
                Text(L10n.shared.tr("restart.options.message"))
            }
            .sheet(item: $guideAction) { action in
                RestartGuideSheet(action: action)
            }
    }

    private func handle(_ action: RestartAction) {
        if action == .respring {
            manager.respringRequested = true
        } else {
            // Executing a userspace/full reboot needs process spawning that
            // the sandbox escape does not provide; guide the user instead.
            guideAction = action
        }
    }
}

extension RestartAction: Identifiable {
    var id: Self { self }
}

extension View {
    func heavyRestartFlow(isPresented: Binding<Bool>) -> some View {
        modifier(HeavyRestartFlow(isPresented: isPresented))
    }
}

struct RestartGuideSheet: View {
    let action: RestartAction
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
                    Text(titleKey)
                        .font(.headline)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.callout).bold()
                            Text(step)
                                .font(.callout)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .workPlotScrollBackground()
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.shared.tr("common.done")) { dismiss() }
                }
            }
        }
    }

    private var titleKey: String {
        L10n.shared.tr(action == .userspace ? "restart.guide.userspace.title" : "restart.guide.full.title")
    }

    private var steps: [String] {
        let count = action == .userspace ? 3 : 4
        return (1...count).map { L10n.shared.tr("restart.guide.\(action == .userspace ? "userspace" : "full").step\($0)") }
    }
}
