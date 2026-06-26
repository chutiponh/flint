// UI/Components/WebPreviewView.swift
// STUB — placeholder so project compiles during TDD RED phase.
import SwiftUI
import WebKit

struct WebPreviewView: NSViewRepresentable {
    var html: String

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {}
}
