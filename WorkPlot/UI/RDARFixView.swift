import SwiftUI

struct RDARFixView: View {
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var status: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader("Canvas RDARFix")
                VStack(spacing: 14) {
                    TextField("Width (px)", text: $widthText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Height (px)", text: $heightText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    ActionButton(title: "Apply Canvas", systemImage: "wand.and.stars") { apply() }
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(status.hasPrefix("Failed") ? Theme.caution : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                SectionHeader("Info")
                Text("Rewrites the canvas route (MobileGestalt MainScreenCanvasSizes plus the IOMobileGraphicsFamily plist) so the screen resolution changes without a reboot.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(Theme.pagePadding)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("RDARFix")
        .navigationBarTitleDisplayMode(.inline)
    }

    func apply() {
        guard let w = Int(widthText), let h = Int(heightText), w > 0, h > 0 else {
            status = "Enter a valid width & height"; return
        }
        do {
            try RDARFix.apply(canvasWidth: w, canvasHeight: h)
            status = "Canvas applied successfully"
        } catch {
            status = "Failed: \(error.localizedDescription)"
        }
    }
}
