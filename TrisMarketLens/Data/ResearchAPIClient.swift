import Foundation

enum ResearchDataMode: String {
    case disconnected
    case mock
    case http
}

enum ResearchAPIError: Error, Equatable {
    case invalidConfiguration
    case invalidResponse
    case httpStatus(Int)
    case transport
    case invalidPayload
}

/// Shared read-only transport. HTTP failures never fall back to sample research results.
struct ResearchAPIClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw ResearchAPIError.invalidConfiguration
        }
        self.baseURL = baseURL
        self.session = session
    }

    func fetch<T: Decodable>(_ type: T.Type, path: [String]) async throws -> T {
        guard !path.isEmpty,
              path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw ResearchAPIError.invalidConfiguration
        }
        var url = baseURL
        for segment in path {
            url.appendPathComponent(segment)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ResearchAPIError.transport
        }

        guard let http = response as? HTTPURLResponse else {
            throw ResearchAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ResearchAPIError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ResearchAPIError.invalidPayload
        }
    }
}
