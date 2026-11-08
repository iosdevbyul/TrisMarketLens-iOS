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
    case timeout
    case offline
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

    /// A restricted, JSON-body read-only operation; callers own authorization and local-only checks.
    func post<Request: Encodable, Response: Decodable>(
        _ responseType: Response.Type, path: [String], request: Request
    ) async throws -> Response {
        guard !path.isEmpty,
              path.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("/") }) else {
            throw ResearchAPIError.invalidConfiguration
        }
        let body: Data
        do {
            body = try JSONEncoder().encode(request)
        } catch {
            throw ResearchAPIError.invalidPayload
        }
        guard body.count <= 4096 else { throw ResearchAPIError.invalidConfiguration }
        let endpoint = ResearchPostEndpoint(path: path.joined(separator: "/"), body: body)
        do {
            return try await networkClient.request(endpoint: endpoint, responseType: responseType)
        } catch let error as NetworkError {
            switch error {
            case .serverError(let status): throw ResearchAPIError.httpStatus(status)
            case .decodingFailed: throw ResearchAPIError.invalidPayload
            case .invalidResponse: throw ResearchAPIError.invalidResponse
            case .invalidURL: throw ResearchAPIError.invalidConfiguration
            case .unknown(let underlying): throw Self.mapTransportError(underlying)
            }
        } catch {
            throw ResearchAPIError.transport
        }
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
                throw Self.mapTransportError(underlying)
            }
        } catch {
            throw ResearchAPIError.transport
        }
    }

    /// Preserve recoverable network failures without automatically replaying requests.
    /// Only the user-initiated Retry triggers another request.
    private static func mapTransportError(_ error: Error) -> ResearchAPIError {
        let ns = error as NSError
        guard ns.domain == NSURLErrorDomain else { return .transport }
        switch ns.code {
        case NSURLErrorTimedOut: return .timeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed: return .offline
        default: return .transport
        }
    }

}

private struct ResearchEndpoint: Endpoint {
    let path: String
    let queryItems: [URLQueryItem]
    let method: HTTPMethod = .get
    let headers = ["Accept": "application/json"]
}

private struct ResearchPostEndpoint: Endpoint {
    let path: String
    let body: Data?
    let method: HTTPMethod = .post
    let headers = ["Accept": "application/json", "Content-Type": "application/json"]
    let queryItems: [URLQueryItem] = []
}
