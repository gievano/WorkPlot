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
                    TextField("Lebar (px)", text: $widthText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Tinggi (px)", text: $heightText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    ActionButton(title: "Terapkan Canvas", systemImage: "wand.and.stars") { apply() }
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(status.hasPrefix("Gagal") ? Theme.caution : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(18)
                .liquidGlass()

                SectionHeader("Info")
                Text("Menulis ulang route canvas (MobileGestalt MainScreenCanvasSizes + plist IOMobileGraphicsFamily) agar resolusi layar berubah tanpa reboot.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(18)
                    .liquidGlass()
            }
            .padding(Theme.pagePadding)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("RDARFix")
        .navigationBarTitleDisplayMode(.inline)
    }

    func apply() {
        guard let w = Int(widthText), let h = Int(heightText), w > 0, h > 0 else {
            status = "Masukkan lebar & tinggi valid"; return
        }
        do {
            try RDARFix.apply(canvasWidth: w, canvasHeight: h)
            status = "Canvas berhasil diterapkan"
        } catch {
            status = "Gagal: \(error.localizedDescription)"
        }
    }
}
