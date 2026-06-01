import Foundation

// Future production implementation of PocketStampService. Once configured, this service
// will use APIClient to call the PocketStamp backend. PassReader remains responsible for
// NFC input; this service sends resulting stamp/redeem actions to the API. Apple Wallet
// pass updates happen server-side after the backend changes the stored balance.
final class RemotePocketStampService: PocketStampService {
    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func authenticate(email: String, password: String) async throws -> MerchantUser {
        // Future call: POST /api/merchant/login with MerchantLoginRequest.
        throw APIError.remoteServiceNotConfigured
    }

    func loadMerchant(for user: MerchantUser) async throws -> Merchant {
        // Merchant data will come from the authenticated session or a merchant endpoint.
        throw APIError.remoteServiceNotConfigured
    }

    func loadLocation(for merchant: Merchant) async throws -> Location {
        // The backend will return the user's selected or default cafe location.
        throw APIError.remoteServiceNotConfigured
    }

    func registerDevice(for merchant: Merchant, location: Location) async throws -> RegisteredDevice {
        // Future call: POST /api/devices/register with DeviceRegistrationRequest.
        throw APIError.remoteServiceNotConfigured
    }

    func addStamp(
        to customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        // Future call: POST /api/taps/stamp with AddStampRequest.
        throw APIError.remoteServiceNotConfigured
    }

    func redeemReward(
        for customerPass: CustomerPass,
        merchant: Merchant,
        location: Location
    ) async throws -> TapResult {
        // Future call: POST /api/taps/redeem with RedeemRewardRequest.
        throw APIError.remoteServiceNotConfigured
    }

    func logActivity(
        for result: TapResult,
        merchant: Merchant,
        location: Location,
        device: RegisteredDevice
    ) async throws -> StampEvent {
        // Activity is expected from the tap response or GET /api/merchant/activity.
        throw APIError.remoteServiceNotConfigured
    }
}
