import Foundation

class TLSDNSClient {
    private let session: URLSession
    private let timeout: TimeInterval = 15

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        config.urlCache = nil
        self.session = URLSession(configuration: config)
    }

    func query(domain: String,
               recordType: DNSRecordType,
               completion: @escaping (Result<Data, DNSError>) -> Void) {
        guard let url = buildURL(domain: domain, recordType: recordType) else {
            completion(.failure(.invalidResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
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

    private func buildURL(domain: String, recordType: DNSRecordType) -> URL? {
        let baseURL = "https://dns.google/dns-query"

        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: recordType.rawValue)
        ]

        return components?.url
    }
}
