import Foundation

class EndpointDiscovery {
    private let dnsResolver = DNSResolver()
    private let configurationService = ConfigurationService.shared

    var onEndpointDiscovered: ((EndpointConfig) -> Void)?
    var onDiscoveryFailed: ((DNSError) -> Void)?

    init() {
        dnsResolver.delegate = self
    }

    func discover() {
        dnsResolver.discoverEndpoint()
    }

    func forceRefresh() {
        configurationService.setConfig(EndpointConfig(
            version: "",
            endpoints: EndpointConfig.Endpoints(api: "", ws: ""),
            features: EndpointConfig.Features(localModel: false, voiceSupport: false),
            model: EndpointConfig.ModelInfo(defaultModel: "", availableModels: [])
        ))
        dnsResolver.discoverEndpoint()
    }
}

extension EndpointDiscovery: DNSResolverDelegate {
    func dnsResolver(_ resolver: DNSResolver, didDiscoverEndpoint config: EndpointConfig) {
        configurationService.setConfig(config)
        onEndpointDiscovered?(config)
    }

    func dnsResolver(_ resolver: DNSResolver, didFailWithError error: DNSError) {
        onDiscoveryFailed?(error)
    }
}
