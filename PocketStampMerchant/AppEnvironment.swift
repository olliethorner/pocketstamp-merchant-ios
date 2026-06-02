import Foundation

enum AppBackendMode {
    case mock
    case local
}

enum AppEnvironment {
    // Switch this to .mock to run the original fully in-memory prototype.
    static let backendMode: AppBackendMode = .local

    // Simulator can usually access Mac localhost at http://localhost:3000.
    // A real iPhone will need the Mac LAN IP or Railway URL later.
    static let localBackendBaseURL = URL(string: "http://localhost:3000")!

    static func makePassReader() -> PassReader {
        switch backendMode {
        case .mock:
            MockPassReader()
        case .local:
            LocalBackendMockPassReader()
        }
    }

    static func makePocketStampService() -> PocketStampService {
        switch backendMode {
        case .mock:
            MockPocketStampService()
        case .local:
            RemotePocketStampService(apiClient: APIClient(baseURL: localBackendBaseURL))
        }
    }
}
