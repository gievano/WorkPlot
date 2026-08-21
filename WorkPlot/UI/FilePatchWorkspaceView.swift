import SwiftUI

struct FilePatchWorkspaceView: View {
    var body: some View {
<<<<<<< HEAD
        NavigationView { List { Text("File Patch Workspace") }.navigationTitle("Files") }
=======
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
>>>>>>> 20aa9fc (fix: perbaiki type mismatch foregroundStyle di FilePatchWorkspaceView)
    }
}
