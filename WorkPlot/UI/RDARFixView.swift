import SwiftUI

struct RDARFixView: View {
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                TextField("Lebar (px)", text: $widthText)
                    .keyboardType(.numberPad)
                TextField("Tinggi (px)", text: $heightText)
                    .keyboardType(.numberPad)
                Button("Terapkan Canvas") { apply() }
                    .buttonStyle(.borderedProminent)
                if let status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }
            } header: { Text("Canvas RDARFix") }

            Section {
                Text("Menulis ulang route canvas (MobileGestalt MainScreenCanvasSizes + plist IOMobileGraphicsFamily) agar resolusi layar berubah tanpa reboot.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: { Text("Info") }
        }
        .navigationTitle("RDARFix")
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
