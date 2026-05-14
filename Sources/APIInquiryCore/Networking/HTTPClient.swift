import Foundation

public struct HTTPResponse: Equatable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol HTTPClient {
    func data(for request: URLRequest) async throws -> HTTPResponse
}

public enum HTTPClientError: Error, Equatable, LocalizedError {
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid."
        }
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return HTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
}
