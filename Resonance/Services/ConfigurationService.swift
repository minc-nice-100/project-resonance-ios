import Foundation

class ConfigurationService {
    static let shared = ConfigurationService()

    private var config: EndpointConfig?
    private let storage: KeyValueStorage
    private let configKey = "endpoint_config"
    private let configQueue = DispatchQueue(label: "com.resonance.configservice")

    init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage
        loadCachedConfig()
    }

    private func loadCachedConfig() {
        if let data = storage.data(forKey: configKey),
           let cached = try? JSONDecoder().decode(EndpointConfig.self, from: data) {
            self.config = cached
        }
    }

    func setConfig(_ config: EndpointConfig) {
        configQueue.sync {
            self.config = config
        }

        if let data = try? JSONEncoder().encode(config) {
            storage.set(data, forKey: configKey)
        }
    }

    func getConfig() -> [String: Any] {
        guard let config = configQueue.sync(execute: { self.config }) else {
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
        return configQueue.sync { config?.endpoints.api ?? "https://project-resonance.net" } ?? "https://project-resonance.net"
    }

    func getWSEndpoint() -> String {
        return configQueue.sync { config?.endpoints.ws ?? "wss://ws.project-resonance.net" } ?? "wss://ws.project-resonance.net"
    }

    func isLocalModelEnabled() -> Bool {
        return configQueue.sync { config?.features.localModel ?? true } ?? true
    }

    func getDefaultModel() -> String {
        return configQueue.sync { config?.model.defaultModel ?? "resonance-7b" } ?? "resonance-7b"
    }
}