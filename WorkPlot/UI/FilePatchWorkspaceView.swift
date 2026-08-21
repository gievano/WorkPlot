import SwiftUI

struct FilePatchWorkspaceView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NavigationView {
            List {
                Section(header: Text(l10n.tr("danger.header"))) {
                    Label(l10n.tr("danger.filepatch.message"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 15, weight: .medium))
                }

                Section {
                    Text(manager.sandboxGranted
                         ? l10n.tr("filepatch.ready")
                         : l10n.tr("filepatch.needaccess"))
                        .font(.system(size: 15))
                        .foregroundStyle(manager.sandboxGranted ? Color.primary : Color.orange)
                }
            }
            .navigationTitle(l10n.tr("tab.files"))
        }
    }
}
