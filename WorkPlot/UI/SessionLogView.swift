import SwiftUI

struct SessionLogView: View {
    @State private var text = SessionLogger.shared.text
    @State private var showShare = false

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "—" : text)
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Session Log")
        .navigationBarTitleDisplayMode(.inline)
        .wpGlassContainer()
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy Log", systemImage: "doc.on.doc")
                }
                Button {
                    showShare = true
                } label: {
                    Label("Share Log", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    SessionLogger.shared.clear()
                    text = ""
                } label: {
                    Label("Clear Log", systemImage: "trash")
                }
            }
        }
        .onAppear { text = SessionLogger.shared.text }
        .sheet(isPresented: $showShare) {
            ActivityShareSheet(items: [text])
        }
    }
}
