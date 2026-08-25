import SwiftUI

struct AppMark: View {
    let name: String
    let size: CGFloat
    var tint: Color = .white

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(tint)
            .frame(width: size, height: size)
    }
}

struct SectionHeader: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isBusy = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isBusy {
                    ProgressView()
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
        }
        .glassAction(prominent: true)
        .controlSize(.large)
        .disabled(disabled || isBusy)
    }
}

struct ProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.16).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large)
                Text(message).font(.subheadline.weight(.semibold))
            }
            .padding(26)
            .liquidGlass()
        }
        .transition(.opacity)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .liquidGlass(cornerRadius: 16)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: isPresented) {
                        guard isPresented else { return }
                        try? await Task.sleep(for: .seconds(2.4))
                        withAnimation(.snappy) { isPresented = false }
                    }
            }
        }
        .animation(.snappy, value: isPresented)
    }
}

extension View {
    /// A bottom-anchored, self-dismissing banner — for one-off "you found
    /// something" style feedback (easter eggs, unlocks) rather than errors.
    func toast(isPresented: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}
