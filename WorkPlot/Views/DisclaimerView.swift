import SwiftUI

/// First-launch acknowledgement. Presented as a full-screen cover so it
/// can't be swiped away — the only way past it is the accept button, which
/// records the acknowledgement in `hasAcceptedDisclaimer`.
struct DisclaimerView: View {
    let accept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("⚠️ Before You Continue")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 12)
                    Text("Ketamine modifies system behavior and may cause unexpected results.")
                    Text("Experimental features may cause crashes, instability, loss of functionality, data loss, or other issues with your device.")
                    Text("Back up your device before using Ketamine.")
                    Text("Ketamine is provided “AS IS” and without warranty, to the maximum extent permitted by applicable law. You are responsible for your device, your data, and anything you choose to do with this software.")
                    Text("By continuing, you acknowledge these risks and agree to use Ketamine at your own discretion.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/Nouvborne/Ketamine/blob/main/DISCLAIMER.md")!) {
                    Text("View Full Disclaimer")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .glassAction()
                ActionButton(title: "I understand & Continue", action: accept)
            }
        }
        .padding(Theme.pagePadding)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
