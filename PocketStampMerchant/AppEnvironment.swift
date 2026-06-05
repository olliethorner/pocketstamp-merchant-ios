import Foundation

enum AppBackendMode {
    case mock
    case local
    case railway

    var displayName: String {
        switch self {
        case .mock: "Mock"
        case .local: "Local"
        case .railway: "Railway"
        }
    }
}

enum AppEnvironment {
    // true = internal demo/dev build with demo mode and merchant switching available.
    // false = production merchant-facing build; hide demo mode and merchant selector.
    static let isDemoModeEnabled = true

    // Switch to .mock for the original fully in-memory prototype.
    // Switch to .local for simulator testing with node server.js running on the Mac.
    // Switch to .railway for deployed backend testing.
    static let backendMode: AppBackendMode = .railway

    // Simulator can usually access a Mac-hosted local backend at this URL.
    static let localBackendBaseURL = URL(string: "http://localhost:3000")!
    static let railwayBackendBaseURL = URL(string: "https://pocketstamp-wallet-backend-production.up.railway.app")!

    static var selectedBackendBaseURL: URL? {
        switch backendMode {
        case .mock:
            nil
        case .local:
            localBackendBaseURL
        case .railway:
            railwayBackendBaseURL
        }
    }

    static var remoteBackendBaseURL: URL {
        guard let selectedBackendBaseURL else {
            preconditionFailure("Mock mode does not use a remote backend URL.")
        }

        return selectedBackendBaseURL
    }

    static func makePassReader() -> PassReader {
        switch backendMode {
        case .mock:
            MockPassReader()
        case .local, .railway:
            // Real NFC remains mocked until Apple entitlement approval.
            LocalBackendMockPassReader()
        }
    }

    static func makePocketStampService() -> PocketStampService {
        switch backendMode {
        case .mock:
            MockPocketStampService()
        case .local, .railway:
            RemotePocketStampService(apiClient: APIClient(baseURL: remoteBackendBaseURL))
        }
    }
}
