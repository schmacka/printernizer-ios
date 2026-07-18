import SwiftUI
import WebKit

/// Parametric model generator. The geometry engine (JSCAD + three.js)
/// runs entirely in the web frontend, so the web app's generator page
/// is embedded rather than reimplemented. Requires the phone to reach
/// the server and, for the CDN-hosted JS modules, the internet.
struct GeneratorView: View {
    @State private var reloadToken = UUID()

    var body: some View {
        Group {
            if let url = generatorURL {
                GeneratorWebView(url: url)
                    .id(reloadToken)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "No Server Configured",
                    systemImage: "network.slash",
                    description: Text("Set the server URL in Settings")
                )
            }
        }
        .navigationTitle("Generator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GeneratorPresetsView()
                } label: {
                    Image(systemName: "list.star")
                }
            }
        }
    }

    private var generatorURL: URL? {
        guard let base = APIConfiguration.normalizedServerURL else { return nil }
        return URL(string: "\(base)/#generator")
    }
}

/// WKWebView wrapper for the web generator page. Injects CSS to hide
/// the web app's navigation chrome so only the generator UI shows.
struct GeneratorWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let hideChrome = """
        const style = document.createElement('style');
        style.textContent = '.navbar, .nav-bar, header.navbar, #connectionStatus { display: none !important; }';
        document.head.appendChild(style);
        """
        let script = WKUserScript(
            source: hideChrome,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) { }
}

#Preview {
    NavigationStack {
        GeneratorView()
    }
}
