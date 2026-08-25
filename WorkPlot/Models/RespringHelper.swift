//
//  RespringHelper.swift
//  WorkPlot
//
//  NeoSpring-style instant respring (WebKit GPU crash). Web approach
//  developed by @neonmodder123, ported to Swift by @skadz108, as used in
//  rooootdev/neospring and rooootdev/GestaltEdit.
//
//  Sets `isRespringing`, which RootView observes to present NeoSpringView
//  full-screen — the WKWebView that actually triggers the crash lives there.
//

import Foundation
import UIKit

final class RespringHelper: ObservableObject {

    static let shared = RespringHelper()

    @Published private(set) var isRespringing = false

    private init() {}

    static let crashHTML = #"""
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

    func trigger() {
        #if targetEnvironment(simulator)
        print("respring skipped on simulator")
        #else
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.trigger() }
            return
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        isRespringing = true
        #endif
    }
}
