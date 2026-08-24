import SwiftUI
import UIKit

struct AppearanceView: View {
    @AppStorage("appAccent") private var appAccent = AppAccent.orange.rawValue
    @AppStorage("useCustomColor") private var useCustomColor = false
    @AppStorage("customColor") private var customColor: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                WPCard {
                    VStack(alignment: .leading, spacing: 14) {
                        WPSectionHeader(title: "Accent Color")
                        HStack(spacing: 14) {
                            ForEach(AppAccent.allCases) { accent in
                                Button {
                                    useCustomColor = false
                                    appAccent = accent.rawValue
                                } label: {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if !useCustomColor && appAccent == accent.rawValue {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(accent.displayName)
                            }
                        }
                    }
                }

                WPCard {
                    VStack(alignment: .leading, spacing: 14) {
                        WPSectionHeader(title: "Custom Color")
                        HStack(spacing: 14) {
                            ColorPicker("", selection: Binding(
                                get: { Color(hue: customColor, saturation: 0.75, brightness: 0.9) },
                                set: { new in
                                    var h: CGFloat = 0
                                    UIColor(new).getHue(&h, saturation: nil, brightness: nil, alpha: nil)
                                    customColor = h
                                    useCustomColor = true
                                }
                            ))
                            .labelsHidden()
                            Circle()
                                .fill(Color(hue: customColor, saturation: 0.75, brightness: 0.9))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if useCustomColor {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            if useCustomColor {
                                Button("Reset") {
                                    useCustomColor = false
                                    appAccent = AppAccent.orange.rawValue
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Appearance")
        .wpGlassContainer()
    }
}
