import Foundation
import Combine

enum DNSServerType: String, CaseIterable {
    case cloudflare = "Cloudflare"
    case google = "Google"
    case domestic = "Domestic"
    case system = "System Default"
}

struct AppSettings: Codable {
    var enableDNSSEC: Bool
    var dnsServer: String
    var autoDiscovery: Bool
    var endpoint: String?

    static let `default` = AppSettings(
        enableDNSSEC: true,
        dnsServer: DNSServerType.domestic.rawValue,
        autoDiscovery: true,
        endpoint: nil
    )
}

class SettingsViewModel: ObservableObject {
    @Published var settings: AppSettings

    private let storage: KeyValueStorage
    private let settingsKey = "app_settings"

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    init(storage: KeyValueStorage = UserDefaultsStorage()) {
        self.storage = storage
        if let data = storage.data(forKey: settingsKey),
           let savedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = savedSettings
        } else {
            self.settings = .default
        }
    }

    func setDNSSEC(enabled: Bool) {
        settings.enableDNSSEC = enabled
        saveSettings()
    }

    func setDNSServer(_ server: DNSServerType) {
        settings.dnsServer = server.rawValue
        saveSettings()
    }

    func setAutoDiscovery(enabled: Bool) {
        settings.autoDiscovery = enabled
        saveSettings()
    }

    func setEndpoint(_ endpoint: String?) {
        settings.endpoint = endpoint
        saveSettings()
    }

    func clearDNSCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    func resetToDefaults() {
        settings = .default
        saveSettings()
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            storage.set(data, forKey: settingsKey)
        }
    }
}
