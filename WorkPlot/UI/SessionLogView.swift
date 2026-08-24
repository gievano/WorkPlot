import SwiftUI

struct SessionLogView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var text = SessionLogger.shared.text
    @State private var showShare = false

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "—" : text)
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(l10n.tr("sessionlog.title"))
        .navigationBarTitleDisplayMode(.inline)
        .wpGlassContainer()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label(l10n.tr("sessionlog.copy"), systemImage: "doc.on.doc")
                }
                Button {
                    showShare = true
                } label: {
                    Label(l10n.tr("sessionlog.share"), systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    SessionLogger.shared.clear()
                    text = ""
                } label: {
                    Label(l10n.tr("sessionlog.clear"), systemImage: "trash")
                }
            }
        }
        .onAppear { text = SessionLogger.shared.text }
        .sheet(isPresented: $showShare) {
            ActivityShareSheet(items: [text])
        }
    }
}
