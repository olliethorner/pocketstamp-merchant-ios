import Foundation

// Lightweight networking foundation for the future Railway / Supabase-backed API.
// The placeholder URL is intentionally not used while MockPocketStampService is active.
struct APIClient {
    let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL = URL(string: "https://api.getpocketstamp.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func send<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: (any Encodable)? = nil,
        bearerToken: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case remoteServiceNotConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The PocketStamp API URL is invalid."
        case .invalidResponse: "The PocketStamp API returned an invalid response."
        case let .httpStatus(code): "The PocketStamp API returned HTTP \(code)."
        case .decodingFailed: "The PocketStamp API response could not be read."
        case .remoteServiceNotConfigured: "Remote PocketStamp service is not configured yet."
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
