import Foundation
import NetworkKit

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

/// App-level contract remains stable while NetworkKit owns the HTTP transport.
struct ResearchAPIClient {
    let baseURL: URL
    private let networkClient: any NetworkClient

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
        self.networkClient = URLSessionNetworkClient(
            configuration: NetworkConfiguration(baseURL: baseURL, timeout: 10),
            session: session
        )
    }

    init(baseURL: URL, networkClient: any NetworkClient) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              components.host != nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil else {
            throw ResearchAPIError.invalidConfiguration
        }
        self.baseURL = baseURL
        self.networkClient = networkClient
    }

    func fetch<T: Decodable>(_ type: T.Type, path: [String], queryItems: [URLQueryItem] = []) async throws -> T {
        guard !path.isEmpty,
              path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw ResearchAPIError.invalidConfiguration
        }

        let endpoint = ResearchEndpoint(path: path.joined(separator: "/"), queryItems: queryItems)
        do {
            return try await networkClient.request(endpoint: endpoint, responseType: type)
        } catch let error as NetworkError {
            switch error {
            case .serverError(let status): throw ResearchAPIError.httpStatus(status)
            case .decodingFailed: throw ResearchAPIError.invalidPayload
            case .invalidResponse: throw ResearchAPIError.invalidResponse
            case .invalidURL: throw ResearchAPIError.invalidConfiguration
            case .unknown(let underlying):
                #if DEBUG
                print("[ResearchAPI] Transport error for \(endpoint.path): \(String(reflecting: underlying))")
                #endif
                throw ResearchAPIError.transport
            }
        } catch {
            throw ResearchAPIError.transport
        }
    }
}

private struct ResearchEndpoint: Endpoint {
    let path: String
    let queryItems: [URLQueryItem]
    let method: HTTPMethod = .get
    let headers = ["Accept": "application/json"]
}
