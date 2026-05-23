import Foundation

enum DNSError: Error {
    case networkUnavailable
    case serverError(Int)
    case timeout
    case invalidResponse
    case dnssecValidationFailed
    case noSrvRecord
    case noTxtRecord
    case resolutionFailed
}

struct SRVRecord {
    let priority: UInt16
    let weight: UInt16
    let port: UInt16
    let target: String
}

struct EndpointConfig: Codable {
    let version: String
    let endpoints: Endpoints
    let features: Features
    let model: ModelInfo

    struct Endpoints: Codable {
        let api: String
        let ws: String
    }

    struct Features: Codable {
        let localModel: Bool
        let voiceSupport: Bool
    }

    struct ModelInfo: Codable {
        let defaultModel: String
        let availableModels: [String]
    }
}

protocol DNSResolverDelegate: AnyObject {
    func dnsResolver(_ resolver: DNSResolver, didDiscoverEndpoint config: EndpointConfig)
    func dnsResolver(_ resolver: DNSResolver, didFailWithError error: DNSError)
}

class DNSResolver {
    weak var delegate: DNSResolverDelegate?

    private let httpDNSClient: HTTPDNSClient
    private let tlsDNSClient: TLSDNSClient
    private let dnssecValidator: DNSSECValidator
    private let regionDetector: RegionDetector
    private let cache: DNSCache

    private let baseDomain = "project-resonance.net"
    private let srvService = "_resonance._tcp"

    init() {
        self.httpDNSClient = HTTPDNSClient()
        self.tlsDNSClient = TLSDNSClient()
        self.dnssecValidator = DNSSECValidator()
        self.regionDetector = RegionDetector()
        self.cache = DNSCache()
    }

    func discoverEndpoint() {
        if let cached = cache.getCachedEndpoint() {
            delegate?.dnsResolver(self, didDiscoverEndpoint: cached)
            return
        }

        querySRVRecord()
    }

    private func querySRVRecord() {
        let srvName = "\(srvService).\(baseDomain)"

        resolveWithFallback(domain: srvName, recordType: .srv) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let srvData):
                self.parseSRVRecord(srvData, targetDomain: srvName)
            case .failure(let error):
                self.delegate?.dnsResolver(self, didFailWithError: error)
            }
        }
    }

    private func parseSRVRecord(_ data: Data, targetDomain: String) {
        guard let srv = parseSRV(data: data) else {
            queryTXTRecord()
            return
        }

        queryTXTRecord()
    }

    private func queryTXTRecord() {
        let txtName = "config.\(baseDomain)"

        resolveWithFallback(domain: txtName, recordType: .txt) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let txtData):
                self.parseTXTRecord(txtData)
            case .failure(let error):
                self.delegate?.dnsResolver(self, didFailWithError: error)
            }
        }
    }

    private func parseTXTRecord(_ data: Data) {
        guard let txtString = String(data: data, encoding: .utf8) else {
            delegate?.dnsResolver(self, didFailWithError: .invalidResponse)
            return
        }

        let configURL = txtString.trimmingCharacters(in: .whitespacesAndNewlines)

        fetchConfiguration(from: configURL)
    }

    private func fetchConfiguration(from urlString: String) {
        guard let url = URL(string: urlString) else {
            delegate?.dnsResolver(self, didFailWithError: .invalidResponse)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Config fetch error: \(error)")
                self.delegate?.dnsResolver(self, didFailWithError: .networkUnavailable)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                self.delegate?.dnsResolver(self, didFailWithError: .serverError(
                    (response as? HTTPURLResponse)?.statusCode ?? 0
                ))
                return
            }

            do {
                let config = try JSONDecoder().decode(EndpointConfig.self, from: data)
                self.cache.cacheEndpoint(config)
                DispatchQueue.main.async {
                    self.delegate?.dnsResolver(self, didDiscoverEndpoint: config)
                }
            } catch {
                self.delegate?.dnsResolver(self, didFailWithError: .invalidResponse)
            }
        }
        task.resume()
    }

    private func resolveWithFallback(domain: String,
                                     recordType: DNSRecordType,
                                     completion: @escaping (Result<Data, DNSError>) -> Void) {
        let isDomestic = regionDetector.isDomestic()

        if isDomestic {
            resolveDomestic(domain: domain, recordType: recordType, completion: completion)
        } else {
            resolveInternational(domain: domain, recordType: recordType, completion: completion)
        }
    }

    private func resolveDomestic(domain: String,
                                 recordType: DNSRecordType,
                                 completion: @escaping (Result<Data, DNSError>) -> Void) {
        httpDNSClient.query(domain: domain, recordType: recordType) { [weak self] result in
            switch result {
            case .success(let data):
                self?.validateAndComplete(data: data, completion: completion)
            case .failure:
                self?.tlsDNSClient.query(domain: domain, recordType: recordType) { tlsResult in
                    switch tlsResult {
                    case .success(let data):
                        self?.validateAndComplete(data: data, completion: completion)
                    case .failure:
                        self?.resolveLocal(domain: domain, recordType: recordType, completion: completion)
                    }
                }
            }
        }
    }

    private func resolveInternational(domain: String,
                                     recordType: DNSRecordType,
                                     completion: @escaping (Result<Data, DNSError>) -> Void) {
        httpDNSClient.query(domain: domain,
                           recordType: recordType,
                           server: .cloudflare) { [weak self] result in
            switch result {
            case .success(let data):
                self?.validateAndComplete(data: data, completion: completion)
            case .failure:
                self?.httpDNSClient.query(domain: domain,
                                         recordType: recordType,
                                         server: .google) { httpResult in
                    switch httpResult {
                    case .success(let data):
                        self?.validateAndComplete(data: data, completion: completion)
                    case .failure:
                        self?.resolveLocal(domain: domain, recordType: recordType, completion: completion)
                    }
                }
            }
        }
    }

    private func validateAndComplete(data: Data,
                                    completion: @escaping (Result<Data, DNSError>) -> Void) {
        if dnssecValidator.validate(data: data) {
            completion(.success(data))
        } else {
            completion(.failure(.dnssecValidationFailed))
        }
    }

    private func resolveLocal(domain: String,
                              recordType: DNSRecordType,
                              completion: @escaping (Result<Data, DNSError>) -> Void) {
        let host = CFHostCreateWithName(nil, domain as CFString).takeRetainedValue()

        CFHostStartInfoResolution(host, .addresses, nil)

        var success: DarwinBoolean = false
        guard let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as? [Data],
              success.boolValue,
              let addressData = addresses.first else {
            completion(.failure(.resolutionFailed))
            return
        }

        completion(.success(addressData))
    }

    private func parseSRV(data: Data) -> SRVRecord? {
        return nil
    }
}

class DNSCache {
    private var cache: [String: (config: EndpointConfig, timestamp: Date)] = [:]
    private let cacheTTL: TimeInterval = 300

    func getCachedEndpoint() -> EndpointConfig? {
        guard let entry = cache["endpoint"],
              Date().timeIntervalSince(entry.timestamp) < cacheTTL else {
            return nil
        }
        return entry.config
    }

    func cacheEndpoint(_ config: EndpointConfig) {
        cache["endpoint"] = (config, Date())
    }
}

class RegionDetector {
    func isDomestic() -> Bool {
        let locale = Locale.current
        let regionCode = locale.region?.identifier ?? ""

        let domesticRegions = ["CN"]
        return domesticRegions.contains(regionCode)
    }
}
