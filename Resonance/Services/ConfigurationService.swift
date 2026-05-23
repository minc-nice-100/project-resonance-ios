import Foundation

class ConfigurationService {
    static let shared = ConfigurationService()

    private var config: EndpointConfig?
    private let userDefaults = UserDefaults.standard
    private let configKey = "endpoint_config"

    private init() {
        loadCachedConfig()
    }

    private func loadCachedConfig() {
        if let data = userDefaults.data(forKey: configKey),
           let cached = try? JSONDecoder().decode(EndpointConfig.self, from: data) {
            self.config = cached
        }
    }

    func setConfig(_ config: EndpointConfig) {
        self.config = config

        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: configKey)
        }
    }

    func getConfig() -> [String: Any] {
        guard let config = config else {
            return [:]
        }

        return [
            "version": config.version,
            "apiEndpoint": config.endpoints.api,
            "wsEndpoint": config.endpoints.ws,
            "localModelEnabled": config.features.localModel,
            "voiceSupport": config.features.voiceSupport,
            "defaultModel": config.model.defaultModel,
            "availableModels": config.model.availableModels
        ]
    }

    func getAPIEndpoint() -> String {
        return config?.endpoints.api ?? "https://project-resonance.net"
    }

    func getWSEndpoint() -> String {
        return config?.endpoints.ws ?? "wss://ws.project-resonance.net"
    }

    func isLocalModelEnabled() -> Bool {
        return config?.features.localModel ?? true
    }

    func getDefaultModel() -> String {
        return config?.model.defaultModel ?? "resonance-7b"
    }
}
