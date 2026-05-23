import Foundation

enum DNSRecordType: String {
    case srv = "SRV"
    case txt = "TXT"
    case a = "A"
    case aaaa = "AAAA"
}

enum DnsServer {
    case cloudflare
    case google
    case domestic

    var url: URL? {
        switch self {
        case .cloudflare:
            return URL(string: "https://cloudflare-dns.com/dns-query")
        case .google:
            return URL(string: "https://dns.google/dns-query")
        case .domestic:
            return URL(string: "https://httpdns.baidu.com/dns-query")
        }
    }
}

class HTTPDNSClient {
    private let session: URLSession
    private let timeout: TimeInterval = 10

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    func query(domain: String,
               recordType: DNSRecordType,
               server: DnsServer = .domestic,
               completion: @escaping (Result<Data, DNSError>) -> Void) {
        guard let url = buildURL(domain: domain, recordType: recordType, server: server) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    completion(.failure(.timeout))
                } else {
                    completion(.failure(.networkUnavailable))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                completion(.failure(.serverError(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            completion(.success(data))
        }
        task.resume()
    }

    private func buildURL(domain: String, recordType: DNSRecordType, server: DnsServer) -> URL? {
        guard let baseURL = server.url else { return nil }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: recordType.rawValue)
        ]

        return components?.url
    }
}
