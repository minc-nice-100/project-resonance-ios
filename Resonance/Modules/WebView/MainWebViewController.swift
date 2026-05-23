import UIKit
import WebKit
import Combine

class MainWebViewController: UIViewController {

    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let refreshControl = UIRefreshControl()

    private var cancellables = Set<AnyCancellable>()
    private let dnsResolver = DNSResolver()
    private let configurationService = ConfigurationService.shared

    private var baseURL: String = "https://project-resonance.net"
    private var isLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        setupBindings()
        discoverEndpoint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupUI() {
        title = "Resonance"
        navigationController?.navigationBar.prefersLargeTitles = true

        view.backgroundColor = .systemBackground

        let retryButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"),
                                           style: .plain,
                                           target: self,
                                           action: #selector(reloadTapped))
        navigationItem.rightBarButtonItem = retryButton
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        contentController.add(self, name: "nativeBridge")
        config.userContentController = contentController

        config.setURLSchemeHandler(self, forURLScheme: "resonance")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    private func setupBindings() {
        webView.publisher(for: \.estimatedProgress)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progressView.progress = Float(progress)
                self?.progressView.isHidden = progress >= 1.0
            }
            .store(in: &cancellables)

        webView.publisher(for: \.url)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                self?.updateURL(url)
            }
            .store(in: &cancellables)
    }

    private func discoverEndpoint() {
        dnsResolver.delegate = self
        dnsResolver.discoverEndpoint()
    }

    private func loadWebContent() {
        guard let url = URL(string: baseURL) else { return }

        let request = URLRequest(url: url,
                                cachePolicy: .reloadIgnoringLocalCacheData,
                                timeoutInterval: 30)
        webView.load(request)
    }

    private func updateURL(_ url: URL?) {
        guard let url = url else { return }
        title = url.host ?? "Resonance"
    }

    @objc private func handleRefresh() {
        webView.reload()
    }

    @objc private func reloadTapped() {
        webView.reload()
    }

    private func showError(message: String) {
        let alert = UIAlertController(title: "Error",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Retry",
                                     style: .default) { [weak self] _ in
            self?.loadWebContent()
        })
        alert.addAction(UIAlertAction(title: "OK",
                                     style: .cancel))
        present(alert, animated: true)
    }

    private func evaluateJavaScript(_ script: String,
                                   completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script) { result, error in
            completion?(result, error)
        }
    }
}

extension MainWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.isHidden = false
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
        isLoading = false
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        progressView.isHidden = true
        isLoading = false
        refreshControl.endRefreshing()

        if (error as NSError).code != NSURLErrorCancelled {
            showError(message: error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        progressView.isHidden = true
        isLoading = false
        refreshControl.endRefreshing()

        if (error as NSError).code != NSURLErrorCancelled {
            showError(message: error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

extension MainWebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

extension MainWebViewController: WKURLSchemeHandler {
    func webView(_ webView: WKWebView,
                 start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "WKURLSchemeHandler",
                                                    code: -1,
                                                    userInfo: nil))
            return
        }

        if url.scheme == "resonance" {
            handleCustomURL(url, task: urlSchemeTask)
        } else {
            urlSchemeTask.didFailWithError(NSError(domain: "WKURLSchemeHandler",
                                                    code: -2,
                                                    userInfo: nil))
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }

    private func handleCustomURL(_ url: URL, task: WKURLSchemeTask) {
        let response = URLResponse(url: url,
                                   mimeType: "application/json",
                                   expectedContentLength: 0,
                                   textEncodingName: nil)
        task.didReceive(response)
        task.didFinish()
    }
}

extension MainWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "nativeBridge",
              let body = message.body as? [String: Any] else {
            return
        }

        handleNativeCall(body)
    }

    private func handleNativeCall(_ body: [String: Any]) {
        guard let action = body["action"] as? String else { return }

        switch action {
        case "getConfig":
            let config = configurationService.getConfig()
            let configJSON = try? JSONSerialization.data(withJSONObject: config)
            let configString = String(data: configJSON ?? Data(), encoding: .utf8) ?? "{}"
            evaluateJavaScript("window.nativeBridge.handleResponse('getConfig', \(configString))")

        case "invokeLocalModel":
            guard let params = body["params"] as? [String: Any],
                  let prompt = params["prompt"] as? String else { return }
            invokeLocalModel(prompt: prompt)

        default:
            break
        }
    }

    private func invokeLocalModel(prompt: String) {
        let response: [String: Any] = [
            "success": false,
            "error": "Local model not available"
        ]

        if let responseJSON = try? JSONSerialization.data(withJSONObject: response),
           let responseString = String(data: responseJSON, encoding: .utf8) {
            evaluateJavaScript("window.nativeBridge.handleResponse('invokeLocalModel', \(responseString))")
        }
    }
}

extension MainWebViewController: DNSResolverDelegate {
    func dnsResolver(_ resolver: DNSResolver, didDiscoverEndpoint config: EndpointConfig) {
        configurationService.setConfig(config)
        baseURL = config.endpoints.api
        loadWebContent()
    }

    func dnsResolver(_ resolver: DNSResolver, didFailWithError error: DNSError) {
        loadWebContent()
    }
}
