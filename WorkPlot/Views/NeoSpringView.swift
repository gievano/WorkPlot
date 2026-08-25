//
//  NeoSpringView.swift
//  Ketamine
//
//  Full-screen respring transition, presented over RootView while
//  RespringHelper.shared.isRespringing is true. Shows a plain loading screen
//  first so the WKWebView beneath it — which triggers the WebKit GPU crash —
//  is never visibly rendered; it's dimmed to black and layered underneath.
//

import SwiftUI
import WebKit

struct NeoSpringView: View {
    @State private var showsWebView = false

    var body: some View {
        ZStack {
            Color.black
            ProgressView()
                .tint(.white)

            if showsWebView {
                NeoSpringWebView()
                    .brightness(-1)
            }
        }
        .ignoresSafeArea()
        .task {
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
        webView.loadHTMLString(RespringHelper.crashHTML, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
